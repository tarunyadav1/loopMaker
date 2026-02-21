# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## Build & Development Commands

```bash
make setup        # Install dependencies (swiftlint, swiftformat, xcbeautify)
make build        # Debug build
make run          # Build and run
make test         # Run all tests
make quality      # Run format + lint
make lint-fix     # Auto-fix lint issues
make format       # Auto-format code
make clean        # Remove build artifacts
```

Shortcuts: `make b` (build), `make r` (run), `make t` (test), `make l` (lint), `make f` (format), `make q` (quality)

Run a single test:
```bash
swift test --filter LoopMakerTests.testTrackDuration
```

Open in Xcode: `make open` or `open Package.swift`

## Architecture

**Swift 6.0 macOS app** using SwiftUI + Combine for an AI-powered music generator built on Meta's MusicGen models via Apple's MLX framework.

### Key Directories

- `LoopMaker/App/` - App entry (`LoopMakerApp.swift`), root view, and `AppState` (global observable state)
- `LoopMaker/Features/` - MVVM feature modules: Generation, Player, Library, Export, Settings
- `LoopMaker/Services/ML/` - ML model management and MusicGen implementation
- `LoopMaker/Services/Audio/` - `AudioEngine` (playback), `AudioExporter` (WAV/M4A export)
- `LoopMaker/Design/` - Theme system and glass morphism UI components

### Service Architecture

Services are initialized in `AppState` and passed via environment:
- `ModelManager` - Downloads and tracks MusicGen model state
- `MusicGenService` - Orchestrates model loading and generation
- `AudioEngine` - AVAudioPlayer-based playback
- `TrackStorage` - Persistence layer

### Core Models

- `ModelType` - small (1.2GB, 8GB RAM) or medium (6.0GB, 16GB RAM)
- `TrackDuration` - short (10s), medium (30s), long (60s)
- `GenrePreset` - 6 presets with prompt suffixes (Lo-fi, Cinematic, Ambient, etc.)
- `Track` - Generated track with metadata (prompt, duration, audioURL, etc.)

## Code Conventions

**Logging**: Use `Log.*` categories instead of `print()`:
```swift
Log.generation.info("Generating track")
Log.ml.error("Model load failed: \(error)")
```
Categories: `app`, `ui`, `audio`, `ml`, `generation`, `data`, `performance`, `export`

**Threading**: Views and state classes use `@MainActor`. Async work uses structured concurrency.

**Linting**: Line length 120 (warn), 150 (error). Function body max 50 lines. No bare `print()` statements.


notization cred for the app
email: tarunyadav9761@gmail.com
password: wfye-jivf-htsy-gkne