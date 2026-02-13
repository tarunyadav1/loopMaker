import SwiftUI

/// Global application state
@MainActor
public final class AppState: ObservableObject {
    enum MainSidebarTab: String, CaseIterable, Identifiable {
        case home = "Home"
        case library = "Library"
        case settings = "Settings"

        var id: String { rawValue }
    }

    enum HomeContentTab: String, CaseIterable {
        case generate = "Generate"
        case favorites = "Favorites"
    }

    // MARK: - Navigation State
    @Published var selectedMainSidebarTab: MainSidebarTab = .home
    @Published var selectedHomeContentTab: HomeContentTab = .generate
    @Published var showNewGeneration = false
    @Published var showSettings = false
    @Published var showExport = false

    // MARK: - Setup State
    @Published var showSetup = false
    @Published var backendManager = BackendProcessManager()

    // MARK: - Generation State
    @Published var isGenerating = false
    @Published var generationProgress: Double = 0
    @Published var generationStatus: String = ""
    @Published var currentRequest: GenerationRequest?

    // MARK: - Model State
    @Published var selectedModel: ModelType = .acestep
    @Published var modelDownloadStates: [ModelType: ModelDownloadState] = [
        .acestep: .notDownloaded
    ]

    // MARK: - Library State
    @Published var tracks: [Track] = []
    @Published var selectedTrack: Track?
    @Published var lastGeneratedTrack: Track?
    @Published var searchQuery = ""
    @Published var prefillRequest: GenerationRequest?

    // MARK: - Services
    private var generationTask: Task<Void, Never>?
    private(set) var pythonBackend = PythonBackendService()
    let audioPlayer = AudioPlayer()
    let licenseService = LicenseService.shared

    // MARK: - Track Persistence

    private static let tracksDirectoryURL: URL = {
        let appSupport = FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask).first!
        return appSupport.appendingPathComponent("LoopMaker/tracks")
    }()

    private static var tracksMetadataURL: URL {
        tracksDirectoryURL.appendingPathComponent("tracks.json")
    }

    // MARK: - Backend Status
    @Published var backendConnected = false
    @Published var backendError: String?

    // MARK: - License

    /// Whether the current user has a Pro license
    var isProUser: Bool { licenseService.licenseState.isPro }

    // MARK: - Initialization

    public init() {
        // Register as shared instance for app-level access
        registerAsShared()

        // Restore persisted tracks from disk
        restoreTracksFromDisk()

        // Restore persisted model download states before backend check
        restoreModelDownloadStates()

        // Start backend automatically on launch
        Task {
            await startBackendAndSetup()
        }
    }

    /// Start backend process and show setup if needed
    private func startBackendAndSetup() async {
        // Show setup view for first-launch or if not already running
        await backendManager.ensureBackendRunning()

        switch backendManager.state {
        case .running:
            // Recreate PythonBackendService with the port the manager chose
            reconnectBackendService()
            backendConnected = true
            await checkModelStatus()

        case .pythonMissing, .error:
            // Show setup view for errors
            showSetup = true
            backendConnected = false
            backendError = backendManager.state.userMessage

        default:
            // Still setting up - this shouldn't happen as ensureBackendRunning awaits
            break
        }
    }

    /// Recreate PythonBackendService pointing at the manager's current port.
    private func reconnectBackendService() {
        let url = URL(string: "http://127.0.0.1:\(backendManager.port)")!
        pythonBackend = PythonBackendService(baseURL: url)
    }

    /// Check model download status from backend.
    /// Merges with persisted state: backend confirmation of "downloaded" always wins,
    /// but backend "not downloaded" only downgrades if we didn't have a persisted state.
    private func checkModelStatus() async {
        do {
            let status = try await pythonBackend.getModelStatus()
            for (model, isDownloaded) in status {
                if isDownloaded {
                    // Backend confirms downloaded - always trust this
                    modelDownloadStates[model] = .downloaded
                } else {
                    // Backend says not downloaded - only downgrade if we don't
                    // already have a persisted .downloaded state. The backend may
                    // not recognize models cached in HuggingFace/transformers paths.
                    let current = modelDownloadStates[model] ?? .notDownloaded
                    if !current.isDownloaded {
                        modelDownloadStates[model] = .notDownloaded
                    }
                }
            }
            persistModelDownloadStates()
            backendError = nil
        } catch {
            // Network error fetching status - keep persisted states, don't wipe them
            Log.app.warning("Could not fetch model status from backend: \(error.localizedDescription)")
        }
    }

    /// Retry backend setup after an error
    func retryBackendSetup() async {
        showSetup = true
        await backendManager.retrySetup()

        if case .running = backendManager.state {
            showSetup = false
            reconnectBackendService()
            backendConnected = true
            await checkModelStatus()
        }
    }

    /// Restart the backend process (no venv rebuild) and reconnect the service.
    func restartBackend() async {
        backendConnected = false
        backendError = nil
        await backendManager.restartBackend()

        if case .running = backendManager.state {
            reconnectBackendService()
            backendConnected = true
            await checkModelStatus()
        } else {
            backendError = backendManager.state.userMessage
        }
    }

    /// Wipe the venv and re-run full setup from scratch.
    func cleanInstallBackend() async {
        backendConnected = false
        backendError = nil
        await backendManager.cleanInstall()

        if case .running = backendManager.state {
            reconnectBackendService()
            backendConnected = true
            await checkModelStatus()
        } else {
            backendError = backendManager.state.userMessage
        }
    }

    // MARK: - Computed Properties

    var filteredTracks: [Track] {
        if searchQuery.isEmpty {
            return tracks
        }
        return tracks.filter {
            $0.prompt.localizedCaseInsensitiveContains(searchQuery) ||
            ($0.title?.localizedCaseInsensitiveContains(searchQuery) ?? false)
        }
    }

    var canGenerate: Bool {
        guard backendConnected else { return false }
        guard let state = modelDownloadStates[selectedModel] else { return false }
        return state.isDownloaded && !isGenerating
    }

    /// Check if a model is accessible (either free or user is Pro)
    func isModelAccessible(_ model: ModelType) -> Bool {
        !model.requiresPro || isProUser
    }

    // MARK: - Actions

    func startGeneration(request: GenerationRequest) {
        guard canGenerate else { return }

        isGenerating = true
        generationProgress = 0
        generationStatus = "Starting generation..."
        currentRequest = request

        generationTask = Task {
            do {
                let generatedTracks = try await pythonBackend.generate(request: request) { progress, status in
                    Task { @MainActor in
                        self.generationProgress = progress
                        self.generationStatus = status
                    }
                }

                generationProgress = 1
                // Insert all variations (most recent first)
                for track in generatedTracks.reversed() {
                    tracks.insert(track, at: 0)
                }
                if let first = generatedTracks.first {
                    selectedTrack = first
                    lastGeneratedTrack = first
                    playTrack(first)
                }
                persistTracksToDisk()
                let count = generatedTracks.count
                generationStatus = count > 1 ? "Complete! \(count) variations generated" : "Complete!"
            } catch {
                generationStatus = "Error: \(error.localizedDescription)"
            }

            isGenerating = false
            currentRequest = nil
        }
    }

    func cancelGeneration() {
        generationTask?.cancel()
        generationTask = nil
        isGenerating = false
        generationProgress = 0
        generationStatus = "Cancelled"
        currentRequest = nil
    }

    func downloadModel(_ model: ModelType) {
        modelDownloadStates[model] = .downloading(progress: 0)

        Task {
            do {
                try await pythonBackend.downloadModel(model) { progress in
                    Task { @MainActor in
                        self.modelDownloadStates[model] = .downloading(progress: progress)
                    }
                }
                modelDownloadStates[model] = .downloaded
                persistModelDownloadStates()
            } catch {
                modelDownloadStates[model] = .error(error.localizedDescription)
            }
        }
    }

    func deleteTrack(_ track: Track) {
        if audioPlayer.isCurrentTrack(track.audioURL) {
            stopPlayback()
        }
        tracks.removeAll { $0.id == track.id }
        if selectedTrack?.id == track.id {
            selectedTrack = nil
        }
        if lastGeneratedTrack?.id == track.id {
            lastGeneratedTrack = nil
        }
        // Clean up audio file
        try? FileManager.default.removeItem(at: track.audioURL)
        persistTracksToDisk()
    }

    func deleteMultipleTracks(_ ids: Set<UUID>) {
        for id in ids {
            if let track = tracks.first(where: { $0.id == id }) {
                if audioPlayer.isCurrentTrack(track.audioURL) {
                    stopPlayback()
                }
                try? FileManager.default.removeItem(at: track.audioURL)
            }
        }
        tracks.removeAll { ids.contains($0.id) }
        if let selected = selectedTrack, ids.contains(selected.id) {
            selectedTrack = nil
        }
        if let last = lastGeneratedTrack, ids.contains(last.id) {
            lastGeneratedTrack = nil
        }
        persistTracksToDisk()
    }

    func clearAllTracks() {
        stopPlayback()
        for track in tracks {
            try? FileManager.default.removeItem(at: track.audioURL)
        }
        tracks.removeAll()
        selectedTrack = nil
        lastGeneratedTrack = nil
        persistTracksToDisk()
    }

    func renameTrack(_ track: Track, newTitle: String) {
        if let index = tracks.firstIndex(where: { $0.id == track.id }) {
            tracks[index].title = newTitle.isEmpty ? nil : newTitle

            let updatedTrack = tracks[index]
            if selectedTrack?.id == updatedTrack.id {
                selectedTrack = updatedTrack
            }
            if lastGeneratedTrack?.id == updatedTrack.id {
                lastGeneratedTrack = updatedTrack
            }
            persistTracksToDisk()
        }
    }

    func toggleFavorite(_ track: Track) {
        if let index = tracks.firstIndex(where: { $0.id == track.id }) {
            tracks[index].isFavorite.toggle()

            let updatedTrack = tracks[index]

            if selectedTrack?.id == updatedTrack.id {
                selectedTrack = updatedTrack
            }

            if lastGeneratedTrack?.id == updatedTrack.id {
                lastGeneratedTrack = updatedTrack
            }

            persistTracksToDisk()
        }
    }

    // MARK: - Playback Controls

    var canPlayPrevious: Bool {
        guard let current = selectedTrack ?? lastGeneratedTrack else { return false }
        guard let index = tracks.firstIndex(where: { $0.id == current.id }) else { return false }
        return index < tracks.count - 1
    }

    var canPlayNext: Bool {
        guard let current = selectedTrack ?? lastGeneratedTrack else { return false }
        guard let index = tracks.firstIndex(where: { $0.id == current.id }) else { return false }
        return index > 0
    }

    func playPreviousTrack() {
        guard let current = selectedTrack ?? lastGeneratedTrack,
              let index = tracks.firstIndex(where: { $0.id == current.id }),
              index < tracks.count - 1 else { return }
        playTrack(tracks[index + 1])
    }

    func playNextTrack() {
        guard let current = selectedTrack ?? lastGeneratedTrack,
              let index = tracks.firstIndex(where: { $0.id == current.id }),
              index > 0 else { return }
        playTrack(tracks[index - 1])
    }

    func playTrack(_ track: Track) {
        selectedTrack = track
        lastGeneratedTrack = track
        audioPlayer.play(url: track.audioURL)
    }

    func togglePlayPause() {
        let activeTrack = selectedTrack ?? lastGeneratedTrack
        guard let track = activeTrack else { return }
        if audioPlayer.isPlaying {
            audioPlayer.pause()
        } else {
            audioPlayer.play(url: track.audioURL)
        }
    }

    func stopPlayback() {
        audioPlayer.stop()
    }

    func seekPlayback(to position: Double) {
        audioPlayer.seek(to: position)
    }

    func setVolume(_ volume: Float) {
        audioPlayer.setVolume(volume)
    }

    func cycleRepeatMode() {
        audioPlayer.cycleRepeatMode()
    }

    // MARK: - Model State Persistence

    private static let modelStatesKey = "com.loopmaker.modelDownloadStates"

    private func persistModelDownloadStates() {
        var dict: [String: Bool] = [:]
        for (model, state) in modelDownloadStates {
            if case .downloaded = state {
                dict[model.rawValue] = true
            }
        }
        UserDefaults.standard.set(dict, forKey: Self.modelStatesKey)
    }

    private func restoreModelDownloadStates() {
        guard let dict = UserDefaults.standard.dictionary(forKey: Self.modelStatesKey) as? [String: Bool] else {
            return
        }
        for (key, isDownloaded) in dict where isDownloaded {
            if let model = ModelType(rawValue: key) {
                modelDownloadStates[model] = .downloaded
            }
        }
    }

    // MARK: - Track Persistence

    private func persistTracksToDisk() {
        do {
            let data = try JSONEncoder().encode(tracks)
            try data.write(to: Self.tracksMetadataURL, options: .atomic)
        } catch {
            Log.data.error("Failed to persist tracks: \(error.localizedDescription)")
        }
    }

    private func restoreTracksFromDisk() {
        let url = Self.tracksMetadataURL
        guard FileManager.default.fileExists(atPath: url.path) else { return }

        do {
            let data = try Data(contentsOf: url)
            let restored = try JSONDecoder().decode([Track].self, from: data)
            // Only keep tracks whose audio files still exist on disk
            tracks = restored.filter { FileManager.default.fileExists(atPath: $0.audioURL.path) }
        } catch {
            Log.data.error("Failed to restore tracks: \(error.localizedDescription)")
        }
    }
}

// MARK: - Sidebar Items

enum SidebarItem: String, CaseIterable, Identifiable {
    case generate = "Generate"
    case library = "Library"
    case favorites = "Favorites"
    case settings = "Settings"

    var id: String { rawValue }

    var icon: String {
        switch self {
        case .generate: return "waveform"
        case .library: return "music.note.list"
        case .favorites: return "heart.fill"
        case .settings: return "gear"
        }
    }
}
