import Foundation

/// Quality mode for ACE-Step generation
public enum QualityMode: String, CaseIterable, Codable, Sendable {
    case fast     // 27 inference steps - faster generation
    case quality  // 60 inference steps - better quality

    public var displayName: String {
        switch self {
        case .fast: return "Fast"
        case .quality: return "Quality"
        }
    }

    public var inferenceSteps: Int {
        switch self {
        case .fast: return 27
        case .quality: return 60
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
    // ACE-Step specific
    public let lyrics: String?
    public let qualityMode: QualityMode
    public let guidanceScale: Double

    public init(
        prompt: String,
        duration: TrackDuration,
        model: ModelType,
        genre: GenrePreset? = nil,
        seed: UInt64? = nil,
        lyrics: String? = nil,
        qualityMode: QualityMode = .fast,
        guidanceScale: Double = 15.0
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

    /// Full prompt including genre suffix if selected
    public var fullPrompt: String {
        if let genre = genre {
            return "\(prompt), \(genre.promptSuffix)"
        }
        return prompt
    }

    /// Effective lyrics for ACE-Step (returns [inst] for instrumental)
    public var effectiveLyrics: String? {
        guard model.supportsLyrics else { return nil }
        return lyrics ?? "[inst]"
    }
}
