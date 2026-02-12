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

    public var displayName: String {
        switch self {
        case .text2music: return "Generate"
        case .cover: return "Cover"
        }
    }

    public var icon: String {
        switch self {
        case .text2music: return "waveform"
        case .cover: return "arrow.triangle.2.circlepath.circle"
        }
    }
}
