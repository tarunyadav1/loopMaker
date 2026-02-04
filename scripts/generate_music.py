#!/usr/bin/env python3
"""
MusicGen Audio Generation - MLX + HuggingFace Backend for LoopMaker
Uses HuggingFace transformers for model loading and generation,
with MLX optimization where available.

Usage: python3 generate_music.py --prompt "..." --output "..." [options]
"""

import argparse
import json
import sys
from pathlib import Path

import numpy as np


def generate_with_transformers(
    model_path: str,
    prompt: str,
    output_path: str,
    duration: float = 10.0,
    temperature: float = 1.0,
    top_k: int = 250,
    guidance_scale: float = 3.0,
    on_progress=None,
):
    """
    Generate music using HuggingFace transformers MusicGen.
    """
    import torch
    from transformers import AutoProcessor, MusicgenForConditionalGeneration

    print(f"Loading model from: {model_path}", file=sys.stderr)

    # Load model and processor
    model = MusicgenForConditionalGeneration.from_pretrained(model_path)
    processor = AutoProcessor.from_pretrained(model_path)

    # Use CPU for MusicGen (MPS has stability issues with this model)
    # MusicGen is CPU-bound anyway due to autoregressive generation
    device = "cpu"
    print(f"Using device: {device}", file=sys.stderr)
    model = model.to(device)

    # Prepare inputs
    print(f"Processing prompt: {prompt}", file=sys.stderr)
    inputs = processor(
        text=[prompt],
        padding=True,
        return_tensors="pt",
    ).to(device)

    # Calculate max_new_tokens based on duration
    # MusicGen generates at ~50 tokens per second of audio
    # The audio encoder frame rate is typically 50 Hz
    max_new_tokens = int(duration * 50)
    print(f"Generating {max_new_tokens} tokens for {duration}s of audio", file=sys.stderr)

    # Progress callback wrapper
    class ProgressCallback:
        def __init__(self, total_tokens, callback):
            self.total_tokens = total_tokens
            self.callback = callback
            self.current = 0

        def __call__(self, *args, **kwargs):
            self.current += 1
            if self.callback:
                progress = min(self.current / self.total_tokens, 0.99)
                self.callback(progress)

    progress_cb = ProgressCallback(max_new_tokens, on_progress) if on_progress else None

    # Generate
    print("Starting generation...", file=sys.stderr)
    with torch.no_grad():
        # Use sampling for more varied output
        audio_values = model.generate(
            **inputs,
            max_new_tokens=max_new_tokens,
            do_sample=True,
            temperature=temperature,
            top_k=top_k,
            guidance_scale=guidance_scale,
        )

    if on_progress:
        on_progress(0.95)

    # Convert to numpy
    print("Processing audio output...", file=sys.stderr)
    audio_np = audio_values[0, 0].cpu().numpy()

    # Get sample rate from model config
    sample_rate = model.config.audio_encoder.sampling_rate
    print(f"Sample rate: {sample_rate}", file=sys.stderr)

    # Normalize audio
    audio_max = np.max(np.abs(audio_np))
    if audio_max > 0:
        audio_np = audio_np / audio_max * 0.95  # Leave headroom

    # Convert to int16
    audio_int16 = (audio_np * 32767).astype(np.int16)

    # Save as WAV
    from scipy.io import wavfile
    wavfile.write(output_path, sample_rate, audio_int16)

    if on_progress:
        on_progress(1.0)

    duration_actual = len(audio_int16) / sample_rate
    print(f"Audio saved: {output_path} ({duration_actual:.2f}s)", file=sys.stderr)

    return {
        "success": True,
        "output_path": output_path,
        "sample_rate": sample_rate,
        "num_samples": len(audio_int16),
        "duration": duration_actual,
    }


def generate_with_mlx(
    model_path: str,
    prompt: str,
    output_path: str,
    duration: float = 10.0,
    temperature: float = 1.0,
    top_k: int = 250,
    guidance_scale: float = 3.0,
    on_progress=None,
):
    """
    Generate music using MLX (Apple's ML framework).
    Falls back to transformers if MLX loading fails.
    """
    try:
        import mlx.core as mx
        from functools import partial
        from types import SimpleNamespace

        # Check if model has state_dict.bin (Apple MLX format)
        model_dir = Path(model_path)
        state_dict_path = model_dir / "state_dict.bin"

        if not state_dict_path.exists():
            print("Model not in MLX format, using HuggingFace transformers", file=sys.stderr)
            return generate_with_transformers(
                model_path, prompt, output_path, duration,
                temperature, top_k, guidance_scale, on_progress
            )

        # MLX-native loading (for Apple MLX format models)
        print("Loading MLX-native model...", file=sys.stderr)
        # ... MLX implementation would go here ...
        # For now, fall back to transformers
        raise NotImplementedError("MLX-native format not yet supported")

    except Exception as e:
        print(f"MLX loading failed ({e}), using HuggingFace transformers", file=sys.stderr)
        return generate_with_transformers(
            model_path, prompt, output_path, duration,
            temperature, top_k, guidance_scale, on_progress
        )


def main():
    parser = argparse.ArgumentParser(description="MusicGen Audio Generation Backend")
    parser.add_argument("--model", default="facebook/musicgen-small", help="Model name or path")
    parser.add_argument("--prompt", required=True, help="Text prompt for generation")
    parser.add_argument("--output", required=True, help="Output WAV file path")
    parser.add_argument("--duration", type=float, default=10.0, help="Duration in seconds")
    parser.add_argument("--temperature", type=float, default=1.0, help="Sampling temperature")
    parser.add_argument("--top-k", type=int, default=250, help="Top-k sampling")
    parser.add_argument("--guidance", type=float, default=3.0, help="Classifier-free guidance")
    parser.add_argument("--progress", action="store_true", help="Output progress to stderr")
    parser.add_argument("--use-mlx", action="store_true", help="Prefer MLX backend")
    args = parser.parse_args()

    def progress_callback(progress):
        if args.progress:
            print(json.dumps({"progress": progress}), file=sys.stderr, flush=True)

    try:
        # Try MLX first if requested, otherwise use transformers directly
        if args.use_mlx:
            result = generate_with_mlx(
                model_path=args.model,
                prompt=args.prompt,
                output_path=args.output,
                duration=args.duration,
                temperature=args.temperature,
                top_k=args.top_k,
                guidance_scale=args.guidance,
                on_progress=progress_callback if args.progress else None,
            )
        else:
            result = generate_with_transformers(
                model_path=args.model,
                prompt=args.prompt,
                output_path=args.output,
                duration=args.duration,
                temperature=args.temperature,
                top_k=args.top_k,
                guidance_scale=args.guidance,
                on_progress=progress_callback if args.progress else None,
            )

        # Output result as JSON to stdout
        print(json.dumps(result))

    except Exception as e:
        import traceback
        error_result = {
            "success": False,
            "error": str(e),
            "traceback": traceback.format_exc(),
        }
        print(json.dumps(error_result))
        sys.exit(1)


if __name__ == "__main__":
    main()
