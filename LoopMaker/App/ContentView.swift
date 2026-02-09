import SwiftUI

/// Main window with Liquid Glass navigation (macOS 26+)
/// Layout adapted from Echo-text: NavigationSplitView + glass sidebar + header toolbar
struct MainWindow: View {
    @EnvironmentObject var appState: AppState
    @StateObject private var licenseService = LicenseService.shared
    @State private var selectedTab: SidebarTab = .home
    @State private var selectedContentTab: ContentTab = .generate
    @State private var columnVisibility: NavigationSplitViewVisibility = .all
    @State private var searchText: String = ""
    @State private var isSearching: Bool = false

    // MARK: - Sidebar Tabs

    enum SidebarTab: String, CaseIterable, Identifiable {
        case home = "Home"
        case library = "Library"
        case feedback = "Feedback"
        case settings = "Settings"

        var id: String { rawValue }

        var icon: String {
            switch self {
            case .home: return "house"
            case .library: return "music.note.list"
            case .feedback: return "bubble.left"
            case .settings: return "gearshape"
            }
        }

        var selectedIcon: String {
            switch self {
            case .home: return "house.fill"
            case .library: return "music.note.list"
            case .feedback: return "bubble.left.fill"
            case .settings: return "gearshape.fill"
            }
        }

        static var mainTabs: [SidebarTab] { [.home, .library] }
        static var bottomTabs: [SidebarTab] { [.feedback, .settings] }
    }

    // MARK: - Content Tabs (shown inside Home)

    enum ContentTab: String, CaseIterable {
        case generate = "Generate"
        case favorites = "Favorites"
        case export = "Export"
    }

    // MARK: - Body

    /// Whether to show the full-screen setup overlay.
    /// Only shown for: first-time install, Python missing, or explicit errors.
    /// Normal backend startup (reconnecting on subsequent launches) shows the main app
    /// with a "connecting" indicator in the status bar instead.
    private var shouldShowSetupOverlay: Bool {
        let state = appState.backendManager.state
        // Always show for explicit setup trigger
        if appState.showSetup { return true }
        // Show for first-time installation steps
        if state.isFirstTimeSetup { return true }
        // Show for errors and missing Python
        if case .pythonMissing = state { return true }
        if case .error = state { return true }
        // First launch: show overlay while checking if venv exists
        if appState.backendManager.isFirstLaunch && state.isSetupPhase { return true }
        // Otherwise (normal reconnection), show main app
        return false
    }

    var body: some View {
        Group {
            if shouldShowSetupOverlay {
                SetupOverlay()
                    .environmentObject(appState)
            } else {
                mainAppContent
            }
        }
    }

    // MARK: - Main App Content

    private var mainAppContent: some View {
        VStack(spacing: 0) {
            NavigationSplitView(columnVisibility: $columnVisibility) {
                // Sidebar with Liquid Glass navigation
                sidebarContent
                    .navigationSplitViewColumnWidth(min: 200, ideal: 220, max: 260)
                    .background(.regularMaterial)
            } detail: {
                // Main content area
                detailContent
            }
            .navigationSplitViewStyle(.prominentDetail)

            if let playingTrack = appState.selectedTrack ?? appState.lastGeneratedTrack {
                PlayerBar(
                    track: playingTrack,
                    audioPlayer: appState.audioPlayer,
                    onPlayPause: { appState.togglePlayPause() },
                    onSeek: { appState.seekPlayback(to: $0) }
                )
                .transition(.move(edge: .bottom).combined(with: .opacity))
            }

            // Status bar footer (always visible, not overlapping)
            StatusBarView()
        }
        .frame(minWidth: 900, minHeight: 620)
        .sheet(isPresented: $appState.showExport) {
            if let track = appState.selectedTrack {
                ExportView(track: track)
            }
        }
    }

    // MARK: - Sidebar Content (Liquid Glass Navigation)

    private var sidebarContent: some View {
        VStack(alignment: .leading, spacing: 0) {
            // Top spacing
            Spacer()
                .frame(height: 12)

            // Main tabs with glass effect
            GlassEffectContainer {
                VStack(spacing: 2) {
                    ForEach(SidebarTab.mainTabs) { tab in
                        sidebarButton(tab)
                    }
                }
            }
            .padding(.horizontal, 8)

            Spacer()

            // Bottom section
            GlassEffectContainer {
                VStack(spacing: 2) {
                    sidebarButton(.feedback)
                    sidebarButton(.settings)
                }
            }
            .padding(.horizontal, 8)
            .padding(.bottom, 12)
        }
    }

    private func sidebarButton(_ tab: SidebarTab) -> some View {
        Button {
            withAnimation(.easeInOut(duration: 0.2)) {
                selectedTab = tab
            }
        } label: {
            HStack(spacing: 10) {
                Image(systemName: selectedTab == tab ? tab.selectedIcon : tab.icon)
                    .font(.system(size: 15, weight: selectedTab == tab ? .medium : .regular))
                    .frame(width: 20)
                Text(tab.rawValue)
                    .font(.system(size: 13, weight: selectedTab == tab ? .medium : .regular))
                Spacer()
            }
            .foregroundColor(selectedTab == tab ? .primary : .secondary)
            .padding(.horizontal, 12)
            .padding(.vertical, 10)
            .background(
                selectedTab == tab
                    ? Color.primary.opacity(0.1)
                    : Color.clear,
                in: RoundedRectangle(cornerRadius: 8)
            )
            .shadow(
                color: selectedTab == tab ? Color.black.opacity(0.06) : Color.clear,
                radius: 3,
                y: 1
            )
            .contentShape(RoundedRectangle(cornerRadius: 8))
        }
        .buttonStyle(.plain)
    }

    // MARK: - Detail Content

    @ViewBuilder
    private var detailContent: some View {
        switch selectedTab {
        case .home:
            VStack(spacing: 0) {
                // Header toolbar with glass content tabs
                headerToolbar

                // Content based on selected content tab
                switch selectedContentTab {
                case .generate:
                    GenerationView()
                case .favorites:
                    FavoritesView()
                case .export:
                    if let track = appState.selectedTrack {
                        ExportView(track: track)
                    } else {
                        noTrackSelectedView
                    }
                }
            }
            .background(Color(nsColor: .windowBackgroundColor))

        case .library:
            LibraryView()

        case .feedback:
            FeedbackView()

        case .settings:
            SettingsView()
                .environmentObject(appState)
        }
    }

    // MARK: - Header Toolbar (Glass Tabs + Search)

    @Namespace private var headerNamespace

    private var headerToolbar: some View {
        SwiftUI.GlassEffectContainer(spacing: 16) {
            HStack(spacing: 16) {
                // Tab pills with Liquid Glass
                HStack(spacing: 2) {
                    ForEach(ContentTab.allCases, id: \.self) { tab in
                        Button {
                            withAnimation(.spring(duration: 0.25, bounce: 0.15)) {
                                selectedContentTab = tab
                            }
                        } label: {
                            Text(tab.rawValue)
                                .font(.system(size: 13, weight: selectedContentTab == tab ? .semibold : .medium))
                                .foregroundColor(selectedContentTab == tab ? .primary : .secondary)
                                .padding(.horizontal, 14)
                                .padding(.vertical, 10)
                                .background(
                                    selectedContentTab == tab
                                        ? Color.primary.opacity(0.12)
                                        : Color.clear,
                                    in: .capsule
                                )
                        }
                        .buttonStyle(.plain)
                    }
                }
                .padding(4)
                .glassEffect(in: .capsule)
                .glassEffectID("tabs", in: headerNamespace)

                Spacer()

                // Search field with Liquid Glass
                HStack(spacing: 8) {
                    Image(systemName: "magnifyingglass")
                        .font(.system(size: 14, weight: .medium))
                        .foregroundColor(.secondary)

                    if isSearching {
                        TextField("Search tracks...", text: $searchText)
                            .textFieldStyle(.plain)
                            .font(.system(size: 14))
                            .frame(minWidth: 180, maxWidth: 240)

                        if !searchText.isEmpty {
                            Button {
                                searchText = ""
                            } label: {
                                Image(systemName: "xmark.circle.fill")
                                    .font(.system(size: 14))
                                    .foregroundColor(.secondary.opacity(0.7))
                            }
                            .buttonStyle(.plain)
                        }
                    } else {
                        Text("Search")
                            .font(.system(size: 14))
                            .foregroundColor(.secondary)
                    }
                }
                .padding(.horizontal, 14)
                .padding(.vertical, 10)
                .glassEffect(.regular.interactive(), in: .capsule)
                .glassEffectID("search", in: headerNamespace)
                .onTapGesture {
                    if !isSearching {
                        withAnimation(.spring(duration: 0.25)) {
                            isSearching = true
                        }
                    }
                }

                // Pro badge
                if licenseService.licenseState.isPro {
                    HStack(spacing: 4) {
                        Image(systemName: "star.fill")
                            .font(.system(size: 10))
                        Text("Pro")
                            .font(.system(size: 11, weight: .bold))
                    }
                    .foregroundColor(DesignSystem.Colors.accent)
                    .padding(.horizontal, 10)
                    .padding(.vertical, 6)
                    .glassEffect(.regular, in: .capsule)
                }
            }
        }
        .padding(.horizontal, 24)
        .padding(.top, 12)
        .padding(.bottom, 10)
    }

    // MARK: - Empty States

    private var noTrackSelectedView: some View {
        VStack(spacing: 16) {
            Spacer()
            Image(systemName: "square.and.arrow.up")
                .font(.system(size: 48))
                .foregroundColor(.secondary.opacity(0.5))
            Text("Select a track to export")
                .font(.system(size: 16, weight: .semibold, design: .rounded))
            Text("Generate or select a track from your library first")
                .font(.system(size: 13))
                .foregroundColor(.secondary)
            Spacer()
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }
}

// MARK: - Feedback View (Embedded)

struct FeedbackView: View {
    @State private var feedbackText = ""
    @State private var feedbackType: FeedbackType = .feature
    @State private var submitted = false

    enum FeedbackType: String, CaseIterable {
        case bug = "Bug Report"
        case feature = "Feature Request"
        case general = "General Feedback"

        var icon: String {
            switch self {
            case .bug: return "ladybug"
            case .feature: return "lightbulb"
            case .general: return "text.bubble"
            }
        }
    }

    var body: some View {
        ScrollView(showsIndicators: false) {
            VStack(alignment: .leading, spacing: 20) {
                // Header
                VStack(alignment: .leading, spacing: 4) {
                    Text("Feedback")
                        .font(.system(size: 24, weight: .bold, design: .rounded))
                        .foregroundColor(.primary)

                    Text("Help us improve LoopMaker")
                        .font(.system(size: 13))
                        .foregroundColor(.secondary)
                }

                // Type selector
                HStack(spacing: 8) {
                    ForEach(FeedbackType.allCases, id: \.self) { type in
                        Button {
                            feedbackType = type
                        } label: {
                            HStack(spacing: 6) {
                                Image(systemName: type.icon)
                                    .font(.system(size: 12))
                                Text(type.rawValue)
                                    .font(.system(size: 12, weight: feedbackType == type ? .semibold : .regular))
                            }
                            .foregroundColor(feedbackType == type ? .primary : .secondary)
                            .padding(.horizontal, 12)
                            .padding(.vertical, 8)
                            .background(
                                feedbackType == type
                                    ? Color.primary.opacity(0.1)
                                    : Color.clear,
                                in: RoundedRectangle(cornerRadius: 8)
                            )
                        }
                        .buttonStyle(.plain)
                    }
                }

                // Text input
                TextEditor(text: $feedbackText)
                    .font(.system(size: 14))
                    .scrollContentBackground(.hidden)
                    .frame(minHeight: 200)
                    .padding(12)
                    .background(
                        Color(nsColor: .controlBackgroundColor),
                        in: RoundedRectangle(cornerRadius: 12)
                    )

                // Submit
                HStack {
                    Spacer()
                    Button {
                        NSWorkspace.shared.open(Constants.URLs.helpURL)
                    } label: {
                        Text("Send Feedback")
                            .font(.system(size: 13, weight: .semibold))
                            .foregroundColor(.white)
                            .padding(.horizontal, 20)
                            .padding(.vertical, 10)
                            .background(
                                DesignSystem.Colors.accent,
                                in: RoundedRectangle(cornerRadius: 10)
                            )
                    }
                    .buttonStyle(.plain)
                }
            }
            .padding(28)
            .frame(maxWidth: 700, alignment: .leading)
        }
        .frame(maxWidth: .infinity)
        .background(Color(nsColor: .windowBackgroundColor))
    }
}

// MARK: - Setup Overlay

struct SetupOverlay: View {
    @EnvironmentObject var appState: AppState
    @State private var showContent = false

    var body: some View {
        ZStack {
            // Background
            Color(nsColor: .windowBackgroundColor)
                .ignoresSafeArea()

            VStack(spacing: 0) {
                Spacer()

                // App branding
                VStack(spacing: 20) {
                    Image(systemName: "waveform.circle.fill")
                        .font(.system(size: 72))
                        .foregroundStyle(.linearGradient(
                            colors: [DesignSystem.Colors.accent, DesignSystem.Colors.accentSecondary],
                            startPoint: .topLeading,
                            endPoint: .bottomTrailing
                        ))
                        .symbolEffect(.pulse, options: .repeating)
                        .shadow(color: DesignSystem.Colors.accent.opacity(0.3), radius: 20)

                    VStack(spacing: 6) {
                        Text("LoopMaker")
                            .font(.system(size: 32, weight: .bold, design: .rounded))

                        Text("AI Music Generator")
                            .font(.system(size: 15, weight: .medium))
                            .foregroundStyle(.secondary)
                    }
                }
                .scaleEffect(showContent ? 1.0 : 0.9)
                .opacity(showContent ? 1.0 : 0)

                Spacer()
                    .frame(height: 48)

                // Setup steps / progress
                SetupProgressContent(
                    state: appState.backendManager.state,
                    isFirstLaunch: appState.backendManager.isFirstLaunch,
                    onRetry: {
                        Task { await appState.retryBackendSetup() }
                    }
                )
                .frame(maxWidth: 480)
                .opacity(showContent ? 1.0 : 0)

                Spacer()

                // Footer
                HStack {
                    if appState.backendManager.isFirstLaunch {
                        Label("First-time setup - this only happens once", systemImage: "info.circle")
                            .font(.system(size: 12))
                            .foregroundStyle(.secondary)
                    }
                    Spacer()
                    Text("v\(Bundle.main.infoDictionary?["CFBundleShortVersionString"] as? String ?? "1.0.0")")
                        .font(.system(size: 11, weight: .medium, design: .monospaced))
                        .foregroundStyle(.tertiary)
                }
                .padding(.horizontal, 32)
                .padding(.bottom, 20)
            }
        }
        .onAppear {
            withAnimation(.easeOut(duration: 0.5)) {
                showContent = true
            }
        }
    }
}

/// Progress content for setup overlay
struct SetupProgressContent: View {
    let state: BackendProcessManager.State
    let isFirstLaunch: Bool
    let onRetry: () -> Void

    var body: some View {
        VStack(spacing: 0) {
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
        .padding(28)
        .background(
            Color(nsColor: .controlBackgroundColor),
            in: RoundedRectangle(cornerRadius: 16)
        )
        .animation(.easeInOut(duration: 0.3), value: state)
    }

    private var progressView: some View {
        VStack(spacing: 20) {
            // Step indicators
            HStack(spacing: 0) {
                ForEach(SetupStep.allCases, id: \.self) { step in
                    stepIndicator(step)
                    if step != SetupStep.allCases.last {
                        Rectangle()
                            .fill(step.isComplete(for: state) ? DesignSystem.Colors.accent : Color.secondary.opacity(0.2))
                            .frame(height: 2)
                            .animation(.easeInOut(duration: 0.3), value: state)
                    }
                }
            }
            .padding(.horizontal, 8)

            // Current step info
            VStack(spacing: 8) {
                Text(state.userMessage)
                    .font(.system(size: 15, weight: .semibold))
                    .foregroundStyle(.primary)

                if case .installingDependencies = state {
                    Text("Setting up AI models and Python dependencies...")
                        .font(.system(size: 12))
                        .foregroundStyle(.secondary)
                }
            }

            ProgressView(value: progressValue)
                .progressViewStyle(.linear)
                .tint(DesignSystem.Colors.accent)
        }
    }

    private func stepIndicator(_ step: SetupStep) -> some View {
        VStack(spacing: 6) {
            ZStack {
                Circle()
                    .fill(step.isComplete(for: state) ? DesignSystem.Colors.accent : (step.isCurrent(for: state) ? DesignSystem.Colors.accent.opacity(0.2) : Color.secondary.opacity(0.1)))
                    .frame(width: 28, height: 28)

                if step.isComplete(for: state) {
                    Image(systemName: "checkmark")
                        .font(.system(size: 12, weight: .bold))
                        .foregroundStyle(.white)
                } else {
                    Image(systemName: step.icon)
                        .font(.system(size: 11))
                        .foregroundStyle(step.isCurrent(for: state) ? DesignSystem.Colors.accent : .secondary)
                }
            }

            Text(step.label)
                .font(.system(size: 10, weight: step.isCurrent(for: state) ? .semibold : .regular))
                .foregroundStyle(step.isCurrent(for: state) ? .primary : .secondary)
                .lineLimit(1)
                .fixedSize()
        }
        .frame(maxWidth: .infinity)
    }

    private var successView: some View {
        VStack(spacing: 16) {
            Image(systemName: "checkmark.circle.fill")
                .font(.system(size: 44))
                .foregroundStyle(DesignSystem.Colors.success)

            VStack(spacing: 4) {
                Text("Ready to create music!")
                    .font(.system(size: 16, weight: .semibold))
                Text("Your AI music engine is set up and ready to go.")
                    .font(.system(size: 13))
                    .foregroundStyle(.secondary)
            }
        }
    }

    private func errorView(message: String) -> some View {
        VStack(spacing: 16) {
            Image(systemName: "exclamationmark.triangle.fill")
                .font(.system(size: 44))
                .foregroundStyle(.orange)

            VStack(spacing: 4) {
                Text("Setup couldn't complete")
                    .font(.system(size: 16, weight: .semibold))
                Text(message)
                    .font(.system(size: 12))
                    .foregroundStyle(.secondary)
                    .multilineTextAlignment(.center)
                    .frame(maxWidth: 380)
            }

            HStack(spacing: 12) {
                Button(action: onRetry) {
                    Text("Retry")
                        .font(.system(size: 13, weight: .semibold))
                        .foregroundColor(.white)
                        .padding(.horizontal, 20)
                        .padding(.vertical, 8)
                        .background(DesignSystem.Colors.accent, in: RoundedRectangle(cornerRadius: 8))
                }
                .buttonStyle(.plain)

                Button {
                    NSWorkspace.shared.open(Constants.URLs.helpURL)
                } label: {
                    Text("Get Help")
                        .font(.system(size: 13, weight: .medium))
                        .padding(.horizontal, 20)
                        .padding(.vertical, 8)
                        .background(Color.secondary.opacity(0.12), in: RoundedRectangle(cornerRadius: 8))
                }
                .buttonStyle(.plain)
            }
        }
    }

    private var pythonMissingView: some View {
        VStack(spacing: 16) {
            Image(systemName: "exclamationmark.triangle.fill")
                .font(.system(size: 44))
                .foregroundStyle(.orange)

            VStack(spacing: 4) {
                Text("Python Required")
                    .font(.system(size: 16, weight: .semibold))
                Text("LoopMaker needs Python 3.9+ to run the AI music engine.")
                    .font(.system(size: 13))
                    .foregroundStyle(.secondary)
                    .multilineTextAlignment(.center)
            }

            VStack(spacing: 12) {
                Button {
                    if let url = URL(string: "https://www.python.org/downloads/") {
                        NSWorkspace.shared.open(url)
                    }
                } label: {
                    HStack(spacing: 6) {
                        Image(systemName: "arrow.down.circle.fill")
                            .font(.system(size: 13))
                        Text("Download Python")
                            .font(.system(size: 13, weight: .semibold))
                    }
                    .foregroundColor(.white)
                    .padding(.horizontal, 20)
                    .padding(.vertical, 10)
                    .frame(maxWidth: .infinity)
                    .background(DesignSystem.Colors.accent, in: RoundedRectangle(cornerRadius: 8))
                }
                .buttonStyle(.plain)

                HStack(spacing: 8) {
                    Text("Or via Homebrew:")
                        .font(.system(size: 11))
                        .foregroundStyle(.secondary)
                    Text("brew install python@3.11")
                        .font(.system(size: 11, design: .monospaced))
                        .padding(.horizontal, 8)
                        .padding(.vertical, 4)
                        .background(Color.primary.opacity(0.06), in: RoundedRectangle(cornerRadius: 4))
                }
            }

            Button(action: onRetry) {
                Text("Retry After Installing")
                    .font(.system(size: 13, weight: .medium))
                    .padding(.horizontal, 20)
                    .padding(.vertical, 8)
                    .background(Color.secondary.opacity(0.12), in: RoundedRectangle(cornerRadius: 8))
            }
            .buttonStyle(.plain)
        }
    }

    private var progressValue: Double {
        switch state {
        case .notStarted: return 0
        case .checkingPython: return 0.05
        case .pythonMissing: return 0
        case .checkingVenv: return 0.1
        case .creatingVenv: return 0.15
        case .installingDependencies(let progress): return 0.15 + (progress * 0.7)
        case .startingBackend: return 0.9
        case .waitingForHealth: return 0.95
        case .running: return 1.0
        case .error: return 0
        }
    }
}

// MARK: - Setup Steps

enum SetupStep: Int, CaseIterable {
    case python = 0
    case environment = 1
    case dependencies = 2
    case engine = 3

    var label: String {
        switch self {
        case .python: return "Python"
        case .environment: return "Env"
        case .dependencies: return "Deps"
        case .engine: return "Engine"
        }
    }

    var icon: String {
        switch self {
        case .python: return "terminal"
        case .environment: return "folder"
        case .dependencies: return "arrow.down"
        case .engine: return "bolt"
        }
    }

    func isComplete(for state: BackendProcessManager.State) -> Bool {
        switch self {
        case .python:
            return state != .notStarted && state != .checkingPython && state != .pythonMissing
        case .environment:
            switch state {
            case .notStarted, .checkingPython, .pythonMissing, .checkingVenv, .creatingVenv:
                return false
            default:
                return true
            }
        case .dependencies:
            switch state {
            case .notStarted, .checkingPython, .pythonMissing, .checkingVenv, .creatingVenv, .installingDependencies:
                return false
            default:
                return true
            }
        case .engine:
            return state == .running
        }
    }

    func isCurrent(for state: BackendProcessManager.State) -> Bool {
        switch self {
        case .python:
            return state == .checkingPython
        case .environment:
            return state == .checkingVenv || state == .creatingVenv
        case .dependencies:
            if case .installingDependencies = state { return true }
            return false
        case .engine:
            return state == .startingBackend || state == .waitingForHealth
        }
    }
}

#Preview {
    MainWindow()
        .environmentObject(AppState())
}
