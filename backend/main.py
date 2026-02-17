"""
LoopMaker Python Backend
FastAPI server for ACE-Step v1.5 audio generation
"""

import asyncio
import json
import os
import platform
import queue
import threading
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
# Metal shader bugs. The handler uses offload_to_cpu=True for stability.
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

# ACE-Step v1.5 handler (singleton)
_handler = None
_handler_initialized = False

# Writable app support directory (avoid writing into the signed .app bundle).
APP_SUPPORT_DIR = Path.home() / "Library" / "Application Support" / "LoopMaker"
APP_SUPPORT_DIR.mkdir(parents=True, exist_ok=True)

# ACE-Step expects checkpoints under "<project_root>/checkpoints".
CHECKPOINTS_DIR = APP_SUPPORT_DIR / "checkpoints"
CHECKPOINTS_DIR.mkdir(parents=True, exist_ok=True)

# Shared output directory (must match Swift's track storage path).
TRACKS_DIR = APP_SUPPORT_DIR / "tracks"
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
    task_type: str = "text2music"  # "text2music", "cover", or "repaint"
    source_audio_path: Optional[str] = None  # absolute path for cover/repaint mode
    ref_audio_strength: float = 0.5  # 0.0-1.0, how much reference audio influences output
    repainting_start: Optional[float] = None  # repaint mode: start of repaint region (seconds)
    repainting_end: Optional[float] = None  # repaint mode: end of repaint region (seconds)
    batch_size: int = 1  # number of variations to generate (1-8)
    # Music metadata — prepended to caption for ACE-Step conditioning
    bpm: Optional[int] = None  # beats per minute (30-300)
    music_key: Optional[str] = None  # e.g. "C major", "A minor"
    time_signature: Optional[str] = None  # e.g. "4/4", "3/4", "6/8"


class GenerationResponse(BaseModel):
    audio_path: str  # path to generated WAV file
    sample_rate: int
    duration: float
    seed: Optional[int] = None


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

def _load_handler():
    """Load ACE-Step v1.5 handler with Mac-specific configuration.

    Uses AceStepHandler which manages DiT + LM internally.
    Downloads model weights via ensure_main_model() if missing.
    """
    global _handler, _handler_initialized

    if _handler_initialized:
        return _handler

    try:
        from acestep.handler import AceStepHandler
        from acestep.model_downloader import ensure_main_model, download_main_model
    except ImportError:
        raise ImportError(
            "Music engine components not installed. Please reinstall the application."
        )

    # Clear memory before loading
    _clear_mps_cache()

    # Ensure model weights are downloaded (idempotent — returns immediately if present)
    print("Ensuring ACE-Step v1.5 model weights are available...")
    success, message = ensure_main_model(CHECKPOINTS_DIR)
    print(f"Model check: {message}")
    if not success:
        raise RuntimeError(f"Failed to download required files: {message}")

    # The upstream check only verifies directories exist, not that weight files
    # are present. Verify the actual model weights exist and force re-download
    # if the checkpoint directory is incomplete.
    _WEIGHT_FILENAMES = [
        "model.safetensors", "pytorch_model.bin",
        "model.safetensors.index.json", "pytorch_model.bin.index.json",
    ]
    turbo_dir = CHECKPOINTS_DIR / "acestep-v15-turbo"
    has_weights = any((turbo_dir / f).exists() for f in _WEIGHT_FILENAMES)
    if not has_weights:
        print("Weight files missing in acestep-v15-turbo — forcing re-download...")
        success, message = download_main_model(CHECKPOINTS_DIR, force=True)
        print(f"Re-download result: {message}")
        if not success:
            raise RuntimeError(f"Failed to download model weights: {message}")
        has_weights = any((turbo_dir / f).exists() for f in _WEIGHT_FILENAMES)
        if not has_weights:
            raise RuntimeError(
                "Model download completed but weight files are still missing in "
                f"{turbo_dir}. Please delete the checkpoints directory and retry."
            )

    # Initialize handler
    # Force CPU for PyTorch components on macOS — MPS has fatal Metal shader bugs
    # (mul_dense_scalar_float_float, masked_fill_scalar_strided_32bit, etc.)
    # that crash with validateComputeFunctionArguments assertions.
    # MLX components (DiT, VAE) still use GPU natively via use_mlx_dit=True.
    device = "cpu" if platform.system() == "Darwin" else "auto"

    print(f"Initializing ACE-Step v1.5 handler (device={device})...")
    _handler = AceStepHandler()

    # ACE-Step derives its "project root" from where the package lives, which in a
    # release build is inside the signed .app bundle. Force all checkpoints/cache
    # writes into Application Support so the app isn't self-modifying.
    _handler._get_project_root = lambda: str(APP_SUPPORT_DIR)  # type: ignore[attr-defined]
    _handler._progress_estimates_path = os.path.join(  # type: ignore[attr-defined]
        str(APP_SUPPORT_DIR),
        ".cache",
        "acestep",
        "progress_estimates.json",
    )
    try:
        _handler._load_progress_estimates()  # type: ignore[attr-defined]
    except Exception:
        pass

    status, enabled = _handler.initialize_service(
        project_root=str(APP_SUPPORT_DIR),
        config_path="acestep-v15-turbo",
        device=device,
        offload_to_cpu=True,
        use_mlx_dit=True,
    )
    print(f"ACE-Step handler initialized: {status} (enabled={enabled})")

    if not enabled:
        raise RuntimeError(f"Music engine failed to initialize: {status}")

    _handler_initialized = True
    return _handler


# MARK: - Health Endpoint

@app.get("/health")
async def health_check():
    """Health check endpoint"""
    return {
        "status": "healthy",
        "models_loaded": ["acestep"] if _handler_initialized else [],
        "device": get_device()
    }


# MARK: - Model Status Endpoint

@app.get("/models/status")
async def get_model_status():
    """Check which models are downloaded and their capabilities"""
    status = {}
    for name, info in MODEL_REGISTRY.items():
        is_loaded = name == "acestep" and _handler_initialized

        # Check if model weights exist locally
        is_downloaded = is_loaded
        if name == "acestep" and not is_downloaded:
            try:
                from acestep.model_downloader import check_main_model_exists
                is_downloaded = check_main_model_exists(CHECKPOINTS_DIR)
            except ImportError:
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
            yield f'{{"status": "downloading", "progress": 0.15, "message": "Initializing download..."}}\n'

            loop = asyncio.get_event_loop()
            load_future = loop.run_in_executor(
                _executor,
                _load_handler,
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
                yield f'{{"status": "downloading", "progress": {progress:.3f}, "message": "Downloading required files ({elapsed_min:.1f} min elapsed)..."}}\n'

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


class GenerationCancelledError(Exception):
    """Raised when the client cancels an in-flight generation."""
    pass


def _generate_acestep_sync(
    request: GenerationRequest,
    progress_cb: ProgressCallback,
    cancel_event: Optional[threading.Event] = None,
) -> list[GenerationResponse]:
    """Synchronous ACE-Step v1.5 generation with progress callbacks.

    Uses AceStepHandler.generate_music() which returns audio tensors directly.
    Supports text2music and cover (audio2audio) task types.
    Returns a list of GenerationResponse (one per batch item).
    """
    def _throw_if_cancelled():
        if cancel_event is not None and cancel_event.is_set():
            raise GenerationCancelledError("Generation cancelled by user")

    # Clear MPS cache before generation
    _clear_mps_cache()

    _throw_if_cancelled()
    progress_cb(0.05, "Loading music engine...")
    handler = _load_handler()
    _throw_if_cancelled()

    # Quality mode determines inference steps
    if request.quality_mode == "draft":
        infer_steps = 4
    elif request.quality_mode == "quality":
        infer_steps = 50
    else:  # "fast" (default)
        infer_steps = 8

    # Default to instrumental if no lyrics provided.
    # Empty string "" means "keep source vocals" (used in cover mode).
    if request.lyrics is not None:
        lyrics = request.lyrics
    else:
        lyrics = "[inst]"

    # Cover mode: audio2audio via reference audio
    is_cover = request.task_type == "cover"
    is_repaint = request.task_type == "repaint"

    if (is_cover or is_repaint) and request.source_audio_path:
        if not os.path.exists(request.source_audio_path):
            raise FileNotFoundError(f"Source audio not found: {request.source_audio_path}")

    # For repaint mode, override duration to repaint end
    if is_repaint and request.repainting_end is not None:
        duration = float(request.repainting_end)
    else:
        duration = float(request.duration)

    # Infer duration from source audio if cover mode and duration is 0
    if is_cover and duration == 0 and request.source_audio_path:
        try:
            sr, audio = wavfile.read(request.source_audio_path)
            duration = len(audio) / sr
        except Exception:
            duration = 30.0  # fallback

    batch_size = max(1, min(request.batch_size, 8))
    if request.seed is not None:
        effective_seed = int(request.seed) & 0x7FFFFFFF
    else:
        effective_seed = int.from_bytes(os.urandom(4), "big") & 0x7FFFFFFF

    # Build enriched caption with music metadata tags
    caption_parts = []
    if request.bpm is not None:
        caption_parts.append(f"BPM: {request.bpm}")
    if request.music_key:
        caption_parts.append(f"Key: {request.music_key}")
    if request.time_signature:
        caption_parts.append(f"Time Signature: {request.time_signature}")
    caption_prefix = ", ".join(caption_parts)
    caption = f"{caption_prefix}. {request.prompt}" if caption_prefix else request.prompt

    progress_cb(0.10, "Preparing generation parameters...")
    _throw_if_cancelled()

    try:
        if is_cover:
            task_label = "Creating cover"
        elif is_repaint:
            task_label = "Extending track"
        else:
            task_label = "Generating audio"

        batch_suffix = f" ({batch_size} variations)" if batch_size > 1 else ""
        progress_cb(0.15, f"{task_label}{batch_suffix}...")

        # Native progress callback: maps handler's 0.0-1.0 range to 0.15-0.85
        def _progress_bridge(val: float, desc: str):
            _throw_if_cancelled()
            mapped = 0.15 + val * 0.70
            progress_cb(mapped, f"{task_label} ({desc})...")

        print(f"Calling ACE-Step v1.5 handler.generate_music() batch_size={batch_size}...")
        import time as _time
        _t0 = _time.time()

        # ACE-Step uses different instruction strings to activate cover/repaint conditioning.
        # Without the cover instruction, is_covers=False and source audio latents are ignored.
        cover_instruction = "Generate audio semantic tokens based on the given conditions:"
        text2music_instruction = "Fill the audio semantic mask based on the given conditions:"
        repaint_instruction = "Repaint the mask area based on the given conditions:"

        if is_cover:
            instruction = cover_instruction
        elif is_repaint:
            instruction = repaint_instruction
        else:
            instruction = text2music_instruction

        # Build kwargs for repaint-specific parameters
        gen_kwargs = dict(
            captions=caption,
            lyrics=lyrics,
            audio_duration=duration,
            inference_steps=infer_steps,
            guidance_scale=request.guidance_scale,
            task_type=request.task_type,
            src_audio=request.source_audio_path if (is_cover or is_repaint) else None,
            audio_cover_strength=request.ref_audio_strength if is_cover else 1.0,
            instruction=instruction,
            reference_audio=request.source_audio_path if is_cover else None,
            batch_size=batch_size,
            seed=effective_seed,
            use_random_seed=False,
            progress=_progress_bridge,
        )

        if is_repaint:
            if request.repainting_start is not None:
                gen_kwargs["repainting_start"] = request.repainting_start
            if request.repainting_end is not None:
                gen_kwargs["repainting_end"] = request.repainting_end

        result = handler.generate_music(**gen_kwargs)
        _throw_if_cancelled()

        print(f"Handler returned in {_time.time() - _t0:.1f}s")

        # Check for errors
        if not result.get("success", False):
            error_msg = result.get("error", "Unknown generation error")
            raise RuntimeError(f"Generation failed: {error_msg}")

        progress_cb(0.85, "Processing audio...")

        # Extract audio tensors from result
        audios = result.get("audios", [])
        if not audios:
            raise RuntimeError("Generation produced no audio")

        responses = []
        for i, audio_dict in enumerate(audios):
            _throw_if_cancelled()
            audio_tensor = audio_dict["tensor"]  # [channels, samples], float32
            sample_rate = audio_dict["sample_rate"]  # 48000

            print(f"Audio {i+1}/{len(audios)}: shape={audio_tensor.shape}, sr={sample_rate}")

            # Convert tensor to numpy
            audio_np = audio_tensor.cpu().numpy()  # [channels, samples]

            # Preserve stereo output from ACE-Step (shape: [channels, samples])
            if audio_np.ndim > 1 and audio_np.shape[0] >= 2:
                # Stereo: transpose to [samples, channels] for scipy WAV
                audio_float = audio_np[:2].T  # [samples, 2]
            elif audio_np.ndim > 1:
                audio_float = audio_np[0]  # single channel
            else:
                audio_float = audio_np

            # Normalize audio
            max_val = np.max(np.abs(audio_float))
            if max_val > 0:
                audio_float = audio_float / max_val * 0.95

            # Convert to int16 for WAV
            audio_int16 = (audio_float * 32767).astype(np.int16)

            # Write normalized WAV to shared tracks directory
            final_path = TRACKS_DIR / f"{uuid.uuid4()}.wav"
            print(f"Writing WAV {i+1} to {final_path}...")
            wavfile.write(str(final_path), sample_rate, audio_int16)
            print(f"WAV {i+1} written: {os.path.getsize(final_path)} bytes")

            num_samples = audio_float.shape[0] if audio_float.ndim > 1 else len(audio_float)
            duration_secs = num_samples / sample_rate

            responses.append(GenerationResponse(
                audio_path=str(final_path),
                sample_rate=sample_rate,
                duration=duration_secs,
                seed=effective_seed,
            ))

        print(f"Returning {len(responses)} response(s)")
        return responses

    finally:
        # Clear MPS cache after generation
        _clear_mps_cache()


async def generate_acestep_http(request: GenerationRequest) -> GenerationResponse:
    """Generate music using ACE-Step v1.5 model (HTTP wrapper).

    Returns first result only (use WebSocket for batch results).
    """
    try:
        loop = asyncio.get_event_loop()
        responses = await loop.run_in_executor(
            _executor,
            _generate_acestep_sync,
            request,
            lambda p, m: None,
        )
        return responses[0]
    except ImportError:
        raise HTTPException(
            status_code=501,
            detail="Music engine components not installed. Please reinstall the application.",
        )
    except Exception as e:
        raise HTTPException(status_code=500, detail=str(e))


# MARK: - WebSocket Generation Endpoint

@app.websocket("/ws/generate")
async def ws_generate(websocket: WebSocket):
    """WebSocket endpoint for generation with real-time progress."""
    await websocket.accept()
    cancel_event = threading.Event()
    gen_future = None

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

        # Validate repaint mode params
        if request.task_type == "repaint":
            if not request.source_audio_path:
                await websocket.send_json({
                    "type": "error",
                    "detail": "Repaint/extend mode requires source_audio_path",
                })
                return
            if not os.path.exists(request.source_audio_path):
                await websocket.send_json({
                    "type": "error",
                    "detail": f"Source audio not found: {request.source_audio_path}",
                })
                return
            if request.repainting_end is None:
                await websocket.send_json({
                    "type": "error",
                    "detail": "Repaint/extend mode requires repainting_end",
                })
                return

        # 2. Set up progress queue (thread-safe bridge from sync -> async)
        progress_queue: queue.Queue = queue.Queue()

        def progress_cb(progress: float, message: str):
            progress_queue.put(("progress", progress, message))

        # 3. Run generation in thread pool
        loop = asyncio.get_event_loop()
        gen_future = loop.run_in_executor(_executor, _generate_acestep_sync, request, progress_cb, cancel_event)

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
        results: list[GenerationResponse] = gen_future.result()
        print(f"WebSocket: sending complete response - {len(results)} variation(s)")

        # Send all batch results. audio_path/duration are for backward compat (first result).
        complete_msg = {
            "type": "complete",
            "audio_path": results[0].audio_path,
            "sample_rate": results[0].sample_rate,
            "duration": results[0].duration,
            "audio_paths": [r.audio_path for r in results],
            "durations": [r.duration for r in results],
        }
        # Include the seed that was actually used (useful when random seed was generated)
        if results[0].seed is not None:
            complete_msg["seed"] = results[0].seed
        await websocket.send_json(complete_msg)
        print("WebSocket: complete message sent successfully")

    except GenerationCancelledError:
        print("WebSocket: generation cancelled")
    except WebSocketDisconnect:
        # Client disconnected (e.g. cancelled) - request cooperative cancellation.
        print("WebSocket: client disconnected, requesting cancellation")
        cancel_event.set()
        if gen_future is not None and not gen_future.done():
            gen_future.cancel()
    except Exception as e:
        import traceback
        print(f"WebSocket generation error: {e}")
        traceback.print_exc()
        cancel_event.set()
        try:
            await websocket.send_json({"type": "error", "detail": str(e)})
        except Exception:
            pass  # Connection already closed


# MARK: - Model Deletion Endpoint

@app.delete("/models/{model_name}")
async def delete_model(model_name: str):
    """Unload a model from memory"""
    global _handler, _handler_initialized

    if model_name == "acestep" and _handler_initialized:
        _handler = None
        _handler_initialized = False
        _clear_mps_cache()
        return {"status": "deleted", "model": model_name}

    return {"status": "not_loaded", "model": model_name}


if __name__ == "__main__":
    import uvicorn
    uvicorn.run(app, host="0.0.0.0", port=8000)
