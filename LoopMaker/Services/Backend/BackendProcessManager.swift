import Foundation
import os

/// Manages the Python backend process lifecycle for zero-config UX
@MainActor
public final class BackendProcessManager: ObservableObject {
    // MARK: - Types

    /// Current state of the backend setup/runtime
    public enum State: Equatable {
        case notStarted
        case checkingPython
        case pythonMissing
        case checkingVenv
        case creatingVenv
        case installingDependencies(progress: Double)
        case startingBackend
        case waitingForHealth
        case running
        case error(String)

        /// True only during first-time installation (creating venv, installing deps).
        /// Normal backend startup (checkingPython, startingBackend, etc.) is NOT setup.
        public var isFirstTimeSetup: Bool {
            switch self {
            case .creatingVenv, .installingDependencies:
                return true
            default:
                return false
            }
        }

        /// True when any startup work is happening (including normal reconnect)
        public var isSetupPhase: Bool {
            switch self {
            case .notStarted, .checkingPython, .checkingVenv, .creatingVenv,
                 .installingDependencies, .startingBackend, .waitingForHealth:
                return true
            case .pythonMissing, .running, .error:
                return false
            }
        }

        public var userMessage: String {
            switch self {
            case .notStarted:
                return "Preparing LoopMaker..."
            case .checkingPython:
                return "Checking system requirements..."
            case .pythonMissing:
                return "Python 3.11 not found. ACE-Step v1.5 requires Python 3.11.x."
            case .checkingVenv:
                return "Checking environment..."
            case .creatingVenv:
                return "Setting up AI environment..."
            case .installingDependencies(let progress):
                let percent = Int(progress * 100)
                return "Installing AI components... \(percent)%"
            case .startingBackend:
                return "Starting music engine..."
            case .waitingForHealth:
                return "Connecting to music engine..."
            case .running:
                return "Ready!"
            case .error(let message):
                return "Error: \(message)"
            }
        }
    }

    // MARK: - Published State

    @Published public var state: State = .notStarted
    @Published public var setupProgress: Double = 0
    @Published public var isFirstLaunch = false

    // MARK: - Private Properties

    private var backendProcess: Process?
    private var healthCheckTask: Task<Void, Never>?
    private let logger = Logger(subsystem: "com.loopmaker.LoopMaker", category: "BackendProcess")

    // MARK: - Paths

    private var appSupportURL: URL {
        FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask).first!
            .appendingPathComponent("LoopMaker", isDirectory: true)
    }

    private var backendURL: URL {
        appSupportURL.appendingPathComponent("backend", isDirectory: true)
    }

    private var venvURL: URL {
        backendURL.appendingPathComponent(".venv", isDirectory: true)
    }

    private var pidFileURL: URL {
        backendURL.appendingPathComponent("pid")
    }

    private var bundledBackendURL: URL? {
        Bundle.main.resourceURL?.appendingPathComponent("backend", isDirectory: true)
    }

    private var bundledPythonURL: URL? {
        Bundle.main.privateFrameworksURL?
            .appendingPathComponent("Python.framework/Versions/3.11/bin/python3", isDirectory: false)
    }

    /// In dev mode (no bundled backend), resolve the source backend directory.
    /// This avoids fragile file-copying and runs uvicorn directly from source.
    private var sourceBackendURL: URL? {
        // Navigate from this Swift source file to the project root's backend/ dir
        // BackendProcessManager.swift → Backend/ → Services/ → LoopMaker/ → project root
        let thisFile = URL(fileURLWithPath: #filePath)
        let projectRoot = thisFile
            .deletingLastPathComponent()
            .deletingLastPathComponent()
            .deletingLastPathComponent()
            .deletingLastPathComponent()
        let candidate = projectRoot.appendingPathComponent("backend", isDirectory: true)
        let mainPy = candidate.appendingPathComponent("main.py")
        if FileManager.default.fileExists(atPath: mainPy.path) {
            return candidate
        }
        return nil
    }

    /// The directory where uvicorn should run (source dir in dev, App Support in prod)
    private var backendWorkingURL: URL {
        sourceBackendURL ?? backendURL
    }

    // MARK: - Initialization

    public init() {}

    deinit {
        // Note: stopBackend() cannot be called here as deinit is nonisolated
        // The app termination handler in LoopMakerApp handles cleanup
    }

    // MARK: - Public API

    /// Main entry point: ensures backend is running, setting up if necessary
    public func ensureBackendRunning() async {
        state = .checkingPython

        // Clean up any orphaned processes
        await cleanupOrphanedProcesses()

        // Check for Python
        guard let pythonPath = await detectPython() else {
            state = .pythonMissing
            return
        }

        // Check if venv exists
        state = .checkingVenv
        isFirstLaunch = !FileManager.default.fileExists(atPath: venvURL.path)

        if isFirstLaunch {
            // First launch setup
            do {
                state = .creatingVenv
                setupProgress = 0.1
                try await createVenv(pythonPath: pythonPath)

                setupProgress = 0.2
                try await installDependencies()

                setupProgress = 0.9
            } catch {
                state = .error("Setup failed: \(error.localizedDescription)")
                return
            }
        }

        // Start backend
        do {
            state = .startingBackend
            setupProgress = 0.95
            try await launchBackend()

            state = .waitingForHealth
            try await waitForHealthy()

            setupProgress = 1.0
            state = .running
        } catch {
            state = .error("Could not start backend: \(error.localizedDescription)")
        }
    }

    /// Stop the backend process gracefully
    public func stopBackend() async {
        healthCheckTask?.cancel()
        healthCheckTask = nil

        guard let process = backendProcess, process.isRunning else {
            cleanupPidFile()
            return
        }

        logger.info("Stopping backend process...")

        // Try graceful termination first
        process.terminate()

        // Wait up to 5 seconds for graceful shutdown
        let deadline = Date().addingTimeInterval(5)
        while process.isRunning && Date() < deadline {
            try? await Task.sleep(nanoseconds: 100_000_000)
        }

        // Force kill if still running
        if process.isRunning {
            logger.warning("Backend did not terminate gracefully, forcing...")
            kill(process.processIdentifier, SIGKILL)
        }

        backendProcess = nil
        cleanupPidFile()
        logger.info("Backend stopped")
    }

    /// Retry setup after an error
    public func retrySetup() async {
        state = .notStarted
        setupProgress = 0
        await ensureBackendRunning()
    }

    // MARK: - Python Detection

    /// Detect Python installation, preferring bundled Python
    private func detectPython() async -> URL? {
        // First check for bundled Python (zero-config)
        if let bundled = bundledPythonURL,
           FileManager.default.isExecutableFile(atPath: bundled.path) {
            logger.info("Using bundled Python at: \(bundled.path)")
            return bundled
        }

        // Check common system locations
        let systemPaths = [
            "/usr/local/bin/python3",
            "/opt/homebrew/bin/python3",
            "/usr/bin/python3",
            "/Library/Frameworks/Python.framework/Versions/3.11/bin/python3",
            "/Library/Frameworks/Python.framework/Versions/3.12/bin/python3"
        ]

        for path in systemPaths {
            if FileManager.default.isExecutableFile(atPath: path) {
                // Verify it's Python 3.9+
                if await verifyPythonVersion(at: URL(fileURLWithPath: path)) {
                    logger.info("Found system Python at: \(path)")
                    return URL(fileURLWithPath: path)
                }
            }
        }

        // Try `which python3`
        if let whichResult = await runShellCommand("which python3"),
           !whichResult.isEmpty {
            let path = whichResult.trimmingCharacters(in: .whitespacesAndNewlines)
            if FileManager.default.isExecutableFile(atPath: path),
               await verifyPythonVersion(at: URL(fileURLWithPath: path)) {
                logger.info("Found Python via which: \(path)")
                return URL(fileURLWithPath: path)
            }
        }

        logger.error("No suitable Python installation found")
        return nil
    }

    private func verifyPythonVersion(at path: URL) async -> Bool {
        guard let output = await runShellCommand("\(path.path) --version") else {
            return false
        }

        // Parse "Python 3.X.Y"
        let components = output.split(separator: " ")
        guard components.count >= 2,
              let version = components.last else {
            return false
        }

        let versionParts = version.split(separator: ".")
        guard versionParts.count >= 2,
              let major = Int(versionParts[0]),
              let minor = Int(versionParts[1]) else {
            return false
        }

        // Require Python 3.11+ (ACE-Step v1.5 requires ==3.11.*)
        return major == 3 && minor >= 11
    }

    // MARK: - Venv Setup

    private func createVenv(pythonPath: URL) async throws {
        let venvPath = self.venvURL.path
        logger.info("Creating virtual environment at: \(venvPath)")

        // Ensure directories exist
        try FileManager.default.createDirectory(at: backendURL, withIntermediateDirectories: true)

        // Copy backend files from bundle
        try copyBundledBackendFiles()

        // Create venv
        let createVenvProcess = Process()
        createVenvProcess.executableURL = pythonPath
        createVenvProcess.arguments = ["-m", "venv", venvURL.path]
        createVenvProcess.currentDirectoryURL = backendURL

        try await runProcessAndWait(createVenvProcess)

        guard createVenvProcess.terminationStatus == 0 else {
            throw BackendSetupError.venvCreationFailed
        }

        logger.info("Virtual environment created successfully")
    }

    private func copyBundledBackendFiles() throws {
        guard let bundledBackend = bundledBackendURL else {
            // Development mode: use backend files from source
            let sourceBackend = URL(fileURLWithPath: #filePath)
                .deletingLastPathComponent()
                .deletingLastPathComponent()
                .deletingLastPathComponent()
                .deletingLastPathComponent()
                .appendingPathComponent("backend", isDirectory: true)

            if FileManager.default.fileExists(atPath: sourceBackend.path) {
                try copyBackendFiles(from: sourceBackend)
                return
            }

            throw BackendSetupError.backendFilesNotFound
        }

        try copyBackendFiles(from: bundledBackend)
    }

    private func copyBackendFiles(from source: URL) throws {
        // Ensure destination directory exists
        try FileManager.default.createDirectory(at: backendURL, withIntermediateDirectories: true)

        let files = ["main.py", "requirements.txt"]

        for file in files {
            let sourceFile = source.appendingPathComponent(file)
            guard FileManager.default.fileExists(atPath: sourceFile.path) else { continue }
            let destFile = backendURL.appendingPathComponent(file)

            if FileManager.default.fileExists(atPath: destFile.path) {
                try FileManager.default.removeItem(at: destFile)
            }

            try FileManager.default.copyItem(at: sourceFile, to: destFile)
        }

        let backendPath = self.backendURL.path
        logger.info("Backend files copied to: \(backendPath)")
    }

    private func installDependencies() async throws {
        logger.info("Installing Python dependencies...")

        state = .installingDependencies(progress: 0)

        let pipPath = venvURL.appendingPathComponent("bin/pip")
        let requirementsPath = backendURL.appendingPathComponent("requirements.txt")

        let process = Process()
        process.executableURL = pipPath
        process.arguments = ["install", "-r", requirementsPath.path, "--quiet"]
        process.currentDirectoryURL = backendURL

        // Capture output for progress estimation
        let outputPipe = Pipe()
        let errorPipe = Pipe()
        process.standardOutput = outputPipe
        process.standardError = errorPipe

        // Simulate progress while installing (pip doesn't give good progress)
        let progressTask = Task {
            var progress = 0.2
            while !Task.isCancelled && progress < 0.85 {
                try? await Task.sleep(nanoseconds: 500_000_000) // 0.5s
                progress += 0.05
                await MainActor.run {
                    self.state = .installingDependencies(progress: progress)
                }
            }
        }
        defer { progressTask.cancel() }

        try await runProcessAndWait(process)

        guard process.terminationStatus == 0 else {
            let errorData = errorPipe.fileHandleForReading.readDataToEndOfFile()
            let errorMessage = String(data: errorData, encoding: .utf8) ?? "Unknown error"
            logger.error("pip install failed: \(errorMessage)")
            throw BackendSetupError.dependencyInstallFailed(errorMessage)
        }

        state = .installingDependencies(progress: 1.0)
        logger.info("Dependencies installed successfully")
    }

    // MARK: - Backend Lifecycle

    private func launchBackend() async throws {
        logger.info("Launching backend server...")

        let pythonPath = venvURL.appendingPathComponent("bin/python")

        let process = Process()
        process.executableURL = pythonPath
        process.arguments = ["-m", "uvicorn", "main:app", "--host", "127.0.0.1", "--port", "8000"]
        let workingDir = backendWorkingURL
        process.currentDirectoryURL = workingDir
        logger.info("Backend working directory: \(workingDir.path)")

        // Set environment
        var env = ProcessInfo.processInfo.environment
        env["PYTHONUNBUFFERED"] = "1"
        process.environment = env

        // Redirect output to logs
        let logPipe = Pipe()
        process.standardOutput = logPipe
        process.standardError = logPipe

        // Log output asynchronously
        logPipe.fileHandleForReading.readabilityHandler = { [weak self] handle in
            let data = handle.availableData
            if !data.isEmpty, let output = String(data: data, encoding: .utf8) {
                self?.logger.debug("Backend: \(output)")
            }
        }

        try process.run()
        backendProcess = process

        // Save PID for crash recovery
        savePid(process.processIdentifier)

        logger.info("Backend process started with PID: \(process.processIdentifier)")
    }

    private func waitForHealthy(timeout: TimeInterval = 30) async throws {
        let healthURL = URL(string: "http://127.0.0.1:8000/health")!
        let startTime = Date()

        while Date().timeIntervalSince(startTime) < timeout {
            do {
                let (_, response) = try await URLSession.shared.data(from: healthURL)
                if let httpResponse = response as? HTTPURLResponse,
                   httpResponse.statusCode == 200 {
                    logger.info("Backend health check passed")
                    return
                }
            } catch {
                // Expected while server is starting
            }

            try await Task.sleep(nanoseconds: 500_000_000) // 0.5s
        }

        throw BackendSetupError.healthCheckTimeout
    }

    // MARK: - Process Management

    private func cleanupOrphanedProcesses() async {
        // Check for orphaned process from previous crash
        guard let savedPid = loadPid() else { return }

        logger.info("Found orphaned PID: \(savedPid), checking if alive...")

        // Check if process is still running
        if kill(savedPid, 0) == 0 {
            // Process exists, check if it's our backend (listening on 8000)
            if let output = await runShellCommand("lsof -i :8000 -t"),
               output.contains(String(savedPid)) {
                logger.info("Killing orphaned backend process: \(savedPid)")
                kill(savedPid, SIGTERM)
                try? await Task.sleep(for: .seconds(1))

                if kill(savedPid, 0) == 0 {
                    kill(savedPid, SIGKILL)
                }
            }
        }

        cleanupPidFile()
    }

    private func savePid(_ pid: Int32) {
        try? String(pid).write(to: pidFileURL, atomically: true, encoding: .utf8)
    }

    private func loadPid() -> Int32? {
        guard let content = try? String(contentsOf: pidFileURL, encoding: .utf8),
              let pid = Int32(content.trimmingCharacters(in: .whitespacesAndNewlines)) else {
            return nil
        }
        return pid
    }

    private func cleanupPidFile() {
        try? FileManager.default.removeItem(at: pidFileURL)
    }

    // MARK: - Helpers

    private func runShellCommand(_ command: String) async -> String? {
        let process = Process()
        process.executableURL = URL(fileURLWithPath: "/bin/bash")
        process.arguments = ["-c", command]

        let pipe = Pipe()
        process.standardOutput = pipe
        process.standardError = FileHandle.nullDevice

        do {
            try await runProcessAndWait(process)

            let data = pipe.fileHandleForReading.readDataToEndOfFile()
            return String(data: data, encoding: .utf8)
        } catch {
            return nil
        }
    }

    private func runProcessAndWait(_ process: Process) async throws {
        try await withCheckedThrowingContinuation { continuation in
            process.terminationHandler = { process in
                process.terminationHandler = nil
                continuation.resume(returning: ())
            }

            do {
                try process.run()
            } catch {
                process.terminationHandler = nil
                continuation.resume(throwing: error)
            }
        }
    }
}

// MARK: - Errors

public enum BackendSetupError: LocalizedError {
    case pythonNotFound
    case venvCreationFailed
    case backendFilesNotFound
    case dependencyInstallFailed(String)
    case backendStartFailed
    case healthCheckTimeout

    public var errorDescription: String? {
        switch self {
        case .pythonNotFound:
            return "Python 3.11 is required but not found. ACE-Step v1.5 requires Python 3.11.x."
        case .venvCreationFailed:
            return "Failed to create Python virtual environment."
        case .backendFilesNotFound:
            return "Backend files not found in app bundle."
        case .dependencyInstallFailed(let message):
            return "Failed to install dependencies: \(message)"
        case .backendStartFailed:
            return "Failed to start the music engine."
        case .healthCheckTimeout:
            return "Music engine failed to respond in time."
        }
    }
}
