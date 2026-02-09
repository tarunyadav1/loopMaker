# Copyright 2024 Apple Inc.
# Vendored from mlx-examples/musicgen with local t5/encodec deps

from .musicgen import MusicGen
from .utils import save_audio

__all__ = ["MusicGen", "save_audio"]
