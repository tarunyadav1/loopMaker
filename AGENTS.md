# AGENTS.md

## Cursor Cloud specific instructions

### Platform constraints

This is a **macOS-native SwiftUI app** (Swift 6.2, macOS 14+). The Cloud Agent environment is Linux x86_64.

- **Swift frontend**: Cannot build or test on Linux (depends on SwiftUI, AppKit, AVFoundation, Sparkle). `swift build` / `swift test` / `make build` are macOS-only.
- **Python backend**: Runs on Linux with CPU-only PyTorch. The `mlx`, `mlx-lm`, and `ace-step` packages are Apple Silicon only and are not installed in the Linux venv. The backend starts and serves API endpoints but cannot perform actual music generation without these packages.
- **SwiftLint**: Installed at `/usr/local/bin/swiftlint` (Linux binary, requires Swift toolchain at `/usr/local/`). Run with `swiftlint lint` from the repo root. SwiftFormat is not available on Linux.

### Services

| Service | How to run | Notes |
|---------|-----------|-------|
| Python backend | `cd backend && . .venv/bin/activate && python -m uvicorn main:app --host 0.0.0.0 --port 8000` | Responds on `/health`, `/models/status`, `/generate`, `/models/download`, `/docs`. Generation requires macOS + ace-step. |
| SwiftLint | `swiftlint lint` (from repo root) | Uses `.swiftlint.yml` config. Existing codebase has ~77 warnings and 11 errors. |

### Development commands

See `CLAUDE.md` for the full command reference. On Linux, only the following are usable:

- **Lint**: `swiftlint lint` (works), `swiftlint lint --fix` (works for auto-correctable rules)
- **Backend**: `cd backend && . .venv/bin/activate && python -m uvicorn main:app --reload --host 0.0.0.0 --port 8000`
- **Backend tests**: `cd backend && . .venv/bin/activate && python -m pytest` (no test files currently exist)

### Gotchas

- The `Package.swift` requires swift-tools-version 6.2 but the installed Linux Swift is 6.0.3. `swift package resolve` will fail. This does not affect SwiftLint which uses its own SourceKit.
- The backend venv is at `backend/.venv` using Python 3.11 (from deadsnakes PPA). Always activate it before running backend commands.
- PyTorch is installed as CPU-only (`torch==2.10.0+cpu`) to save disk space on Linux.
