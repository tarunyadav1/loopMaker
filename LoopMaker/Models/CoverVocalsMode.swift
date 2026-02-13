import Foundation

/// Vocals handling mode for cover generation
public enum CoverVocalsMode: String, CaseIterable, Codable, Sendable {
    case keep
    case instrumental
    case newLyrics

    public var displayName: String {
        switch self {
        case .keep: return "Keep Vocals"
        case .instrumental: return "Instrumental"
        case .newLyrics: return "New Lyrics"
        }
    }

    public var icon: String {
        switch self {
        case .keep: return "mic.fill"
        case .instrumental: return "pianokeys"
        case .newLyrics: return "music.mic"
        }
    }
}

/// Task type for generation
public enum GenerationTaskType: String, CaseIterable, Codable, Sendable {
    case text2music
    case cover
    case extend

    public var displayName: String {
        switch self {
        case .text2music: return "Generate"
        case .cover: return "Cover"
        case .extend: return "Extend"
        }
    }

    public var icon: String {
        switch self {
        case .text2music: return "waveform"
        case .cover: return "arrow.triangle.2.circlepath.circle"
        case .extend: return "arrow.forward.to.line"
        }
    }

    /// The task type string sent to the backend (differs from rawValue for extend)
    public var backendTaskType: String {
        switch self {
        case .text2music: return "text2music"
        case .cover: return "cover"
        case .extend: return "repaint"
        }
    }
}

/// Amount of time to extend a track by
public enum ExtensionAmount: String, CaseIterable, Sendable {
    case ten
    case thirty
    case sixty
    case onetwenty

    public var displayName: String {
        switch self {
        case .ten: return "+10s"
        case .thirty: return "+30s"
        case .sixty: return "+1m"
        case .onetwenty: return "+2m"
        }
    }

    public var seconds: Int {
        switch self {
        case .ten: return 10
        case .thirty: return 30
        case .sixty: return 60
        case .onetwenty: return 120
        }
    }
}
