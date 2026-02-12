# =============================================================================
# LoopMaker Makefile - Developer & Distribution Commands
# =============================================================================

# Configuration
APP_NAME = LoopMaker
SCHEME = LoopMaker
CONFIGURATION = Debug
DESTINATION = platform=macOS

# Distribution configuration
SIGNING_IDENTITY ?= -
PYTHON_VERSION = 3.11.8
PYTHON_BUILD_DIR = build/python
PYTHON_FRAMEWORK = $(PYTHON_BUILD_DIR)/Python.framework
BUNDLED_PYTHON = $(PYTHON_FRAMEWORK)/Versions/3.11/bin/python3
SITE_PACKAGES_DIR = build/site-packages
APP_BUNDLE = build/$(APP_NAME).app
APP_VERSION = $(shell /usr/libexec/PlistBuddy -c "Print :CFBundleShortVersionString" LoopMaker/Info.plist 2>/dev/null || echo "1.0.0")
DMG_NAME = $(APP_NAME)-$(APP_VERSION)

# Colors for output
GREEN = \033[0;32m
YELLOW = \033[0;33m
RED = \033[0;31m
NC = \033[0m

.PHONY: help setup bootstrap build build-release run clean reset open \
        lint lint-fix format format-check quality test test-unit coverage \
        archive notarize release logs version \
        backend backend-setup backend-test \
        download-python bundle-site-packages release-app sign-app dmg notarize-dmg distribute \
        clean-python clean-dist \
        b r t l f q

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
	@echo "  $(YELLOW)Distribution:$(NC)"
	@echo "    make release-app    - Build release .app with bundled Python + deps"
	@echo "    make sign-app       - Code sign the .app bundle"
	@echo "    make dmg            - Create distributable DMG"
	@echo "    make notarize-dmg   - Notarize the DMG with Apple"
	@echo "    make distribute     - Full pipeline: build, sign, DMG, notarize"
	@echo ""
	@echo "  $(YELLOW)Distribution Steps (individual):$(NC)"
	@echo "    make download-python      - Download Python $(PYTHON_VERSION) framework"
	@echo "    make bundle-site-packages - Pre-install Python deps for bundling"
	@echo ""
	@echo "  $(YELLOW)Utilities:$(NC)"
	@echo "    make open           - Open project in Xcode"
	@echo "    make logs           - Show app logs"
	@echo "    make version        - Show current version"
	@echo ""
	@echo "  $(YELLOW)Distribution Variables:$(NC)"
	@echo "    SIGNING_IDENTITY    - Code signing identity (default: ad-hoc)"
	@echo "                          e.g. SIGNING_IDENTITY='Developer ID Application: Name (TEAMID)'"

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

# Build proper .app bundle for development (debug, no bundled Python/deps)
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
	@# Copy app icon if available
	@if [ -f LoopMaker/Resources/AppIcon.icns ]; then cp LoopMaker/Resources/AppIcon.icns build/$(APP_NAME).app/Contents/Resources/; fi
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
# Distribution Pipeline
# =============================================================================

# Download standalone Python framework for bundling
download-python:
	@echo "$(GREEN)Downloading Python $(PYTHON_VERSION) standalone...$(NC)"
	@mkdir -p $(PYTHON_BUILD_DIR)
	@./scripts/download-python.sh $(PYTHON_VERSION) $(PYTHON_BUILD_DIR)
	@echo "$(GREEN)Python downloaded to $(PYTHON_BUILD_DIR)$(NC)"

# Pre-install Python dependencies into a portable site-packages directory.
# Uses the bundled Python framework to ensure compatibility.
bundle-site-packages: download-python
	@echo "$(GREEN)Bundling Python site-packages...$(NC)"
	@if [ ! -x "$(BUNDLED_PYTHON)" ]; then \
		echo "$(RED)Error: Bundled Python not found at $(BUNDLED_PYTHON)$(NC)"; \
		echo "$(YELLOW)Run 'make download-python' first$(NC)"; \
		exit 1; \
	fi
	@echo "  Creating temporary venv..."
	@"$(BUNDLED_PYTHON)" -m venv build/bundle-venv
	@echo "  Upgrading pip..."
	@build/bundle-venv/bin/pip install --upgrade pip --quiet
	@echo "  Installing dependencies (this may take several minutes)..."
	@build/bundle-venv/bin/pip install -r backend/requirements.txt --quiet
	@echo "  Extracting site-packages..."
	@rm -rf $(SITE_PACKAGES_DIR)
	@cp -R build/bundle-venv/lib/python3.11/site-packages $(SITE_PACKAGES_DIR)
	@# Clean up unnecessary files to reduce bundle size
	@find $(SITE_PACKAGES_DIR) -type d -name "__pycache__" -exec rm -rf {} + 2>/dev/null || true
	@find $(SITE_PACKAGES_DIR) -type d -name "tests" -mindepth 2 -exec rm -rf {} + 2>/dev/null || true
	@find $(SITE_PACKAGES_DIR) -type d -name "test" -mindepth 2 -exec rm -rf {} + 2>/dev/null || true
	@find $(SITE_PACKAGES_DIR) -name "*.pyc" -delete 2>/dev/null || true
	@rm -rf build/bundle-venv
	@echo "$(GREEN)Site-packages bundled at $(SITE_PACKAGES_DIR)$(NC)"
	@echo "  Size: $$(du -sh $(SITE_PACKAGES_DIR) | cut -f1)"

# Build release .app bundle with bundled Python and pre-installed dependencies.
# This produces a self-contained app that requires no internet on first launch.
release-app: build-release download-python bundle-site-packages
	@echo "$(GREEN)Creating release $(APP_NAME).app bundle...$(NC)"
	@rm -rf $(APP_BUNDLE)
	@# Create directory structure
	@mkdir -p $(APP_BUNDLE)/Contents/MacOS
	@mkdir -p $(APP_BUNDLE)/Contents/Resources/backend
	@mkdir -p $(APP_BUNDLE)/Contents/Frameworks
	@# Copy release binary
	@cp .build/release/$(APP_NAME) $(APP_BUNDLE)/Contents/MacOS/
	@# Copy metadata
	@cp LoopMaker/Info.plist $(APP_BUNDLE)/Contents/
	@if [ -f LoopMaker/LoopMaker.entitlements ]; then \
		cp LoopMaker/LoopMaker.entitlements $(APP_BUNDLE)/Contents/; \
	fi
	@# Copy Python framework (hard requirement for release)
	@if [ ! -d "$(PYTHON_FRAMEWORK)" ]; then \
		echo "$(RED)Error: Python.framework not found. Run 'make download-python' first.$(NC)"; \
		exit 1; \
	fi
	@cp -R $(PYTHON_FRAMEWORK) $(APP_BUNDLE)/Contents/Frameworks/
	@# Copy backend files
	@cp backend/main.py $(APP_BUNDLE)/Contents/Resources/backend/
	@cp backend/requirements.txt $(APP_BUNDLE)/Contents/Resources/backend/
	@# Copy pre-installed site-packages (hard requirement for release)
	@if [ ! -d "$(SITE_PACKAGES_DIR)" ]; then \
		echo "$(RED)Error: site-packages not found. Run 'make bundle-site-packages' first.$(NC)"; \
		exit 1; \
	fi
	@cp -R $(SITE_PACKAGES_DIR) $(APP_BUNDLE)/Contents/Resources/backend/site-packages
	@# Copy app icon if available
	@if [ -f LoopMaker/Resources/AppIcon.icns ]; then \
		cp LoopMaker/Resources/AppIcon.icns $(APP_BUNDLE)/Contents/Resources/; \
	fi
	@echo "$(GREEN)Release app bundle created at $(APP_BUNDLE)$(NC)"
	@echo "  Size: $$(du -sh $(APP_BUNDLE) | cut -f1)"

# Sign the .app bundle. Set SIGNING_IDENTITY for distribution signing.
# Ad-hoc signing (default) works for local testing but not Gatekeeper.
sign-app:
	@echo "$(GREEN)Signing $(APP_BUNDLE)...$(NC)"
	@if [ ! -d "$(APP_BUNDLE)" ]; then \
		echo "$(RED)Error: $(APP_BUNDLE) not found. Run 'make release-app' first.$(NC)"; \
		exit 1; \
	fi
	@# Sign frameworks first (inside-out signing order)
	@if [ -d "$(APP_BUNDLE)/Contents/Frameworks/Python.framework" ]; then \
		echo "  Signing Python.framework..."; \
		codesign --force --sign "$(SIGNING_IDENTITY)" --options runtime \
			$(APP_BUNDLE)/Contents/Frameworks/Python.framework; \
	fi
	@# Sign the main bundle
	@echo "  Signing $(APP_NAME).app..."
	@if [ -f LoopMaker/LoopMaker.entitlements ]; then \
		codesign --force --sign "$(SIGNING_IDENTITY)" --options runtime \
			--entitlements LoopMaker/LoopMaker.entitlements \
			$(APP_BUNDLE); \
	else \
		codesign --force --sign "$(SIGNING_IDENTITY)" --options runtime \
			$(APP_BUNDLE); \
	fi
	@# Verify signature
	@echo "  Verifying signature..."
	@codesign --verify --deep --strict $(APP_BUNDLE)
	@echo "$(GREEN)Signing complete and verified$(NC)"

# Create a distributable DMG with drag-to-Applications layout
dmg:
	@echo "$(GREEN)Creating DMG...$(NC)"
	@if [ ! -d "$(APP_BUNDLE)" ]; then \
		echo "$(RED)Error: $(APP_BUNDLE) not found. Run 'make release-app' first.$(NC)"; \
		exit 1; \
	fi
	@./scripts/create-dmg.sh "$(APP_BUNDLE)" "build/$(DMG_NAME).dmg" "$(APP_NAME)"
	@echo "$(GREEN)DMG created at build/$(DMG_NAME).dmg$(NC)"
	@echo "  Size: $$(du -sh build/$(DMG_NAME).dmg | cut -f1)"

# Notarize the DMG with Apple
notarize-dmg:
	@echo "$(GREEN)Notarizing DMG...$(NC)"
	@./scripts/notarize.sh "build/$(DMG_NAME).dmg"

# Full distribution pipeline: build → sign → DMG → notarize
distribute: release-app sign-app dmg notarize-dmg
	@echo ""
	@echo "$(GREEN)============================================$(NC)"
	@echo "$(GREEN)  Distribution complete!$(NC)"
	@echo "$(GREEN)============================================$(NC)"
	@echo ""
	@echo "  DMG: build/$(DMG_NAME).dmg"
	@echo "  Version: $(APP_VERSION)"
	@echo ""

# Legacy targets (kept for compatibility)
archive: release-app
	@echo "$(YELLOW)Note: 'make archive' now builds a full .app bundle via release-app$(NC)"

notarize: notarize-dmg
	@echo "$(YELLOW)Note: 'make notarize' now notarizes the DMG via notarize-dmg$(NC)"

release: distribute
	@echo "$(YELLOW)Note: 'make release' now runs the full distribute pipeline$(NC)"

# =============================================================================
# Utility Commands
# =============================================================================

logs:
	@echo "$(GREEN)Showing app logs...$(NC)"
	@log show --predicate 'subsystem == "com.loopmaker.LoopMaker"' --last 1h

version:
	@echo "$(GREEN)Current version:$(NC)"
	@echo "  $(APP_VERSION)"

# =============================================================================
# Python Backend Commands (Development)
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
# Cleanup
# =============================================================================

# Clean Python/distribution build artifacts
clean-dist:
	@echo "$(YELLOW)Cleaning distribution artifacts...$(NC)"
	@rm -rf $(PYTHON_BUILD_DIR)
	@rm -rf $(SITE_PACKAGES_DIR)
	@rm -rf build/bundle-venv
	@rm -rf build/*.dmg
	@rm -rf $(APP_BUNDLE)
	@echo "$(GREEN)Distribution artifacts cleaned!$(NC)"

# Legacy alias
clean-python: clean-dist

# =============================================================================
# Development Shortcuts
# =============================================================================

b: build
r: run
t: test
l: lint
f: format
q: quality
