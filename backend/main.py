"""
LoopMaker Python Backend
FastAPI server for MusicGen audio generation
"""

import asyncio
import base64
import io
import os
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
    description="AI Music Generation API powered by MusicGen",
    version="1.0.0"
)

# CORS for Swift app communication
app.add_middleware(
    CORSMiddleware,
    allow_origins=["*"],
    allow_credentials=True,
    allow_methods=["*"],
    allow_headers=["*"],
)

# Model cache
models: dict = {}
processors: dict = {}

# Configuration
MODEL_CACHE_DIR = Path.home() / ".cache" / "loopmaker" / "models"
MODEL_CACHE_DIR.mkdir(parents=True, exist_ok=True)

MODEL_NAMES = {
    "small": "facebook/musicgen-small",
    "medium": "facebook/musicgen-medium",
}


class GenerationRequest(BaseModel):
    prompt: str
    duration: int = 30  # seconds
    model: str = "small"
    seed: Optional[int] = None


class GenerationResponse(BaseModel):
    audio: str  # base64 encoded WAV
    sample_rate: int
    duration: float


class DownloadRequest(BaseModel):
    model: str


@app.get("/health")
async def health_check():
    """Health check endpoint"""
    return {"status": "healthy", "models_loaded": list(models.keys())}


@app.get("/models/status")
async def get_model_status():
    """Check which models are downloaded"""
    status = {}
    for model_name, hf_name in MODEL_NAMES.items():
        # Check if model files exist in cache
        cache_path = MODEL_CACHE_DIR / model_name
        status[model_name] = cache_path.exists() or model_name in models
    return status


@app.post("/models/download")
async def download_model(request: DownloadRequest):
    """Download a model with progress streaming"""
    if request.model not in MODEL_NAMES:
        raise HTTPException(status_code=400, detail=f"Unknown model: {request.model}")

    async def stream_progress():
        try:
            hf_name = MODEL_NAMES[request.model]

            # Stream progress updates
            yield f'{{"status": "downloading", "progress": 0.1}}\n'

            # Download processor
            processor = AutoProcessor.from_pretrained(hf_name)
            yield f'{{"status": "downloading", "progress": 0.3}}\n'

            # Download model
            model = MusicgenForConditionalGeneration.from_pretrained(hf_name)
            yield f'{{"status": "downloading", "progress": 0.8}}\n'

            # Cache the model
            models[request.model] = model
            processors[request.model] = processor

            yield f'{{"status": "complete", "progress": 1.0}}\n'

        except Exception as e:
            yield f'{{"status": "error", "error": "{str(e)}"}}\n'

    return StreamingResponse(
        stream_progress(),
        media_type="application/x-ndjson"
    )


def load_model(model_name: str):
    """Load model if not already loaded"""
    if model_name not in models:
        hf_name = MODEL_NAMES.get(model_name)
        if not hf_name:
            raise ValueError(f"Unknown model: {model_name}")

        print(f"Loading model: {hf_name}")
        models[model_name] = MusicgenForConditionalGeneration.from_pretrained(hf_name)
        processors[model_name] = AutoProcessor.from_pretrained(hf_name)

    return models[model_name], processors[model_name]


@app.post("/generate", response_model=GenerationResponse)
async def generate_music(request: GenerationRequest):
    """Generate music from text prompt"""
    try:
        # Load model
        model, processor = load_model(request.model)

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


@app.delete("/models/{model_name}")
async def delete_model(model_name: str):
    """Unload a model from memory"""
    if model_name in models:
        del models[model_name]
        del processors[model_name]
        return {"status": "deleted", "model": model_name}
    return {"status": "not_loaded", "model": model_name}


if __name__ == "__main__":
    import uvicorn
    uvicorn.run(app, host="0.0.0.0", port=8000)
