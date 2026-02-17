import SwiftUI
import Combine

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
    @Published var modelDownloadMessages: [ModelType: String] = [:]

    // MARK: - Library State
    @Published var tracks: [Track] = []
    @Published var selectedTrack: Track?
    @Published var lastGeneratedTrack: Track?
    @Published var searchQuery = ""
    @Published var prefillRequest: GenerationRequest?

    // MARK: - Services
    private var generationTask: Task<Void, Never>?
    private var activeGenerationID: UUID?
    private var cancellables = Set<AnyCancellable>()
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

        // Keep UI connection/error flags synchronized with backend lifecycle changes.
        bindBackendState()
        bindLicenseState()

        // Restore persisted tracks from disk
        restoreTracksFromDisk()

        // Restore persisted model download states before backend check
        restoreModelDownloadStates()
    }

    private func bindBackendState() {
        backendManager.$state
            .sink { [weak self] newState in
                self?.syncBackendStatus(for: newState)
            }
            .store(in: &cancellables)
    }

    private func bindLicenseState() {
        licenseService.$licenseState
            .sink { [weak self] newState in
                self?.handleLicenseStateChange(newState)
            }
            .store(in: &cancellables)
    }

    private func handleLicenseStateChange(_ state: LicenseState) {
        switch state {
        case .valid, .offlineGrace:
            Task { @MainActor [weak self] in
                guard let self else { return }
                await self.startBackendAndSetup()
            }

        case .unknown, .validating:
            break

        case .unlicensed, .invalid, .expired:
            backendConnected = false
            backendError = nil
            showSetup = false

            Task { @MainActor [weak self] in
                guard let self else { return }
                await self.backendManager.stopBackend()
                self.backendManager.state = .notStarted
            }
        }
    }

    private func syncBackendStatus(for state: BackendProcessManager.State) {
        switch state {
        case .running:
            backendConnected = true
            backendError = nil
            showSetup = false

        case .pythonMissing, .error:
            backendConnected = false
            backendError = UIRedaction.redactModelNames(in: state.userMessage)
            showSetup = true

        default:
            backendConnected = false
            backendError = nil
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
            backendError = UIRedaction.redactModelNames(in: backendManager.state.userMessage)

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
    private func checkModelStatus() async {
        do {
            let status = try await pythonBackend.getModelStatus()
            for (model, isDownloaded) in status {
                let current = modelDownloadStates[model] ?? .notDownloaded
                // Don't stomp on an in-flight download UI.
                if current.isDownloading { continue }
                modelDownloadStates[model] = isDownloaded ? .downloaded : .notDownloaded
                if isDownloaded {
                    modelDownloadMessages[model] = nil
                }
            }
            persistModelDownloadStates()
            backendError = nil
        } catch {
            // Network error fetching status - keep persisted states, don't wipe them
            Log.app.warning("Could not fetch model status from backend: \(error.localizedDescription)")
        }
    }

    // MARK: - Model Preparation

    /// Ensure the selected model is available locally, downloading if needed.
    /// Updates `modelDownloadStates` for UI and throws on failure.
    private func ensureModelReady(_ model: ModelType) async throws {
        if modelDownloadStates[model]?.isDownloading == true { return }

        // Quick truth check against backend (avoids re-downloading when local state is stale).
        let status = try await pythonBackend.getModelStatus()
        if status[model] == true {
            modelDownloadStates[model] = .downloaded
            modelDownloadMessages[model] = nil
            persistModelDownloadStates()
            return
        }

        modelDownloadStates[model] = .downloading(progress: 0)
        modelDownloadMessages[model] =
            "Downloading music engine files (\(model.sizeFormatted)). This happens once and may take a while."

        do {
            try await pythonBackend.downloadModel(model) { progress, message in
                Task { @MainActor in
                    self.modelDownloadStates[model] = .downloading(progress: progress)
                    if let message, !message.isEmpty {
                        self.modelDownloadMessages[model] = UIRedaction.redactModelNames(in: message)
                    }
                }
            }
            modelDownloadStates[model] = .downloaded
            modelDownloadMessages[model] = nil
            persistModelDownloadStates()
        } catch {
            // Show a user-facing error (detailed logs already exist in backend output).
            modelDownloadStates[model] = .error("Couldn't download the music model. Check your internet and try again.")
            // Keep the last message around for context if present.
            throw error
        }
    }

    /// Start generation, downloading required model files first if needed.
    func startGenerationEnsuringModel(request: GenerationRequest) {
        guard backendConnected else {
            backendError = "Music engine is offline."
            return
        }
        guard !isGenerating else { return }

        Task {
            do {
                try await ensureModelReady(request.model)
                startGeneration(request: request)
            } catch {
                Log.app.warning("Model preparation failed: \(error.localizedDescription)")
            }
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
            backendError = UIRedaction.redactModelNames(in: backendManager.state.userMessage)
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
            backendError = UIRedaction.redactModelNames(in: backendManager.state.userMessage)
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

    /// Check if a model is accessible for the current license state.
    func isModelAccessible(_ model: ModelType) -> Bool {
        !model.requiresPro || isProUser
    }

    // MARK: - Actions

    func startGeneration(request: GenerationRequest) {
        guard canGenerate else { return }

        let generationID = UUID()
        activeGenerationID = generationID
        isGenerating = true
        generationProgress = 0
        generationStatus = "Starting generation..."
        currentRequest = request

        generationTask = Task {
            defer {
                if self.activeGenerationID == generationID {
                    self.isGenerating = false
                    self.currentRequest = nil
                    self.generationTask = nil
                    self.activeGenerationID = nil
                }
            }

            do {
                let generatedTracks = try await pythonBackend.generate(request: request) { progress, status in
                    Task { @MainActor in
                        guard self.activeGenerationID == generationID else { return }
                        self.generationProgress = progress
                        self.generationStatus = UIRedaction.redactModelNames(in: status)
                    }
                }

                guard self.activeGenerationID == generationID else { return }
                guard !Task.isCancelled else {
                    generationStatus = "Cancelled"
                    return
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
            } catch is CancellationError {
                guard self.activeGenerationID == generationID else { return }
                generationStatus = "Cancelled"
            } catch {
                guard self.activeGenerationID == generationID else { return }
                if Task.isCancelled {
                    generationStatus = "Cancelled"
                } else {
                    let safeMessage = UIRedaction.redactModelNames(in: error.localizedDescription)
                    generationStatus = "Error: \(safeMessage)"
                }
            }
        }
    }

    func cancelGeneration() {
        let cancelledID = activeGenerationID
        generationTask?.cancel()
        generationTask = nil
        if activeGenerationID == cancelledID {
            activeGenerationID = nil
        }
        isGenerating = false
        generationProgress = 0
        generationStatus = "Cancelled"
        currentRequest = nil
    }

    func downloadModel(_ model: ModelType) {
        modelDownloadStates[model] = .downloading(progress: 0)

        Task {
            do {
                try await pythonBackend.downloadModel(model) { progress, message in
                    Task { @MainActor in
                        self.modelDownloadStates[model] = .downloading(progress: progress)
                        if let message, !message.isEmpty {
                            self.modelDownloadMessages[model] = UIRedaction.redactModelNames(in: message)
                        }
                    }
                }
                modelDownloadStates[model] = .downloaded
                modelDownloadMessages[model] = nil
                persistModelDownloadStates()
            } catch {
                modelDownloadStates[model] = .error("Couldn't download the music model. Check your internet and try again.")
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
