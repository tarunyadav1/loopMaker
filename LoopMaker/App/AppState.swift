import SwiftUI
import Combine

/// Global application state
@MainActor
public final class AppState: ObservableObject {
    // MARK: - Navigation State
    @Published var selectedSidebarItem: SidebarItem = .generate
    @Published var showNewGeneration = false
    @Published var showSettings = false
    @Published var showExport = false

    // MARK: - Generation State
    @Published var isGenerating = false
    @Published var generationProgress: Double = 0
    @Published var generationStatus: String = ""
    @Published var currentRequest: GenerationRequest?

    // MARK: - Model State
    @Published var selectedModel: ModelType = .small
    @Published var modelDownloadStates: [ModelType: ModelDownloadState] = [
        .small: .notDownloaded,
        .medium: .notDownloaded
    ]

    // MARK: - Library State
    @Published var tracks: [Track] = []
    @Published var selectedTrack: Track?
    @Published var searchQuery = ""

    // MARK: - Playback State
    @Published var isPlaying = false
    @Published var playbackProgress: Double = 0

    // MARK: - Services
    private var generationTask: Task<Void, Never>?
    private let pythonBackend = PythonBackendService()

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
        guard let state = modelDownloadStates[selectedModel] else { return false }
        return state.isDownloaded && !isGenerating
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
                let track = try await pythonBackend.generate(request: request) { progress, status in
                    Task { @MainActor in
                        self.generationProgress = progress
                        self.generationStatus = status
                    }
                }

                tracks.insert(track, at: 0)
                selectedTrack = track
                generationStatus = "Complete!"
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
            } catch {
                modelDownloadStates[model] = .error(error.localizedDescription)
            }
        }
    }

    func deleteTrack(_ track: Track) {
        tracks.removeAll { $0.id == track.id }
        if selectedTrack?.id == track.id {
            selectedTrack = nil
        }
        // Clean up audio file
        try? FileManager.default.removeItem(at: track.audioURL)
    }

    func toggleFavorite(_ track: Track) {
        if let index = tracks.firstIndex(where: { $0.id == track.id }) {
            tracks[index].isFavorite.toggle()
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
