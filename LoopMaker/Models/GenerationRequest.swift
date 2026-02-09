import Foundation

/// Quality mode for ACE-Step v1.5 generation
public enum QualityMode: String, CaseIterable, Codable, Sendable {
    case draft    // 4 inference steps - quick preview
    case fast     // 8 inference steps - turbo (default, recommended)
    case quality  // 50 inference steps - highest quality

    public var displayName: String {
        switch self {
        case .draft: return "Draft"
        case .fast: return "Turbo"
        case .quality: return "Quality"
        }
    }

    public var inferenceSteps: Int {
        switch self {
        case .draft: return 4
        case .fast: return 8
        case .quality: return 50
        }
    }
}

/// Request parameters for music generation
public struct GenerationRequest: Sendable {
    public let prompt: String
    public let duration: TrackDuration
    public let model: ModelType
    public let genre: GenrePreset?
    public let seed: UInt64?
    public let lyrics: String?
    public let qualityMode: QualityMode
    public let guidanceScale: Double

    public init(
        prompt: String,
        duration: TrackDuration,
        model: ModelType = .acestep,
        genre: GenrePreset? = nil,
        seed: UInt64? = nil,
        lyrics: String? = nil,
        qualityMode: QualityMode = .fast,
        guidanceScale: Double = 7.0  // v1.5 default (was 15.0 in v1)
    ) {
        self.prompt = prompt
        self.duration = duration
        self.model = model
        self.genre = genre
        self.seed = seed
        self.lyrics = lyrics
        self.qualityMode = qualityMode
        self.guidanceScale = guidanceScale
    }

    /// Full prompt (genre text is now included directly in the prompt field)
    public var fullPrompt: String {
        return prompt
    }

    /// Effective lyrics (returns [inst] for instrumental)
    public var effectiveLyrics: String {
        lyrics ?? "[inst]"
    }
}
