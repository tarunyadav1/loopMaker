"""
LoopMaker Python Backend
FastAPI server for MusicGen and ACE-Step audio generation
"""

import asyncio
import base64
import io
import os
import platform
from dataclasses import dataclass
from enum import Enum
from pathlib import Path
from typing import Optional

import numpy as np
import torch
from fastapi import FastAPI, HTTPException
from fastapi.middleware.cors import CORSMiddleware
from fastapi.responses import StreamingResponse
from pydantic import BaseModel
from transformers import AutoProcessor, MusicgenForConditionalGeneration
import scipy.io.wavfile as wavfile

app = FastAPI(
    title="LoopMaker Backend",
    description="AI Music Generation API powered by MusicGen and ACE-Step",
    version="1.1.0"
)

# CORS for Swift app communication
app.add_middleware(
    CORSMiddleware,
    allow_origins=["*"],
    allow_credentials=True,
    allow_methods=["*"],
    allow_headers=["*"],
)


# MARK: - Model Registry

class ModelFamily(str, Enum):
    MUSICGEN = "musicgen"
    ACESTEP = "acestep"


@dataclass
class ModelInfo:
    hf_name: str
    family: ModelFamily
    size_gb: float
    min_ram_gb: int
    max_duration: int
    supports_lyrics: bool


MODEL_REGISTRY = {
    "small": ModelInfo("facebook/musicgen-small", ModelFamily.MUSICGEN, 1.2, 8, 60, False),
    "medium": ModelInfo("facebook/musicgen-medium", ModelFamily.MUSICGEN, 6.0, 16, 60, False),
    "acestep": ModelInfo("ACE-Step/ACE-Step-v1-3.5B", ModelFamily.ACESTEP, 7.0, 16, 240, True),
}

# Backwards compatibility
MODEL_NAMES = {k: v.hf_name for k, v in MODEL_REGISTRY.items() if v.family == ModelFamily.MUSICGEN}


# MARK: - Model Caches

models: dict = {}
processors: dict = {}
acestep_pipelines: dict = {}

# Configuration
MODEL_CACHE_DIR = Path.home() / ".cache" / "loopmaker" / "models"
MODEL_CACHE_DIR.mkdir(parents=True, exist_ok=True)


# MARK: - Request/Response Models

class GenerationRequest(BaseModel):
    prompt: str
    duration: int = 30  # seconds
    model: str = "small"
    seed: Optional[int] = None
    # ACE-Step specific
    lyrics: Optional[str] = None
    quality_mode: str = "fast"  # "fast" (27 steps) or "quality" (60 steps)
    guidance_scale: float = 15.0


class GenerationResponse(BaseModel):
    audio: str  # base64 encoded WAV
    sample_rate: int
    duration: float


class DownloadRequest(BaseModel):
    model: str


# MARK: - Device Detection

def get_device() -> str:
    """Detect optimal device for inference."""
    if torch.cuda.is_available():
        return "cuda"
    elif torch.backends.mps.is_available():
        return "mps"
    return "cpu"


# MARK: - Model Loaders

def load_musicgen_model(model_name: str):
    """Load MusicGen model if not already loaded."""
    if model_name not in models:
        hf_name = MODEL_NAMES.get(model_name)
        if not hf_name:
            raise ValueError(f"Unknown MusicGen model: {model_name}")

        print(f"Loading MusicGen model: {hf_name}")
        models[model_name] = MusicgenForConditionalGeneration.from_pretrained(hf_name)
        processors[model_name] = AutoProcessor.from_pretrained(hf_name)

    return models[model_name], processors[model_name]


def load_acestep_model(model_name: str):
    """Load ACE-Step model with Mac-specific configuration."""
    if model_name not in acestep_pipelines:
        model_info = MODEL_REGISTRY.get(model_name)
        if not model_info or model_info.family != ModelFamily.ACESTEP:
            raise ValueError(f"Unknown ACE-Step model: {model_name}")

        print(f"Loading ACE-Step model: {model_info.hf_name}")

        try:
            from acestep.pipeline_ace_step import ACEStepPipeline
        except ImportError:
            raise ImportError(
                "ACE-Step not installed. Install with: "
                "pip install git+https://github.com/ace-step/ACE-Step.git"
            )

        is_mac = platform.system() == "Darwin"

        # Use float32 on Mac (bf16 not fully supported), bfloat16 on CUDA
        dtype = "float32" if is_mac else "bfloat16"

        # ACEStepPipeline downloads model automatically when checkpoint_dir=None
        # Use quantized version for smaller memory footprint
        acestep_pipelines[model_name] = ACEStepPipeline(
            checkpoint_dir=None,  # Will download from HuggingFace
            dtype=dtype,
            device_id=0,
            cpu_offload=is_mac,  # Enable CPU offload on Mac to save memory
            quantized=False,  # Use full precision for better quality
        )

    return acestep_pipelines[model_name]


# MARK: - Health Endpoint

@app.get("/health")
async def health_check():
    """Health check endpoint"""
    return {
        "status": "healthy",
        "models_loaded": list(models.keys()) + list(acestep_pipelines.keys()),
        "device": get_device()
    }


# MARK: - Model Status Endpoint

@app.get("/models/status")
async def get_model_status():
    """Check which models are downloaded and their capabilities"""
    status = {}
    for name, info in MODEL_REGISTRY.items():
        cache_path = MODEL_CACHE_DIR / name
        is_loaded = name in models or name in acestep_pipelines

        status[name] = {
            "downloaded": cache_path.exists() or is_loaded,
            "loaded": is_loaded,
            "family": info.family.value,
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

            if model_info.family == ModelFamily.MUSICGEN:
                # Download MusicGen
                hf_name = model_info.hf_name
                processor = AutoProcessor.from_pretrained(hf_name)
                yield f'{{"status": "downloading", "progress": 0.3}}\n'

                model = MusicgenForConditionalGeneration.from_pretrained(hf_name)
                yield f'{{"status": "downloading", "progress": 0.8}}\n'

                models[request.model] = model
                processors[request.model] = processor

            elif model_info.family == ModelFamily.ACESTEP:
                # Download ACE-Step
                yield f'{{"status": "downloading", "progress": 0.2}}\n'
                try:
                    pipeline = load_acestep_model(request.model)
                    yield f'{{"status": "downloading", "progress": 0.8}}\n'
                except ImportError as e:
                    yield f'{{"status": "error", "error": "{str(e)}"}}\n'
                    return

            yield f'{{"status": "complete", "progress": 1.0}}\n'

        except Exception as e:
            yield f'{{"status": "error", "error": "{str(e)}"}}\n'

    return StreamingResponse(
        stream_progress(),
        media_type="application/x-ndjson"
    )


# MARK: - Generation Endpoint

@app.post("/generate", response_model=GenerationResponse)
async def generate_music(request: GenerationRequest):
    """Generate music from text prompt - routes to appropriate model family"""
    model_info = MODEL_REGISTRY.get(request.model)
    if not model_info:
        raise HTTPException(status_code=400, detail=f"Unknown model: {request.model}")

    if request.duration > model_info.max_duration:
        raise HTTPException(
            status_code=400,
            detail=f"Max duration for {request.model} is {model_info.max_duration}s, got {request.duration}s"
        )

    if model_info.family == ModelFamily.MUSICGEN:
        return await generate_musicgen(request)
    else:
        return await generate_acestep(request)


async def generate_musicgen(request: GenerationRequest) -> GenerationResponse:
    """Generate music using MusicGen model."""
    try:
        model, processor = load_musicgen_model(request.model)

        # Set seed for reproducibility
        if request.seed is not None:
            torch.manual_seed(request.seed)
            np.random.seed(request.seed)

        # Prepare inputs
        inputs = processor(
            text=[request.prompt],
            padding=True,
            return_tensors="pt",
        )

        # Calculate max new tokens based on duration
        # MusicGen generates at ~50 tokens per second
        sample_rate = model.config.audio_encoder.sampling_rate
        tokens_per_second = model.config.audio_encoder.frame_rate
        max_new_tokens = int(request.duration * tokens_per_second)

        # Generate audio
        with torch.no_grad():
            audio_values = model.generate(
                **inputs,
                max_new_tokens=max_new_tokens,
                do_sample=True,
            )

        # Convert to numpy
        audio_data = audio_values[0, 0].cpu().numpy()

        # Normalize audio
        audio_data = audio_data / np.max(np.abs(audio_data)) * 0.95

        # Convert to int16 for WAV
        audio_int16 = (audio_data * 32767).astype(np.int16)

        # Create WAV file in memory
        wav_buffer = io.BytesIO()
        wavfile.write(wav_buffer, sample_rate, audio_int16)
        wav_buffer.seek(0)

        # Encode to base64
        audio_base64 = base64.b64encode(wav_buffer.read()).decode("utf-8")

        return GenerationResponse(
            audio=audio_base64,
            sample_rate=sample_rate,
            duration=len(audio_data) / sample_rate
        )

    except Exception as e:
        raise HTTPException(status_code=500, detail=str(e))


async def generate_acestep(request: GenerationRequest) -> GenerationResponse:
    """Generate music using ACE-Step model."""
    import tempfile
    import os

    try:
        pipeline = load_acestep_model(request.model)

        # Set seed (None for random)
        manual_seeds = [request.seed] if request.seed is not None else None

        # Quality mode determines inference steps
        infer_steps = 60 if request.quality_mode == "quality" else 27

        # Default to instrumental if no lyrics provided
        lyrics = request.lyrics if request.lyrics else "[inst]"

        # Create temp file for output
        with tempfile.NamedTemporaryFile(suffix=".wav", delete=False) as tmp:
            temp_path = tmp.name

        try:
            # Generate audio using __call__ method
            pipeline(
                prompt=request.prompt,
                lyrics=lyrics,
                audio_duration=float(request.duration),
                guidance_scale=request.guidance_scale,
                manual_seeds=manual_seeds,
                infer_step=infer_steps,
                scheduler_type="euler",
                format="wav",
                save_path=temp_path,
            )

            # Read the generated audio file
            sample_rate, audio_data = wavfile.read(temp_path)

            # Convert to float for normalization
            if audio_data.dtype == np.int16:
                audio_float = audio_data.astype(np.float32) / 32767.0
            elif audio_data.dtype == np.int32:
                audio_float = audio_data.astype(np.float32) / 2147483647.0
            else:
                audio_float = audio_data.astype(np.float32)

            # Handle stereo by taking first channel or averaging
            if audio_float.ndim > 1:
                audio_float = audio_float.mean(axis=1)

            # Normalize audio
            max_val = np.max(np.abs(audio_float))
            if max_val > 0:
                audio_float = audio_float / max_val * 0.95

            # Convert to int16 for WAV
            audio_int16 = (audio_float * 32767).astype(np.int16)

            # Create WAV file in memory
            wav_buffer = io.BytesIO()
            wavfile.write(wav_buffer, sample_rate, audio_int16)
            wav_buffer.seek(0)

            # Encode to base64
            audio_base64 = base64.b64encode(wav_buffer.read()).decode("utf-8")

            return GenerationResponse(
                audio=audio_base64,
                sample_rate=sample_rate,
                duration=len(audio_float) / sample_rate
            )

        finally:
            # Clean up temp file
            if os.path.exists(temp_path):
                os.remove(temp_path)

    except ImportError as e:
        raise HTTPException(
            status_code=501,
            detail="ACE-Step not installed. Install with: pip install git+https://github.com/ace-step/ACE-Step.git"
        )
    except Exception as e:
        raise HTTPException(status_code=500, detail=str(e))


# MARK: - Model Deletion Endpoint

@app.delete("/models/{model_name}")
async def delete_model(model_name: str):
    """Unload a model from memory"""
    deleted = False

    if model_name in models:
        del models[model_name]
        del processors[model_name]
        deleted = True

    if model_name in acestep_pipelines:
        del acestep_pipelines[model_name]
        deleted = True

    if deleted:
        return {"status": "deleted", "model": model_name}
    return {"status": "not_loaded", "model": model_name}


if __name__ == "__main__":
    import uvicorn
    uvicorn.run(app, host="0.0.0.0", port=8000)
