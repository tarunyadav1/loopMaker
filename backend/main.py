"""
LoopMaker Python Backend
FastAPI server for ACE-Step v1.5 audio generation
"""

import asyncio
import json
import os
import platform
import queue
import uuid
from concurrent.futures import ThreadPoolExecutor
from dataclasses import dataclass
from pathlib import Path
from typing import Callable, Optional

# Must set MPS fallback BEFORE importing torch — enables CPU fallback for
# Metal shader ops that crash (e.g. masked_fill_scalar_strided_32bit).
if platform.system() == "Darwin":
    os.environ["PYTORCH_ENABLE_MPS_FALLBACK"] = "1"

import numpy as np
import torch

# Note: PYTORCH_ENABLE_MPS_FALLBACK=1 is set above to handle PyTorch MPS
# Metal shader bugs. The pipeline uses cpu_offload=True + float32 for stability.
from fastapi import FastAPI, HTTPException, WebSocket, WebSocketDisconnect
from fastapi.middleware.cors import CORSMiddleware
from fastapi.responses import StreamingResponse
from pydantic import BaseModel
import scipy.io.wavfile as wavfile

app = FastAPI(
    title="LoopMaker Backend",
    description="AI Music Generation API powered by ACE-Step v1.5",
    version="2.0.0"
)

# CORS for Swift app communication
app.add_middleware(
    CORSMiddleware,
    allow_origins=["*"],
    allow_credentials=False,
    allow_methods=["*"],
    allow_headers=["*"],
)


# MARK: - MPS Memory Management

def _setup_mps_environment():
    """Configure MPS environment for Apple Silicon Macs.

    Note: PYTORCH_ENABLE_MPS_FALLBACK is set before `import torch` at module
    level (must be set before torch initializes the MPS backend).
    PYTORCH_MPS_HIGH_WATERMARK_RATIO is intentionally NOT set — PyTorch 2.10+
    computes low=2*high, so custom values cause "invalid low watermark ratio".
    """
    pass


_setup_mps_environment()


def _clear_mps_cache():
    """Clear MPS memory cache if available."""
    if torch.backends.mps.is_available():
        torch.mps.empty_cache()


# MARK: - Model Registry

@dataclass
class ModelInfo:
    hf_name: str
    size_gb: float
    min_ram_gb: int
    max_duration: int
    supports_lyrics: bool


MODEL_REGISTRY = {
    "acestep": ModelInfo("ACE-Step/acestep-v15-turbo", 5.0, 8, 240, True),
}


# MARK: - Model Caches

# ACE-Step v1.5 pipeline (replaces separate handler architecture)
_pipeline = None
_pipeline_initialized = False

# Configuration
MODEL_CACHE_DIR = Path.home() / ".cache" / "loopmaker" / "models"
MODEL_CACHE_DIR.mkdir(parents=True, exist_ok=True)

# Shared output directory (must match Swift's track storage path)
TRACKS_DIR = Path.home() / "Library" / "Application Support" / "LoopMaker" / "tracks"
TRACKS_DIR.mkdir(parents=True, exist_ok=True)


# MARK: - Request/Response Models

class GenerationRequest(BaseModel):
    prompt: str
    duration: int = 30  # seconds
    model: str = "acestep"
    seed: Optional[int] = None
    lyrics: Optional[str] = None
    quality_mode: str = "fast"  # "draft" (4 steps), "fast" (8 steps), or "quality" (50 steps)
    guidance_scale: float = 7.0  # v1.5 default (was 15.0 in v1)
    task_type: str = "text2music"  # "text2music" or "cover"
    source_audio_path: Optional[str] = None  # absolute path for cover mode
    ref_audio_strength: float = 0.5  # 0.0-1.0, how much reference audio influences output


class GenerationResponse(BaseModel):
    audio_path: str  # path to generated WAV file
    sample_rate: int
    duration: float


class DownloadRequest(BaseModel):
    model: str


# MARK: - Device Detection

def get_device() -> str:
    """Detect optimal device for inference (ACE-Step uses PyTorch for DiT, MLX for LM)."""
    if torch.cuda.is_available():
        return "cuda"
    elif torch.backends.mps.is_available():
        return "mps"
    return "cpu"


# MARK: - Model Loaders

ACE_STEP_REPO_ID = "ACE-Step/ACE-Step-v1-3.5B"
ACE_STEP_CACHE_DIR = Path.home() / ".cache" / "ace-step" / "checkpoints"


def _resolve_checkpoint_dir() -> str:
    """Resolve the ACE-Step checkpoint directory.

    First tries local cache (instant), then falls back to snapshot_download
    which will download weights if missing (~8GB).
    """
    from huggingface_hub import snapshot_download

    ACE_STEP_CACHE_DIR.mkdir(parents=True, exist_ok=True)

    # Fast path: try local-only resolution first (avoids HF API call)
    try:
        path = snapshot_download(
            ACE_STEP_REPO_ID,
            cache_dir=str(ACE_STEP_CACHE_DIR),
            local_files_only=True,
        )
        # Verify required subdirectories exist
        required = ["music_dcae_f8c8", "music_vocoder", "ace_step_transformer", "umt5-base"]
        if all(os.path.exists(os.path.join(path, d)) for d in required):
            print(f"ACE-Step checkpoint resolved from cache: {path}")
            return path
    except Exception:
        pass

    # Slow path: download from HuggingFace
    print(f"Downloading ACE-Step model from HuggingFace ({ACE_STEP_REPO_ID})...")
    print("This may take 5-30 minutes depending on your connection (~8GB)...")
    path = snapshot_download(
        ACE_STEP_REPO_ID,
        cache_dir=str(ACE_STEP_CACHE_DIR),
    )
    print(f"ACE-Step checkpoint downloaded to: {path}")
    return path


def _load_pipeline():
    """Load ACE-Step pipeline with Mac-specific configuration.

    Uses ACEStepPipeline which handles both DiT + codec internally.
    Resolves checkpoint path locally first to avoid slow HF API calls.
    """
    global _pipeline, _pipeline_initialized

    if _pipeline_initialized:
        return _pipeline

    try:
        from acestep.pipeline_ace_step import ACEStepPipeline
    except ImportError:
        raise ImportError(
            "ACE-Step not installed. Install with: "
            "pip install git+https://github.com/ace-step/ACE-Step-1.5.git"
        )

    # Clear memory before loading
    _clear_mps_cache()

    # Resolve checkpoint path (fast from local cache, slow download if missing)
    checkpoint_dir = _resolve_checkpoint_dir()

    print("Loading ACE-Step pipeline...")
    _pipeline = ACEStepPipeline(
        checkpoint_dir=checkpoint_dir,
        dtype="float32",
        torch_compile=False,
        cpu_offload=True,
    )

    # Force CPU device on Mac. PyTorch MPS has multiple fatal Metal shader bugs
    # (sub_dense_scalar_lhs_float_float, masked_fill_scalar_strided_32bit, etc.)
    # that crash with validateComputeFunctionArguments assertions.
    # PYTORCH_ENABLE_MPS_FALLBACK=1 can't catch fatal assertions.
    if platform.system() == "Darwin":
        _pipeline.device = torch.device("cpu")
        print("Forced CPU device (MPS Metal shaders are buggy)")

    # Pre-load the checkpoint so first generation isn't slow
    if not _pipeline.loaded:
        print("Loading model weights into memory...")
        _pipeline.load_checkpoint(checkpoint_dir)

    print("ACE-Step pipeline loaded successfully")

    _pipeline_initialized = True
    return _pipeline


# MARK: - Health Endpoint

@app.get("/health")
async def health_check():
    """Health check endpoint"""
    return {
        "status": "healthy",
        "models_loaded": ["acestep"] if _pipeline_initialized else [],
        "device": get_device()
    }


# MARK: - Model Status Endpoint

@app.get("/models/status")
async def get_model_status():
    """Check which models are downloaded and their capabilities"""
    status = {}
    for name, info in MODEL_REGISTRY.items():
        is_loaded = name == "acestep" and _pipeline_initialized

        # Check if model weights exist in cache
        is_downloaded = is_loaded
        if name == "acestep" and not is_downloaded:
            try:
                from huggingface_hub import snapshot_download
                path = snapshot_download(
                    ACE_STEP_REPO_ID,
                    cache_dir=str(ACE_STEP_CACHE_DIR),
                    local_files_only=True,
                )
                required = ["music_dcae_f8c8", "music_vocoder", "ace_step_transformer", "umt5-base"]
                is_downloaded = all(os.path.exists(os.path.join(path, d)) for d in required)
            except Exception:
                is_downloaded = False

        status[name] = {
            "downloaded": is_downloaded,
            "loaded": is_loaded,
            "size_gb": info.size_gb,
            "max_duration": info.max_duration,
            "supports_lyrics": info.supports_lyrics,
            "min_ram_gb": info.min_ram_gb
        }
    return status


# MARK: - Model Download Endpoint

@app.post("/models/download")
async def download_model(request: DownloadRequest):
    """Download a model with progress streaming"""
    model_info = MODEL_REGISTRY.get(request.model)
    if not model_info:
        raise HTTPException(status_code=400, detail=f"Unknown model: {request.model}")

    async def stream_progress():
        try:
            yield f'{{"status": "downloading", "progress": 0.1}}\n'

            # Download ACE-Step v1.5 — run in thread to avoid blocking event loop
            yield f'{{"status": "downloading", "progress": 0.15, "message": "Initializing ACE-Step v1.5 download..."}}\n'

            loop = asyncio.get_event_loop()
            load_future = loop.run_in_executor(
                _executor,
                _load_pipeline,
            )

            # Send keepalive progress updates every 5 seconds while model downloads
            # ACE-Step downloads ~5GB (28 files) which can take 5-30 minutes
            tick = 0
            while not load_future.done():
                await asyncio.sleep(5)
                tick += 1
                # Slowly ramp progress from 0.15 to 0.75 over ~30 minutes (360 ticks)
                progress = min(0.15 + tick * 0.005, 0.75)
                elapsed_min = tick * 5 / 60
                yield f'{{"status": "downloading", "progress": {progress:.3f}, "message": "Downloading ACE-Step v1.5 model ({elapsed_min:.1f} min elapsed)..."}}\n'

            # Check for errors from the thread
            try:
                load_future.result()
            except ImportError as e:
                yield f'{{"status": "error", "error": "{str(e)}"}}\n'
                return

            yield f'{{"status": "downloading", "progress": 0.85, "message": "Model loaded successfully"}}\n'

            yield f'{{"status": "complete", "progress": 1.0}}\n'

        except Exception as e:
            error_msg = str(e).replace('"', '\\"').replace('\n', ' ')
            yield f'{{"status": "error", "error": "{error_msg}"}}\n'

    return StreamingResponse(
        stream_progress(),
        media_type="application/x-ndjson"
    )


# MARK: - Generation Endpoint

@app.post("/generate", response_model=GenerationResponse)
async def generate_music(request: GenerationRequest):
    """Generate music from text prompt"""
    model_info = MODEL_REGISTRY.get(request.model)
    if not model_info:
        raise HTTPException(status_code=400, detail=f"Unknown model: {request.model}")

    if request.duration > model_info.max_duration:
        raise HTTPException(
            status_code=400,
            detail=f"Max duration for {request.model} is {model_info.max_duration}s, got {request.duration}s"
        )

    return await generate_acestep_http(request)


ProgressCallback = Callable[[float, str], None]

_executor = ThreadPoolExecutor(max_workers=2)


def _generate_acestep_sync(
    request: GenerationRequest,
    progress_cb: ProgressCallback,
) -> GenerationResponse:
    """Synchronous ACE-Step v1.5 generation with progress callbacks.

    Uses ACEStepPipeline which handles both DiT + LM internally.
    Supports text2music and cover (audio2audio) task types.
    """
    import tempfile

    # Clear MPS cache before generation
    _clear_mps_cache()

    progress_cb(0.05, "Loading ACE-Step v1.5 model...")
    pipeline = _load_pipeline()

    # Quality mode determines inference steps
    if request.quality_mode == "draft":
        infer_steps = 4
    elif request.quality_mode == "quality":
        infer_steps = 50
    else:  # "fast" (default)
        infer_steps = 8

    # Default to instrumental if no lyrics provided
    lyrics = request.lyrics if request.lyrics else "[inst]"

    # Cover mode: audio2audio via reference audio
    is_cover = request.task_type == "cover"

    if is_cover and request.source_audio_path:
        if not os.path.exists(request.source_audio_path):
            raise FileNotFoundError(f"Source audio not found: {request.source_audio_path}")

    # Infer duration from source audio if cover mode and duration is 0
    duration = float(request.duration)
    if is_cover and duration == 0 and request.source_audio_path:
        try:
            sr, audio = wavfile.read(request.source_audio_path)
            duration = len(audio) / sr
        except Exception:
            duration = 30.0  # fallback

    progress_cb(0.10, "Preparing generation parameters...")

    # Create temp directory for output
    temp_dir = tempfile.mkdtemp(prefix="loopmaker_")

    try:
        task_label = "Creating cover" if is_cover else "Generating audio"
        progress_cb(0.15, f"{task_label} (ACE-Step v1.5)...")

        # Build seed list
        manual_seeds = [request.seed] if request.seed is not None else None

        # Monkey-patch tqdm to forward diffusion step progress (0.15 → 0.85)
        import tqdm as _tqdm_module
        _orig_tqdm_init = _tqdm_module.tqdm.__init__
        _orig_tqdm_update = _tqdm_module.tqdm.update

        def _patched_init(self, *args, **kwargs):
            _orig_tqdm_init(self, *args, **kwargs)

        def _patched_update(self, n=1):
            _orig_tqdm_update(self, n)
            if self.total and self.total > 0:
                pct = self.n / self.total
                mapped = 0.15 + pct * 0.70  # Map 0-1 → 0.15-0.85
                progress_cb(mapped, f"{task_label} (step {self.n}/{self.total})...")

        _tqdm_module.tqdm.__init__ = _patched_init
        _tqdm_module.tqdm.update = _patched_update

        # Call pipeline directly
        print("Calling ACE-Step pipeline...")
        import time as _time
        _t0 = _time.time()
        try:
            result = pipeline(
                prompt=request.prompt,
                lyrics=lyrics,
                audio_duration=duration,
                infer_step=infer_steps,
                guidance_scale=request.guidance_scale,
                scheduler_type="euler",
                cfg_type="apg",
                omega_scale=10.0,
                audio2audio_enable=is_cover,
                ref_audio_input=request.source_audio_path if is_cover else None,
                ref_audio_strength=request.ref_audio_strength if is_cover else 0.5,
                save_path=temp_dir,
                batch_size=1,
                format="wav",
                manual_seeds=manual_seeds,
            )
        finally:
            # Restore original tqdm
            _tqdm_module.tqdm.__init__ = _orig_tqdm_init
            _tqdm_module.tqdm.update = _orig_tqdm_update

        print(f"Pipeline returned in {_time.time() - _t0:.1f}s, result type: {type(result)}")
        print(f"Pipeline result: {result}")

        progress_cb(0.85, "Processing audio...")

        # result is a list: [audio_path_0, ..., input_params_dict]
        # Find the first audio file path from the result
        output_audio_path = None
        if isinstance(result, list):
            for item in result:
                if isinstance(item, str) and Path(item).exists() and item.endswith(".wav"):
                    output_audio_path = item
                    break

        # Fallback: search temp dir for generated WAV files
        if not output_audio_path:
            generated_files = list(Path(temp_dir).glob("**/*.wav"))
            if not generated_files:
                generated_files = list(Path(temp_dir).glob("**/*.flac")) + list(Path(temp_dir).glob("**/*.mp3"))
            if generated_files:
                output_audio_path = str(generated_files[0])

        print(f"Output audio path: {output_audio_path}")
        if not output_audio_path:
            raise RuntimeError("ACE-Step generated no audio files")

        # Read the generated file
        print(f"Reading generated WAV file...")
        sample_rate, audio_data = wavfile.read(output_audio_path)
        print(f"WAV read: sr={sample_rate}, shape={audio_data.shape}, dtype={audio_data.dtype}")

        # Convert to float for normalization
        if audio_data.dtype == np.int16:
            audio_float = audio_data.astype(np.float32) / 32767.0
        elif audio_data.dtype == np.int32:
            audio_float = audio_data.astype(np.float32) / 2147483647.0
        else:
            audio_float = audio_data.astype(np.float32)

        # Handle stereo by averaging channels
        if audio_float.ndim > 1:
            audio_float = audio_float.mean(axis=1)

        # Normalize audio
        max_val = np.max(np.abs(audio_float))
        if max_val > 0:
            audio_float = audio_float / max_val * 0.95

        # Convert to int16 for WAV
        audio_int16 = (audio_float * 32767).astype(np.int16)

        # Write normalized WAV to shared tracks directory
        final_path = TRACKS_DIR / f"{uuid.uuid4()}.wav"
        print(f"Writing final WAV to {final_path}...")
        wavfile.write(str(final_path), sample_rate, audio_int16)
        print(f"Final WAV written: {os.path.getsize(final_path)} bytes")

        duration_secs = len(audio_float) / sample_rate
        print(f"Returning response: path={final_path}, sr={sample_rate}, duration={duration_secs:.1f}s")
        return GenerationResponse(
            audio_path=str(final_path),
            sample_rate=sample_rate,
            duration=duration_secs,
        )

    finally:
        # Clean up temp directory
        import shutil
        shutil.rmtree(temp_dir, ignore_errors=True)
        # Clear MPS cache after generation
        _clear_mps_cache()


async def generate_acestep_http(request: GenerationRequest) -> GenerationResponse:
    """Generate music using ACE-Step v1.5 model (HTTP wrapper)."""
    try:
        loop = asyncio.get_event_loop()
        return await loop.run_in_executor(
            _executor,
            _generate_acestep_sync,
            request,
            lambda p, m: None,
        )
    except ImportError:
        raise HTTPException(
            status_code=501,
            detail="ACE-Step v1.5 not installed. Install with: pip install git+https://github.com/ace-step/ACE-Step-1.5.git",
        )
    except Exception as e:
        raise HTTPException(status_code=500, detail=str(e))


# MARK: - WebSocket Generation Endpoint

@app.websocket("/ws/generate")
async def ws_generate(websocket: WebSocket):
    """WebSocket endpoint for generation with real-time progress."""
    await websocket.accept()

    try:
        # 1. Receive generation request from client
        raw = await websocket.receive_text()
        print(f"WebSocket: received request: {raw[:500]}")
        data = json.loads(raw)
        request = GenerationRequest(**data)
        print(f"WebSocket: parsed request OK - task_type={request.task_type}, model={request.model}")

        # Validate model
        model_info = MODEL_REGISTRY.get(request.model)
        if not model_info:
            await websocket.send_json({"type": "error", "detail": f"Unknown model: {request.model}"})
            return

        if request.duration > model_info.max_duration:
            await websocket.send_json({
                "type": "error",
                "detail": f"Max duration for {request.model} is {model_info.max_duration}s, got {request.duration}s",
            })
            return

        # Validate cover mode params
        if request.task_type == "cover":
            if not request.source_audio_path:
                await websocket.send_json({
                    "type": "error",
                    "detail": "Cover mode requires source_audio_path",
                })
                return
            if not os.path.exists(request.source_audio_path):
                await websocket.send_json({
                    "type": "error",
                    "detail": f"Source audio not found: {request.source_audio_path}",
                })
                return

        # 2. Set up progress queue (thread-safe bridge from sync -> async)
        progress_queue: queue.Queue = queue.Queue()

        def progress_cb(progress: float, message: str):
            progress_queue.put(("progress", progress, message))

        # 3. Run generation in thread pool
        loop = asyncio.get_event_loop()
        gen_future = loop.run_in_executor(_executor, _generate_acestep_sync, request, progress_cb)

        # 4. Forward progress messages and send heartbeats while waiting
        while True:
            # Check for progress messages (non-blocking)
            try:
                while True:
                    msg_type, progress, message = progress_queue.get_nowait()
                    await websocket.send_json({
                        "type": msg_type,
                        "progress": progress,
                        "message": message,
                    })
            except queue.Empty:
                pass

            # Check if generation is done
            if gen_future.done():
                break

            # Send heartbeat to keep connection alive
            await websocket.send_json({"type": "heartbeat"})
            await asyncio.sleep(2)

        # 5. Drain any remaining progress messages
        try:
            while True:
                msg_type, progress, message = progress_queue.get_nowait()
                await websocket.send_json({
                    "type": msg_type,
                    "progress": progress,
                    "message": message,
                })
        except queue.Empty:
            pass

        # 6. Get result or propagate error
        print("WebSocket: getting generation result...")
        result: GenerationResponse = gen_future.result()
        print(f"WebSocket: sending complete response - {result.audio_path}")

        await websocket.send_json({
            "type": "complete",
            "audio_path": result.audio_path,
            "sample_rate": result.sample_rate,
            "duration": result.duration,
        })
        print("WebSocket: complete message sent successfully")

    except WebSocketDisconnect:
        # Client disconnected (e.g. cancelled) - nothing to do
        print("WebSocket: client disconnected")
    except Exception as e:
        import traceback
        print(f"WebSocket generation error: {e}")
        traceback.print_exc()
        try:
            await websocket.send_json({"type": "error", "detail": str(e)})
        except Exception:
            pass  # Connection already closed


# MARK: - Model Deletion Endpoint

@app.delete("/models/{model_name}")
async def delete_model(model_name: str):
    """Unload a model from memory"""
    global _pipeline, _pipeline_initialized

    if model_name == "acestep" and _pipeline_initialized:
        _pipeline = None
        _pipeline_initialized = False
        _clear_mps_cache()
        return {"status": "deleted", "model": model_name}

    return {"status": "not_loaded", "model": model_name}


if __name__ == "__main__":
    import uvicorn
    uvicorn.run(app, host="0.0.0.0", port=8000)
