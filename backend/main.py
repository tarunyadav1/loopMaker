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

# Note: PyTorch 2.10's MPS backend has multiple buggy Metal shaders
# (masked_fill_scalar_strided_32bit, mul_dense_scalar_float_float) that crash
# with fatal Metal validation assertions. The DiT model is forced to CPU to
# avoid these. The LM uses MLX (native Apple Silicon) so it's still fast.
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

# ACE-Step v1.5 handlers (separate DiT + LM architecture)
_acestep_dit_handler = None
_acestep_llm_handler = None
_acestep_initialized = False

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

def _ensure_acestep_weights_downloaded():
    """Ensure ACE-Step model weights are actually downloaded.

    The pip install of ACE-Step v1.5 creates the checkpoints/ directory structure
    with config files but NOT the large model weight files (Git LFS).
    The handler's check_main_model_exists() only checks directory existence,
    so it gets fooled. We explicitly check for weight files and download if missing.
    """
    import acestep
    from acestep.model_downloader import (
        download_main_model,
        download_submodel,
        check_model_exists,
    )

    # The handler's _get_project_root() returns parent of acestep package dir
    project_root = Path(os.path.dirname(os.path.dirname(os.path.abspath(acestep.__file__))))
    checkpoint_dir = project_root / "checkpoints"
    checkpoint_dir.mkdir(parents=True, exist_ok=True)

    # Check for actual model weight files (not just directory existence).
    # Weight files can be model.safetensors, pytorch_model.bin, or sharded variants.
    def _has_weight_files(model_dir: Path) -> bool:
        if not model_dir.exists():
            return False
        return (
            any(model_dir.glob("model*.safetensors"))
            or any(model_dir.glob("pytorch_model*.bin"))
        )

    dit_dir = checkpoint_dir / "acestep-v15-turbo"
    qwen_dir = checkpoint_dir / "Qwen3-Embedding-0.6B"

    if not _has_weight_files(dit_dir) or not _has_weight_files(qwen_dir):
        print("ACE-Step model weights not found — downloading from HuggingFace...")
        print(f"Destination: {checkpoint_dir}")
        print("This may take 5-30 minutes depending on your connection (~5GB)...")
        success, msg = download_main_model(checkpoint_dir, force=True)
        if not success:
            raise RuntimeError(f"Failed to download ACE-Step main model: {msg}")
        print(f"Main model download: {msg}")

    # Download 0.6B LM separately (not included in main model, which has 1.7B)
    lm_dir = checkpoint_dir / "acestep-5Hz-lm-0.6B"
    if not _has_weight_files(lm_dir):
        print("Downloading ACE-Step 0.6B LM model...")
        success, msg = download_submodel("acestep-5Hz-lm-0.6B", checkpoint_dir)
        if not success:
            print(f"WARNING: Failed to download 0.6B LM: {msg}")
            print("Generation will work without prompt enhancement.")
        else:
            print(f"LM download: {msg}")

    return str(checkpoint_dir)


def load_acestep_model():
    """Load ACE-Step v1.5 model with Mac-specific configuration.

    v1.5 uses a two-handler architecture:
    - AceStepHandler (DiT): The audio generation model (~2B params)
    - LLMHandler (LM): Optional language model for prompt enhancement (0.6B-4B)
    """
    global _acestep_dit_handler, _acestep_llm_handler, _acestep_initialized

    if _acestep_initialized:
        return _acestep_dit_handler, _acestep_llm_handler

    try:
        from acestep.handler import AceStepHandler
        from acestep.llm_inference import LLMHandler
    except ImportError:
        raise ImportError(
            "ACE-Step v1.5 not installed. Install with: "
            "pip install git+https://github.com/ace-step/ACE-Step-1.5.git"
        )

    is_mac = platform.system() == "Darwin"

    # Clear memory before loading
    _clear_mps_cache()

    # Ensure model weights are actually downloaded (pip install only gets configs)
    checkpoint_dir = _ensure_acestep_weights_downloaded()

    # On Mac, force CPU for DiT inference. PyTorch 2.10's MPS backend has
    # multiple buggy Metal shaders (masked_fill_scalar_strided_32bit,
    # mul_dense_scalar_float_float) that crash with fatal Metal validation
    # assertions. CPU is slower but reliable. The LM uses MLX (native Apple
    # Silicon) so it's still fast. Can revisit when PyTorch fixes MPS shaders.
    dit_device = "cpu" if is_mac else "auto"

    print(f"Loading ACE-Step v1.5 DiT model (acestep-v15-turbo) on {dit_device}...")
    _acestep_dit_handler = AceStepHandler()
    status_msg, ready = _acestep_dit_handler.initialize_service(
        project_root="",  # Handler auto-detects via _get_project_root()
        config_path="acestep-v15-turbo",
        device=dit_device,
        use_flash_attention=False,
        compile_model=False,
        offload_to_cpu=False,  # Already on CPU, no need to offload
        offload_dit_to_cpu=False,
    )
    print(f"DiT status: {status_msg}")

    if not ready:
        raise RuntimeError(f"Failed to initialize ACE-Step DiT: {status_msg}")

    # Load 0.6B LM for prompt enhancement (smallest variant for 16GB Macs)
    print("Loading ACE-Step v1.5 LM (0.6B)...")
    _acestep_llm_handler = LLMHandler()
    lm_status, lm_ready = _acestep_llm_handler.initialize(
        checkpoint_dir=checkpoint_dir,  # Must point to actual checkpoints dir
        lm_model_path="acestep-5Hz-lm-0.6B",
        backend="mlx" if is_mac else "pt",  # MLX for native Apple Silicon acceleration
        device="auto",
        offload_to_cpu=is_mac,
    )
    print(f"LM status: {lm_status}")

    if not lm_ready:
        # LM is optional — generation works without it, just less refined prompts
        print("WARNING: LM failed to load, generation will work without prompt enhancement")
        _acestep_llm_handler = None

    _acestep_initialized = True
    return _acestep_dit_handler, _acestep_llm_handler


# MARK: - Health Endpoint

@app.get("/health")
async def health_check():
    """Health check endpoint"""
    return {
        "status": "healthy",
        "models_loaded": ["acestep"] if _acestep_initialized else [],
        "device": get_device()
    }


# MARK: - Model Status Endpoint

@app.get("/models/status")
async def get_model_status():
    """Check which models are downloaded and their capabilities"""
    status = {}
    for name, info in MODEL_REGISTRY.items():
        cache_path = MODEL_CACHE_DIR / name
        is_loaded = name == "acestep" and _acestep_initialized

        status[name] = {
            "downloaded": cache_path.exists() or is_loaded,
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
                load_acestep_model,
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

    Uses the two-handler architecture:
    - AceStepHandler (DiT) for audio generation
    - LLMHandler (LM) for optional prompt enhancement
    """
    import tempfile

    # Clear MPS cache before generation
    _clear_mps_cache()

    progress_cb(0.05, "Loading ACE-Step v1.5 model...")
    dit_handler, llm_handler = load_acestep_model()

    try:
        from acestep.inference import generate_music as ace_generate, GenerationParams, GenerationConfig
    except ImportError:
        raise ImportError(
            "ACE-Step v1.5 not installed. Install with: "
            "pip install git+https://github.com/ace-step/ACE-Step-1.5.git"
        )

    # Quality mode determines inference steps and method
    if request.quality_mode == "draft":
        infer_steps = 4
    elif request.quality_mode == "quality":
        infer_steps = 50
    else:  # "fast" (default)
        infer_steps = 8

    # Default to instrumental if no lyrics provided
    lyrics = request.lyrics if request.lyrics else "[inst]"
    is_instrumental = lyrics == "[inst]"

    # Determine if thinking (LM enhancement) should be enabled
    use_thinking = llm_handler is not None

    progress_cb(0.10, "Preparing generation parameters...")

    # Set up v1.5 generation parameters
    params = GenerationParams(
        task_type="text2music",
        caption=request.prompt,
        lyrics=lyrics,
        instrumental=is_instrumental,
        duration=float(request.duration),
        inference_steps=infer_steps,
        seed=request.seed if request.seed is not None else -1,  # -1 = random
        guidance_scale=request.guidance_scale,
        shift=1.0,  # Default for turbo models
        infer_method="ode",
        thinking=use_thinking,
        lm_temperature=0.85,
        lm_cfg_scale=2.0,
        use_cot_metas=use_thinking,
        use_cot_caption=use_thinking,
        use_cot_language=use_thinking,
    )

    config = GenerationConfig(
        batch_size=1,
        allow_lm_batch=False,
        use_random_seed=(request.seed is None),
        audio_format="wav",
    )

    # Create temp directory for output
    temp_dir = tempfile.mkdtemp(prefix="loopmaker_")

    try:
        progress_cb(0.15, "Generating audio (ACE-Step v1.5)...")

        # Run generation
        result = ace_generate(
            dit_handler=dit_handler,
            llm_handler=llm_handler,
            params=params,
            config=config,
            save_dir=temp_dir,
        )

        if not result.success:
            raise RuntimeError(f"ACE-Step generation failed: {result.status_message}")

        progress_cb(0.85, "Processing audio...")

        # Find the generated audio file
        generated_files = list(Path(temp_dir).glob("*.wav"))
        if not generated_files:
            # Try other formats
            generated_files = list(Path(temp_dir).glob("*.flac")) + list(Path(temp_dir).glob("*.mp3"))

        if not generated_files:
            raise RuntimeError("ACE-Step generated no audio files")

        # Read the first generated file
        temp_audio_path = str(generated_files[0])
        sample_rate, audio_data = wavfile.read(temp_audio_path)

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
        output_path = TRACKS_DIR / f"{uuid.uuid4()}.wav"
        wavfile.write(str(output_path), sample_rate, audio_int16)

        return GenerationResponse(
            audio_path=str(output_path),
            sample_rate=sample_rate,
            duration=len(audio_float) / sample_rate,
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
        data = json.loads(raw)
        request = GenerationRequest(**data)

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
        result: GenerationResponse = gen_future.result()

        await websocket.send_json({
            "type": "complete",
            "audio_path": result.audio_path,
            "sample_rate": result.sample_rate,
            "duration": result.duration,
        })

    except WebSocketDisconnect:
        # Client disconnected (e.g. cancelled) - nothing to do
        pass
    except Exception as e:
        try:
            await websocket.send_json({"type": "error", "detail": str(e)})
        except Exception:
            pass  # Connection already closed


# MARK: - Model Deletion Endpoint

@app.delete("/models/{model_name}")
async def delete_model(model_name: str):
    """Unload a model from memory"""
    global _acestep_dit_handler, _acestep_llm_handler, _acestep_initialized

    if model_name == "acestep" and _acestep_initialized:
        _acestep_dit_handler = None
        _acestep_llm_handler = None
        _acestep_initialized = False
        _clear_mps_cache()
        return {"status": "deleted", "model": model_name}

    return {"status": "not_loaded", "model": model_name}


if __name__ == "__main__":
    import uvicorn
    uvicorn.run(app, host="0.0.0.0", port=8000)
