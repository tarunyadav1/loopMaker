#!/usr/bin/env python3
"""
EnCodec Audio Decoder - Python subprocess for Swift integration
Decodes audio tokens to waveform using HuggingFace transformers

Usage: python3 decode_audio.py <tokens_file> <output_wav_file> [model_path]
"""

import sys
import json
import numpy as np
from pathlib import Path


def decode_audio(tokens_path: str, output_path: str, model_path: str = None):
    """
    Decode audio tokens to WAV file using EnCodec from transformers

    Args:
        tokens_path: Path to JSON file containing audio tokens
        output_path: Path to output WAV file
        model_path: Optional path to local model, or uses HuggingFace hub
    """
    try:
        from transformers import AutoProcessor, EncodecModel
        import torch

        # Load tokens from JSON
        with open(tokens_path, "r") as f:
            data = json.load(f)

        tokens = np.array(data["tokens"], dtype=np.int64)
        sample_rate = data.get("sample_rate", 32000)

        print(f"Loaded tokens with shape: {tokens.shape}", file=sys.stderr)

        # Expected shape: [batch, num_codebooks, seq_len] from MusicGen
        if tokens.ndim != 3:
            raise ValueError(
                f"Expected 3D tokens [batch, num_codebooks, seq_len], got shape: {tokens.shape}"
            )

        batch_size, num_codebooks, seq_len = tokens.shape
        print(
            f"Batch: {batch_size}, Codebooks: {num_codebooks}, Seq len: {seq_len}",
            file=sys.stderr,
        )

        # Load EnCodec model from HuggingFace
        model_name = model_path if model_path else "facebook/encodec_32khz"
        print(f"Loading model from {model_name}...", file=sys.stderr)

        try:
            model = EncodecModel.from_pretrained(model_name)
            processor = AutoProcessor.from_pretrained(model_name)
        except Exception as e:
            print(f"Error loading {model_name}: {e}", file=sys.stderr)
            # Fallback to 24khz
            print("Trying 24kHz model...", file=sys.stderr)
            model = EncodecModel.from_pretrained("facebook/encodec_24khz")
            processor = AutoProcessor.from_pretrained("facebook/encodec_24khz")

        print(
            f"Model loaded. Sample rate: {model.config.sampling_rate}", file=sys.stderr
        )

        # Convert tokens to torch tensor
        # Shape should be [batch, num_codebooks, seq_len]
        codes = torch.from_numpy(tokens)

        # For single-frame decoding (common for MusicGen)
        # Reshape to [nb_frames=1, batch_size, nb_quantizers, frame_len]
        # codes shape is [batch, num_codebooks, seq_len]
        # We need [1, batch, num_codebooks, seq_len]
        codes = codes.unsqueeze(0)  # Add frames dimension

        print(f"Decoding with codes shape: {codes.shape}", file=sys.stderr)

        # Decode the codes to audio
        # The model.decode() expects [nb_frames, batch, nb_quantizers, frame_len]
        with torch.no_grad():
            audio_values = model.decode(codes, [None])[
                0
            ]  # Returns tuple, take first element

        # audio_values shape: [batch, channels, time]
        print(f"Decoded audio shape: {audio_values.shape}", file=sys.stderr)

        # Convert to numpy and process
        # audio_values is [batch, channels, time], take first batch and first channel
        audio_np = audio_values[0, 0].numpy()

        # Normalize to int16 range
        audio_max = np.max(np.abs(audio_np))
        if audio_max > 0:
            audio_np = audio_np / audio_max * 0.95  # Leave some headroom
        audio_int16 = (audio_np * 32767).astype(np.int16)

        # Save as WAV using scipy
        from scipy.io import wavfile

        wavfile.write(output_path, model.config.sampling_rate, audio_int16)

        print(f"Audio saved to {output_path}", file=sys.stderr)
        print(
            f"Duration: {len(audio_int16) / model.config.sampling_rate:.2f}s",
            file=sys.stderr,
        )

        # Return metadata as JSON to stdout
        result = {
            "success": True,
            "output_path": output_path,
            "sample_rate": int(model.config.sampling_rate),
            "num_samples": len(audio_int16),
            "duration": len(audio_int16) / model.config.sampling_rate,
        }
        print(json.dumps(result))
        return 0

    except Exception as e:
        import traceback

        error_result = {
            "success": False,
            "error": str(e),
            "traceback": traceback.format_exc(),
        }
        print(json.dumps(error_result), file=sys.stderr)
        return 1


if __name__ == "__main__":
    if len(sys.argv) < 3:
        print(
            "Usage: python3 decode_audio.py <tokens_json_file> <output_wav_file> [model_path]",
            file=sys.stderr,
        )
        sys.exit(1)

    tokens_file = sys.argv[1]
    output_file = sys.argv[2]
    model_path = sys.argv[3] if len(sys.argv) > 3 else None

    exit_code = decode_audio(tokens_file, output_file, model_path)
    sys.exit(exit_code)
