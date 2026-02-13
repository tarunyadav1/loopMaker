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
                return "Python 3.11 not found. Please install Python 3.11.x to continue."
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
    @Published public var port: Int = 8000

    // MARK: - Private Properties

    private var backendProcess: Process?
    private var healthCheckTask: Task<Void, Never>?
    private var isStarting = false
    private var crashRetryCount = 0
    private let maxCrashRetries = 3
    private static let portRange = 8000...8003
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

    /// Pre-installed site-packages bundled inside the .app for zero-download distribution.
    private var bundledSitePackagesURL: URL? {
        Bundle.main.resourceURL?
            .appendingPathComponent("backend", isDirectory: true)
            .appendingPathComponent("site-packages", isDirectory: true)
    }

    /// True when the .app contains pre-bundled Python + site-packages (no pip install needed).
    private var isBundledMode: Bool {
        guard let sitePackages = bundledSitePackagesURL,
              let python = bundledPythonURL else { return false }
        return FileManager.default.fileExists(atPath: sitePackages.path)
            && FileManager.default.isExecutableFile(atPath: python.path)
    }

    /// Sentinel file written after successful pip install.
    /// Distinguishes a complete venv from one that failed mid-install.
    private var setupCompleteURL: URL {
        venvURL.appendingPathComponent(".setup-complete")
    }

    /// In dev mode (debug build from source tree), resolve the source backend directory.
    /// Only compiled in DEBUG to avoid leaking the build machine path in release binaries.
    private var sourceBackendURL: URL? {
        #if DEBUG
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
        #endif
        return nil
    }

    /// The directory where uvicorn should run.
    /// Bundled: Resources/backend/ inside the .app
    /// Dev: source tree's backend/
    /// Prod unbundled: App Support backend/
    private var backendWorkingURL: URL {
        if isBundledMode, let bundled = bundledBackendURL {
            return bundled
        }
        return sourceBackendURL ?? backendURL
    }

    /// Whether we're running from a debug build with access to the source tree
    private var isDevMode: Bool {
        sourceBackendURL != nil
    }

    /// The single venv all methods should use.
    /// Dev mode: source tree's `backend/.venv/` (must be pre-created by the developer).
    /// Prod mode: App Support's `.venv/` (created on first launch).
    /// This eliminates the split-brain where venv creation targeted App Support
    /// but launchBackend preferred the source tree's venv.
    private var activeVenvURL: URL {
        if let sourceDir = sourceBackendURL {
            let sourceVenv = sourceDir.appendingPathComponent(".venv", isDirectory: true)
            if FileManager.default.fileExists(atPath: sourceVenv.path) {
                return sourceVenv
            }
        }
        return venvURL
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
        guard !isStarting, state != .running else { return }
        isStarting = true
        defer { isStarting = false }

        // Clean up any orphaned processes
        await cleanupOrphanedProcesses()

        // Bundled mode: skip all setup, launch directly with bundled Python + site-packages
        if isBundledMode {
            logger.info("Bundled mode: using pre-installed Python and site-packages")
            do {
                state = .startingBackend
                setupProgress = 0.9
                try await launchBackend()

                state = .waitingForHealth
                try await waitForHealthy()

                setupProgress = 1.0
                state = .running
                startHealthMonitoring()
            } catch {
                state = .error("Could not start backend: \(error.localizedDescription)")
            }
            return
        }

        // Non-bundled mode: check Python and venv
        state = .checkingPython

        guard let pythonPath = await detectPython() else {
            state = .pythonMissing
            return
        }

        // Check if the active venv exists AND completed setup successfully.
        // A venv directory without the sentinel file means pip install failed mid-way.
        state = .checkingVenv
        let venvExists = FileManager.default.fileExists(atPath: activeVenvURL.path)
        let setupComplete = FileManager.default.fileExists(atPath: setupCompleteURL.path)
        let needsSetup = !venvExists || (!setupComplete && !isDevMode)
        isFirstLaunch = needsSetup

        if needsSetup {
            if isDevMode {
                state = .error(
                    "Dev mode: no venv found at backend/.venv/. "
                    + "Run: cd backend && python3 -m venv .venv && .venv/bin/pip install -r requirements.txt"
                )
                return
            }

            // Prod unbundled: first launch or broken venv recovery
            do {
                // Remove any half-installed venv before starting fresh
                if venvExists && !setupComplete {
                    logger.warning("Found incomplete venv, removing for fresh install...")
                    try? FileManager.default.removeItem(at: venvURL)
                }

                state = .creatingVenv
                setupProgress = 0.1
                try await createVenv(pythonPath: pythonPath)

                setupProgress = 0.2
                try await installDependencies()

                // Write sentinel to mark successful setup
                try "ok".write(to: setupCompleteURL, atomically: true, encoding: .utf8)

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
            startHealthMonitoring()
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

    /// Synchronous termination for use in the app termination handler.
    /// Sends SIGTERM immediately without waiting for graceful shutdown.
    public func terminateBackendNow() {
        healthCheckTask?.cancel()
        healthCheckTask = nil
        backendProcess?.terminate()
        backendProcess = nil
        cleanupPidFile()
    }

    /// Retry setup after an error. Removes any broken venv to force fresh install.
    public func retrySetup() async {
        state = .notStarted
        setupProgress = 0
        // Remove broken venv so setup re-triggers
        if !isDevMode && !isBundledMode {
            try? FileManager.default.removeItem(at: venvURL)
        }
        await ensureBackendRunning()
    }

    /// Restart the backend process without rebuilding the venv.
    /// - Parameter resetRetryCount: When `true` (default for manual restarts), resets the crash
    ///   retry counter. Auto-recovery passes `false` to preserve the counter.
    public func restartBackend(resetRetryCount: Bool = true) async {
        logger.info("Restarting backend...")
        await stopBackend()
        state = .notStarted
        if resetRetryCount {
            crashRetryCount = 0
        }

        do {
            state = .startingBackend
            setupProgress = 0.9
            try await launchBackend()

            state = .waitingForHealth
            try await waitForHealthy()

            setupProgress = 1.0
            state = .running
            startHealthMonitoring()
        } catch {
            state = .error("Restart failed: \(error.localizedDescription)")
        }
    }

    /// Stop the backend, wipe the venv and setup sentinel, then re-run full setup.
    public func cleanInstall() async {
        logger.info("Starting clean install...")
        await stopBackend()
        state = .notStarted
        setupProgress = 0
        crashRetryCount = 0

        // Remove venv and setup sentinel (prod mode only)
        if !isDevMode && !isBundledMode {
            try? FileManager.default.removeItem(at: venvURL)
            try? FileManager.default.removeItem(at: setupCompleteURL)
        }

        await ensureBackendRunning()
    }

    /// The Application Support backend directory, exposed for cache cleanup.
    public var backendDirectoryURL: URL { backendURL }

    /// Current backend PID (if known and alive), for lightweight telemetry in UI.
    public var currentBackendPID: Int32? {
        if let process = backendProcess, process.isRunning {
            return process.processIdentifier
        }

        if let (savedPid, _) = loadPidAndPort(), kill(savedPid, 0) == 0 {
            return savedPid
        }

        return nil
    }

    // MARK: - Health Monitoring

    /// Periodically check backend health after reaching .running state.
    /// Detects process crashes and attempts auto-recovery before reporting errors.
    private func startHealthMonitoring() {
        crashRetryCount = 0
        healthCheckTask?.cancel()
        healthCheckTask = Task {
            while !Task.isCancelled {
                try? await Task.sleep(for: .seconds(10))
                guard !Task.isCancelled else { break }

                // Fast check: is the process still alive?
                if backendProcess?.isRunning != true {
                    logger.error("Backend process died unexpectedly")

                    if crashRetryCount < maxCrashRetries {
                        crashRetryCount += 1
                        let attempt = crashRetryCount
                        logger.info("Auto-restart attempt \(attempt)/\(self.maxCrashRetries)...")
                        await restartBackend(resetRetryCount: false)
                        // If restart succeeded, restartBackend already calls startHealthMonitoring
                        // which replaces this task, so we can break out of this loop.
                        break
                    } else {
                        state = .error(
                            "Backend crashed repeatedly (\(self.maxCrashRetries) retries exhausted). "
                            + "Try restarting from Settings."
                        )
                        break
                    }
                }

                // Slow check: is the HTTP endpoint responding?
                let healthURL = URL(string: "http://127.0.0.1:\(self.port)/health")!
                do {
                    let (_, response) = try await URLSession.shared.data(from: healthURL)
                    if let http = response as? HTTPURLResponse, http.statusCode != 200 {
                        logger.warning("Backend health check returned \(http.statusCode)")
                    }
                } catch {
                    // Process is running but not responding — could be busy with generation.
                    // Only log; the process-alive check above catches actual crashes.
                    logger.warning("Backend health check failed: \(error.localizedDescription)")
                }
            }
        }
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
        // Prefer bundled backend files from inside the .app
        if let bundledBackend = bundledBackendURL,
           FileManager.default.fileExists(atPath: bundledBackend.path) {
            try copyBackendFiles(from: bundledBackend)
            return
        }

        // Dev mode: use backend files from source tree
        if let sourceBackend = sourceBackendURL {
            try copyBackendFiles(from: sourceBackend)
            return
        }

        throw BackendSetupError.backendFilesNotFound
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

        let pipPath = activeVenvURL.appendingPathComponent("bin/pip")
        let requirementsPath = backendWorkingURL.appendingPathComponent("requirements.txt")

        let process = Process()
        process.executableURL = pipPath
        process.arguments = ["install", "-r", requirementsPath.path, "--quiet"]
        process.currentDirectoryURL = backendURL

        // Drain stdout/stderr asynchronously to prevent pipe buffer deadlock.
        // If the buffer (~64KB) fills and nobody reads, the process blocks on write
        // and runProcessAndWait never returns.
        let outputPipe = Pipe()
        let errorPipe = Pipe()
        process.standardOutput = outputPipe
        process.standardError = errorPipe

        // Collect stderr for error reporting
        let errorBuffer = PipeBuffer()
        errorPipe.fileHandleForReading.readabilityHandler = { handle in
            let data = handle.availableData
            if !data.isEmpty {
                errorBuffer.append(data)
            }
        }
        // Discard stdout (just drain it)
        outputPipe.fileHandleForReading.readabilityHandler = { handle in
            _ = handle.availableData
        }

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

        // Stop draining now that the process has exited
        errorPipe.fileHandleForReading.readabilityHandler = nil
        outputPipe.fileHandleForReading.readabilityHandler = nil

        guard process.terminationStatus == 0 else {
            let errorMessage = errorBuffer.string ?? "Unknown error"
            logger.error("pip install failed: \(errorMessage)")
            throw BackendSetupError.dependencyInstallFailed(errorMessage)
        }

        state = .installingDependencies(progress: 1.0)
        logger.info("Dependencies installed successfully")
    }

    // MARK: - Backend Lifecycle

    private func launchBackend() async throws {
        logger.info("Launching backend server...")

        // Find an available port from the range
        var selectedPort: Int?
        for candidate in Self.portRange {
            if let lsofOutput = await runShellCommand("lsof -i :\(candidate) -t"),
               !lsofOutput.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
                logger.info("Port \(candidate) is in use, trying next...")
                continue
            }
            selectedPort = candidate
            break
        }

        guard let chosenPort = selectedPort else {
            logger.error("All ports \(Self.portRange) are in use")
            throw BackendSetupError.portConflict
        }

        port = chosenPort
        logger.info("Selected port: \(chosenPort)")

        let workingDir = backendWorkingURL
        let pythonPath: URL
        var env = ProcessInfo.processInfo.environment
        env["PYTHONUNBUFFERED"] = "1"

        if isBundledMode {
            // Bundled mode: use bundled Python with PYTHONPATH for pre-installed packages
            pythonPath = bundledPythonURL!
            if let sitePackages = bundledSitePackagesURL {
                env["PYTHONPATH"] = sitePackages.path
            }
        } else {
            // Venv mode: use the venv's Python (which already knows its site-packages)
            pythonPath = activeVenvURL.appendingPathComponent("bin/python")
        }

        let process = Process()
        process.executableURL = pythonPath
        process.arguments = ["-m", "uvicorn", "main:app", "--host", "127.0.0.1", "--port", "\(chosenPort)"]
        process.currentDirectoryURL = workingDir
        process.environment = env
        logger.info("Backend working directory: \(workingDir.path)")
        logger.info("Backend Python: \(pythonPath.path)")
        if let pp = env["PYTHONPATH"] {
            logger.info("PYTHONPATH: \(pp)")
        }

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

        // Save PID and port for crash recovery
        savePid(process.processIdentifier)

        logger.info("Backend process started with PID: \(process.processIdentifier) on port \(chosenPort)")
    }

    private func waitForHealthy(timeout: TimeInterval = 30) async throws {
        let healthURL = URL(string: "http://127.0.0.1:\(port)/health")!
        let startTime = Date()

        while Date().timeIntervalSince(startTime) < timeout {
            // Bail immediately if the process already exited
            if backendProcess?.isRunning != true {
                logger.error("Backend process exited before becoming healthy")
                throw BackendSetupError.backendStartFailed
            }

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
        guard let (savedPid, savedPort) = loadPidAndPort() else { return }

        logger.info("Found orphaned PID: \(savedPid) on port \(savedPort), checking if alive...")

        // Check if process is still running
        if kill(savedPid, 0) == 0 {
            // Process exists, check if it's our backend (listening on saved port)
            if let output = await runShellCommand("lsof -i :\(savedPort) -t"),
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

    /// Save PID and port in format "pid:port" for orphan cleanup.
    private func savePid(_ pid: Int32) {
        try? "\(pid):\(port)".write(to: pidFileURL, atomically: true, encoding: .utf8)
    }

    /// Load PID and port from the pid file. Falls back to port 8000 for old-format files.
    private func loadPidAndPort() -> (pid: Int32, port: Int)? {
        guard let content = try? String(contentsOf: pidFileURL, encoding: .utf8) else {
            return nil
        }
        let trimmed = content.trimmingCharacters(in: .whitespacesAndNewlines)
        let parts = trimmed.split(separator: ":")
        if parts.count == 2,
           let pid = Int32(parts[0]),
           let savedPort = Int(parts[1]) {
            return (pid, savedPort)
        }
        // Legacy format: just PID
        if let pid = Int32(trimmed) {
            return (pid, 8000)
        }
        return nil
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

        // Drain stdout asynchronously to prevent pipe buffer deadlock
        let buffer = PipeBuffer()
        pipe.fileHandleForReading.readabilityHandler = { handle in
            let data = handle.availableData
            if !data.isEmpty {
                buffer.append(data)
            }
        }

        do {
            try await runProcessAndWait(process)
            pipe.fileHandleForReading.readabilityHandler = nil
            return buffer.string
        } catch {
            pipe.fileHandleForReading.readabilityHandler = nil
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

// MARK: - Pipe Buffer

/// Thread-safe buffer for collecting pipe output from readabilityHandler callbacks.
/// Prevents pipe buffer deadlock by draining data as it arrives.
private final class PipeBuffer: @unchecked Sendable {
    private var data = Data()
    private let lock = NSLock()

    func append(_ newData: Data) {
        lock.lock()
        data.append(newData)
        lock.unlock()
    }

    var string: String? {
        lock.lock()
        defer { lock.unlock() }
        return String(data: data, encoding: .utf8)
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
    case portConflict

    public var errorDescription: String? {
        switch self {
        case .pythonNotFound:
            return "Python 3.11 is required but not found. Please install Python 3.11.x to continue."
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
        case .portConflict:
            return "Ports 8000–8003 are all in use. Please free one and try again."
        }
    }
}
