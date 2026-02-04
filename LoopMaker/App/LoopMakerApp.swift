import SwiftUI

@main
struct LoopMakerApp: App {
    @StateObject private var appState = AppState()
    @Environment(\.scenePhase) private var scenePhase

    var body: some Scene {
        WindowGroup {
            ZStack {
                ContentView()
                    .environmentObject(appState)

                // Show setup overlay when needed
                if appState.showSetup || appState.backendManager.state.isSetupPhase {
                    SetupOverlay()
                        .environmentObject(appState)
                }
            }
        }
        .windowStyle(.automatic)
        .defaultSize(width: 1200, height: 800)
        .commands {
            CommandGroup(replacing: .newItem) {}

            CommandMenu("Generation") {
                Button("New Generation") {
                    appState.showNewGeneration = true
                }
                .keyboardShortcut("n", modifiers: [.command])

                Divider()

                Button("Cancel Generation") {
                    appState.cancelGeneration()
                }
                .keyboardShortcut(".", modifiers: [.command])
                .disabled(!appState.isGenerating)
            }
        }
        .onChange(of: scenePhase) { _, newPhase in
            if newPhase == .background {
                // App is going to background - could pause backend if needed
            }
        }
    }

    init() {
        // Register for app termination to clean up backend process
        NotificationCenter.default.addObserver(
            forName: NSApplication.willTerminateNotification,
            object: nil,
            queue: .main
        ) { _ in
            // Stop backend process on app termination
            Task { @MainActor in
                AppState.shared?.backendManager.stopBackend()
            }
        }
    }
}

/// Overlay view for setup/loading state
struct SetupOverlay: View {
    @EnvironmentObject var appState: AppState

    var body: some View {
        ZStack {
            // Blurred background
            Color.black.opacity(0.3)
                .ignoresSafeArea()

            // Setup content
            VStack(spacing: 40) {
                Spacer()

                // App icon and title
                VStack(spacing: 16) {
                    Image(systemName: "waveform.circle.fill")
                        .font(.system(size: 80))
                        .foregroundStyle(.linearGradient(
                            colors: [.purple, .blue],
                            startPoint: .topLeading,
                            endPoint: .bottomTrailing
                        ))
                        .symbolEffect(.pulse, options: .repeating)

                    Text("LoopMaker")
                        .font(.largeTitle)
                        .fontWeight(.bold)

                    Text("AI Music Generator")
                        .font(.title3)
                        .foregroundStyle(.secondary)
                }

                Spacer()

                // Progress section
                SetupProgressContent(
                    state: appState.backendManager.state,
                    isFirstLaunch: appState.backendManager.isFirstLaunch,
                    onRetry: {
                        Task {
                            await appState.retryBackendSetup()
                        }
                    }
                )

                Spacer()

                // Footer
                if appState.backendManager.isFirstLaunch {
                    Text("This only happens once!")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
            }
            .padding(60)
            .frame(minWidth: 500, minHeight: 400)
            .background(.ultraThinMaterial)
            .cornerRadius(20)
            .shadow(radius: 20)
        }
        .transition(.opacity)
    }
}

/// Progress content for setup overlay
struct SetupProgressContent: View {
    let state: BackendProcessManager.State
    let isFirstLaunch: Bool
    let onRetry: () -> Void

    var body: some View {
        VStack(spacing: 20) {
            switch state {
            case .error(let message):
                errorView(message: message)

            case .pythonMissing:
                pythonMissingView

            case .running:
                successView

            default:
                progressView
            }
        }
        .animation(.easeInOut, value: state)
    }

    // MARK: - Views

    private var progressView: some View {
        VStack(spacing: 16) {
            Text(state.userMessage)
                .font(.headline)
                .foregroundStyle(.primary)

            ProgressView(value: progressValue)
                .progressViewStyle(.linear)
                .frame(width: 300)

            if case .installingDependencies = state {
                Text("Downloading AI models and dependencies...")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
        }
    }

    private var successView: some View {
        VStack(spacing: 16) {
            Image(systemName: "checkmark.circle.fill")
                .font(.system(size: 48))
                .foregroundStyle(.green)

            Text("Ready to create music!")
                .font(.headline)
        }
    }

    private func errorView(message: String) -> some View {
        VStack(spacing: 16) {
            Image(systemName: "exclamationmark.triangle.fill")
                .font(.system(size: 48))
                .foregroundStyle(.orange)

            Text("Setup couldn't complete")
                .font(.headline)

            Text(message)
                .font(.caption)
                .foregroundStyle(.secondary)
                .multilineTextAlignment(.center)
                .frame(maxWidth: 400)

            HStack(spacing: 12) {
                Button("Retry", action: onRetry)
                    .buttonStyle(.borderedProminent)

                Button("Get Help") {
                    if let url = URL(string: "https://github.com/loopmaker/loopmaker/issues") {
                        NSWorkspace.shared.open(url)
                    }
                }
                .buttonStyle(.bordered)
            }
            .padding(.top, 8)
        }
    }

    private var pythonMissingView: some View {
        VStack(spacing: 16) {
            Image(systemName: "exclamationmark.triangle.fill")
                .font(.system(size: 48))
                .foregroundStyle(.orange)

            Text("Python Required")
                .font(.headline)

            Text("LoopMaker needs Python 3.9 or later to run the AI engine.")
                .font(.body)
                .foregroundStyle(.secondary)
                .multilineTextAlignment(.center)
                .frame(maxWidth: 400)

            VStack(alignment: .leading, spacing: 8) {
                Text("Install Python:")
                    .font(.caption)
                    .fontWeight(.semibold)

                Button("Download from python.org") {
                    if let url = URL(string: "https://www.python.org/downloads/") {
                        NSWorkspace.shared.open(url)
                    }
                }
                .buttonStyle(.borderedProminent)

                Text("Or install via Homebrew:")
                    .font(.caption)
                    .foregroundStyle(.secondary)

                Text("brew install python@3.11")
                    .font(.system(.caption, design: .monospaced))
                    .padding(8)
                    .background(Color.black.opacity(0.1))
                    .cornerRadius(4)
            }
            .padding(.top, 8)

            Button("Retry After Installing", action: onRetry)
                .buttonStyle(.bordered)
                .padding(.top, 16)
        }
    }

    // MARK: - Computed Properties

    private var progressValue: Double {
        switch state {
        case .notStarted:
            return 0
        case .checkingPython:
            return 0.05
        case .pythonMissing:
            return 0
        case .checkingVenv:
            return 0.1
        case .creatingVenv:
            return 0.15
        case .installingDependencies(let progress):
            return 0.15 + (progress * 0.7)
        case .startingBackend:
            return 0.9
        case .waitingForHealth:
            return 0.95
        case .running:
            return 1.0
        case .error:
            return 0
        }
    }
}

// MARK: - Shared AppState Access

extension AppState {
    /// Shared instance for app-level access (e.g., termination handler)
    @MainActor static var shared: AppState?

    /// Call during app init to set up shared instance
    @MainActor func registerAsShared() {
        AppState.shared = self
    }
}
