# =============================================================================
# LoopMaker Makefile - Developer Commands
# =============================================================================

# Configuration
APP_NAME = LoopMaker
SCHEME = LoopMaker
CONFIGURATION = Debug
DESTINATION = platform=macOS

# Colors for output
GREEN = \033[0;32m
YELLOW = \033[0;33m
RED = \033[0;31m
NC = \033[0m

.PHONY: help setup bootstrap build build-release run clean reset open lint lint-fix format format-check quality test test-unit coverage archive notarize release logs version

# =============================================================================
# Help
# =============================================================================

help:
	@echo "$(GREEN)LoopMaker - Available commands:$(NC)"
	@echo ""
	@echo "  $(YELLOW)Setup:$(NC)"
	@echo "    make setup          - Install all dependencies and tools"
	@echo "    make bootstrap      - First-time project setup"
	@echo ""
	@echo "  $(YELLOW)Development:$(NC)"
	@echo "    make build          - Build the app (Debug)"
	@echo "    make build-release  - Build the app (Release)"
	@echo "    make run            - Build and run the app"
	@echo "    make clean          - Clean build artifacts"
	@echo "    make reset          - Clean and rebuild from scratch"
	@echo ""
	@echo "  $(YELLOW)Code Quality:$(NC)"
	@echo "    make lint           - Run SwiftLint"
	@echo "    make lint-fix       - Run SwiftLint with autocorrect"
	@echo "    make format         - Format code with SwiftFormat"
	@echo "    make format-check   - Check formatting without changes"
	@echo "    make quality        - Run all code quality checks"
	@echo ""
	@echo "  $(YELLOW)Testing:$(NC)"
	@echo "    make test           - Run all tests"
	@echo "    make test-unit      - Run unit tests only"
	@echo "    make coverage       - Run tests with coverage report"
	@echo ""
	@echo "  $(YELLOW)Release:$(NC)"
	@echo "    make archive        - Create release archive"
	@echo "    make notarize       - Notarize the app"
	@echo "    make release        - Full release (archive + notarize)"
	@echo ""
	@echo "  $(YELLOW)Utilities:$(NC)"
	@echo "    make open           - Open project in Xcode"
	@echo "    make logs           - Show app logs"
	@echo "    make version        - Show current version"

# =============================================================================
# Setup Commands
# =============================================================================

setup:
	@echo "$(GREEN)Installing dependencies...$(NC)"
	@which brew > /dev/null || /bin/bash -c "$$(curl -fsSL https://raw.githubusercontent.com/Homebrew/install/HEAD/install.sh)"
	@brew install swiftlint swiftformat xcbeautify || true
	@echo "$(GREEN)Resolving Swift packages...$(NC)"
	@swift package resolve
	@echo "$(GREEN)Setup complete!$(NC)"

bootstrap: setup
	@echo "$(GREEN)Bootstrapping project...$(NC)"
	@swift package resolve
	@echo "$(GREEN)Bootstrap complete!$(NC)"

# =============================================================================
# Development Commands
# =============================================================================

build:
	@echo "$(GREEN)Building $(APP_NAME) (Debug)...$(NC)"
	@swift build -c debug 2>&1 | xcbeautify || swift build -c debug

build-release:
	@echo "$(GREEN)Building $(APP_NAME) (Release)...$(NC)"
	@swift build -c release 2>&1 | xcbeautify || swift build -c release

# Build proper .app bundle (required for keyboard input to work on macOS)
app: build
	@echo "$(GREEN)Creating $(APP_NAME).app bundle...$(NC)"
	@mkdir -p build/$(APP_NAME).app/Contents/MacOS
	@mkdir -p build/$(APP_NAME).app/Contents/Resources/backend
	@cp .build/debug/$(APP_NAME) build/$(APP_NAME).app/Contents/MacOS/
	@cp LoopMaker/Info.plist build/$(APP_NAME).app/Contents/
	@if [ -f LoopMaker/LoopMaker.entitlements ]; then cp LoopMaker/LoopMaker.entitlements build/$(APP_NAME).app/Contents/; fi
	@# Copy backend files for auto-start
	@cp backend/main.py build/$(APP_NAME).app/Contents/Resources/backend/
	@cp backend/requirements.txt build/$(APP_NAME).app/Contents/Resources/backend/
	@echo "$(GREEN)App bundle created at build/$(APP_NAME).app$(NC)"

run: app
	@echo "$(GREEN)Running $(APP_NAME).app...$(NC)"
	@open build/$(APP_NAME).app

# Run without rebuilding (faster iteration)
run-fast:
	@echo "$(GREEN)Running $(APP_NAME).app (no rebuild)...$(NC)"
	@open build/$(APP_NAME).app

# Legacy: run bare executable (keyboard input may not work)
run-cli: build
	@echo "$(YELLOW)Warning: Running as CLI - keyboard input may not work$(NC)"
	@swift run $(APP_NAME)

clean:
	@echo "$(YELLOW)Cleaning build artifacts...$(NC)"
	@swift package clean
	@rm -rf .build/
	@rm -rf DerivedData/
	@rm -rf *.xcresult
	@echo "$(GREEN)Clean complete!$(NC)"

reset: clean
	@echo "$(YELLOW)Resetting project...$(NC)"
	@swift package reset
	@swift package resolve
	@$(MAKE) build
	@echo "$(GREEN)Reset complete!$(NC)"

open:
	@echo "$(GREEN)Opening in Xcode...$(NC)"
	@open Package.swift

# =============================================================================
# Code Quality Commands
# =============================================================================

lint:
	@echo "$(GREEN)Running SwiftLint...$(NC)"
	@swiftlint lint --quiet || swiftlint lint

lint-fix:
	@echo "$(GREEN)Running SwiftLint with autocorrect...$(NC)"
	@swiftlint lint --fix --quiet || swiftlint lint --fix
	@swiftlint lint --quiet || true

format:
	@echo "$(GREEN)Formatting code with SwiftFormat...$(NC)"
	@swiftformat . --quiet || swiftformat .

format-check:
	@echo "$(GREEN)Checking code formatting...$(NC)"
	@swiftformat . --lint --quiet || swiftformat . --lint

quality: format lint
	@echo "$(GREEN)All code quality checks passed!$(NC)"

# =============================================================================
# Testing Commands
# =============================================================================

test:
	@echo "$(GREEN)Running all tests...$(NC)"
	@swift test 2>&1 | xcbeautify || swift test

test-unit:
	@echo "$(GREEN)Running unit tests...$(NC)"
	@swift test --filter $(APP_NAME)Tests 2>&1 | xcbeautify || swift test --filter $(APP_NAME)Tests

coverage:
	@echo "$(GREEN)Running tests with coverage...$(NC)"
	@swift test --enable-code-coverage
	@echo "$(GREEN)Coverage data available in .build/debug/codecov/$(NC)"

# =============================================================================
# Release Commands
# =============================================================================

archive:
	@echo "$(GREEN)Creating release archive...$(NC)"
	@swift build -c release
	@mkdir -p build/Release
	@cp -R .build/release/$(APP_NAME) build/Release/
	@echo "$(GREEN)Archive created at build/Release/$(APP_NAME)$(NC)"

notarize:
	@echo "$(GREEN)Notarizing app...$(NC)"
	@./scripts/notarize.sh

release: archive notarize
	@echo "$(GREEN)Release complete!$(NC)"

# =============================================================================
# Utility Commands
# =============================================================================

logs:
	@echo "$(GREEN)Showing app logs...$(NC)"
	@log show --predicate 'subsystem == "com.loopmaker.LoopMaker"' --last 1h

version:
	@echo "$(GREEN)Current version:$(NC)"
	@grep -A1 "CFBundleShortVersionString" LoopMaker/Info.plist 2>/dev/null | tail -1 | tr -d '\t' | sed 's/<[^>]*>//g' || echo "1.0.0"

# =============================================================================
# Python Backend Commands
# =============================================================================

backend:
	@echo "$(GREEN)Starting Python backend...$(NC)"
	@cd backend && python -m uvicorn main:app --reload --host 0.0.0.0 --port 8000

backend-setup:
	@echo "$(GREEN)Setting up Python backend...$(NC)"
	@cd backend && python -m venv .venv && . .venv/bin/activate && pip install -r requirements.txt
	@echo "$(GREEN)Backend setup complete!$(NC)"

backend-test:
	@echo "$(GREEN)Testing Python backend...$(NC)"
	@cd backend && python -m pytest

# =============================================================================
# Python Bundling (for zero-config distribution)
# =============================================================================

PYTHON_VERSION = 3.11.8
PYTHON_BUILD_DIR = build/python
PYTHON_FRAMEWORK = $(PYTHON_BUILD_DIR)/Python.framework

# Download standalone Python for bundling
download-python:
	@echo "$(GREEN)Downloading Python $(PYTHON_VERSION) standalone...$(NC)"
	@mkdir -p $(PYTHON_BUILD_DIR)
	@./scripts/download-python.sh $(PYTHON_VERSION) $(PYTHON_BUILD_DIR)
	@echo "$(GREEN)Python downloaded to $(PYTHON_BUILD_DIR)$(NC)"

# Build full .app bundle with bundled Python
app-bundle: build download-python
	@echo "$(GREEN)Creating $(APP_NAME).app bundle with bundled Python...$(NC)"
	@mkdir -p build/$(APP_NAME).app/Contents/MacOS
	@mkdir -p build/$(APP_NAME).app/Contents/Resources/backend
	@mkdir -p build/$(APP_NAME).app/Contents/Frameworks
	@# Copy executable
	@cp .build/debug/$(APP_NAME) build/$(APP_NAME).app/Contents/MacOS/
	@# Copy Info.plist
	@cp LoopMaker/Info.plist build/$(APP_NAME).app/Contents/
	@# Copy entitlements if exists
	@if [ -f LoopMaker/LoopMaker.entitlements ]; then cp LoopMaker/LoopMaker.entitlements build/$(APP_NAME).app/Contents/; fi
	@# Copy Python framework
	@if [ -d "$(PYTHON_FRAMEWORK)" ]; then cp -R $(PYTHON_FRAMEWORK) build/$(APP_NAME).app/Contents/Frameworks/; fi
	@# Copy backend files
	@cp backend/main.py build/$(APP_NAME).app/Contents/Resources/backend/
	@cp backend/requirements.txt build/$(APP_NAME).app/Contents/Resources/backend/
	@echo "$(GREEN)App bundle with Python created at build/$(APP_NAME).app$(NC)"

# Clean Python build artifacts
clean-python:
	@echo "$(YELLOW)Cleaning Python build artifacts...$(NC)"
	@rm -rf $(PYTHON_BUILD_DIR)
	@echo "$(GREEN)Python artifacts cleaned!$(NC)"

# =============================================================================
# Development Shortcuts
# =============================================================================

b: build
r: run
t: test
l: lint
f: format
q: quality
