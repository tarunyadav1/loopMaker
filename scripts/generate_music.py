#!/usr/bin/env python3
"""
MusicGen Audio Generation - MLX Backend for LoopMaker
Uses Apple's MLX framework for Metal GPU-accelerated inference.

Usage: python3 generate_music.py --prompt "..." --output "..." [options]
"""

import argparse
import json
import sys
from pathlib import Path

import numpy as np


# Add backend directory to path so we can import mlx_musicgen
sys.path.insert(0, str(Path(__file__).resolve().parent.parent / "backend"))


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
    Generate music using MLX MusicGen (Metal GPU).
    """
    import mlx.core as mx
    from mlx_musicgen import MusicGen, save_audio

    print(f"Loading MLX MusicGen model: {model_path}", file=sys.stderr)

    if on_progress:
        on_progress(0.05)

    model = MusicGen.from_pretrained(model_path)

    if on_progress:
        on_progress(0.15)

    # ~50 steps per second of audio
    max_steps = int(duration * 50)
    print(f"Generating {max_steps} steps for {duration}s of audio", file=sys.stderr)

    print("Starting MLX generation...", file=sys.stderr)
    audio = model.generate(
        prompt,
        max_steps=max_steps,
        top_k=top_k,
        temp=temperature,
        guidance_coef=guidance_scale,
    )

    if on_progress:
        on_progress(0.90)

    sample_rate = model.sampling_rate

    # Convert to numpy and normalize
    audio_np = np.array(audio).flatten()
    audio_max = np.max(np.abs(audio_np))
    if audio_max > 0:
        audio_np = audio_np / audio_max * 0.95

    # Convert to int16 and save
    audio_int16 = (audio_np * 32767).astype(np.int16)
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


def main():
    parser = argparse.ArgumentParser(description="MusicGen Audio Generation (MLX)")
    parser.add_argument("--model", default="facebook/musicgen-small", help="Model name or path")
    parser.add_argument("--prompt", required=True, help="Text prompt for generation")
    parser.add_argument("--output", required=True, help="Output WAV file path")
    parser.add_argument("--duration", type=float, default=10.0, help="Duration in seconds")
    parser.add_argument("--temperature", type=float, default=1.0, help="Sampling temperature")
    parser.add_argument("--top-k", type=int, default=250, help="Top-k sampling")
    parser.add_argument("--guidance", type=float, default=3.0, help="Classifier-free guidance")
    parser.add_argument("--progress", action="store_true", help="Output progress to stderr")
    parser.add_argument("--seed", type=int, default=None, help="Random seed")
    args = parser.parse_args()

    if args.seed is not None:
        import mlx.core as mx
        mx.random.seed(args.seed)
        np.random.seed(args.seed)

    def progress_callback(progress):
        if args.progress:
            print(json.dumps({"progress": progress}), file=sys.stderr, flush=True)

    try:
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
