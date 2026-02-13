import Foundation

/// Quality mode for music generation
public enum QualityMode: String, CaseIterable, Codable, Sendable {
    case draft
    case fast
    case quality

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
public struct GenerationRequest: Sendable, Equatable {
    public static func == (lhs: GenerationRequest, rhs: GenerationRequest) -> Bool {
        lhs.prompt == rhs.prompt &&
        lhs.duration == rhs.duration &&
        lhs.model == rhs.model &&
        lhs.genre == rhs.genre &&
        lhs.seed == rhs.seed &&
        lhs.lyrics == rhs.lyrics &&
        lhs.qualityMode == rhs.qualityMode &&
        lhs.guidanceScale == rhs.guidanceScale &&
        lhs.taskType == rhs.taskType &&
        lhs.sourceAudioURL == rhs.sourceAudioURL &&
        lhs.refAudioStrength == rhs.refAudioStrength &&
        lhs.repaintingStart == rhs.repaintingStart &&
        lhs.repaintingEnd == rhs.repaintingEnd &&
        lhs.sourceTrack == rhs.sourceTrack &&
        lhs.batchSize == rhs.batchSize &&
        lhs.bpm == rhs.bpm &&
        lhs.musicKey == rhs.musicKey &&
        lhs.timeSignature == rhs.timeSignature
    }

    public let prompt: String
    public let duration: TrackDuration
    public let model: ModelType
    public let genre: GenrePreset?
    public let seed: UInt64?
    public let lyrics: String?
    public let qualityMode: QualityMode
    public let guidanceScale: Double
    public let taskType: GenerationTaskType
    public let sourceAudioURL: URL?
    public let refAudioStrength: Double
    public let repaintingStart: Double?
    public let repaintingEnd: Double?
    public let sourceTrack: Track?
    public let batchSize: Int
    public let bpm: Int?
    public let musicKey: String?
    public let timeSignature: String?

    public init(
        prompt: String,
        duration: TrackDuration,
        model: ModelType = .acestep,
        genre: GenrePreset? = nil,
        seed: UInt64? = nil,
        lyrics: String? = nil,
        qualityMode: QualityMode = .fast,
        guidanceScale: Double = 7.0,
        taskType: GenerationTaskType = .text2music,
        sourceAudioURL: URL? = nil,
        refAudioStrength: Double = 0.5,
        repaintingStart: Double? = nil,
        repaintingEnd: Double? = nil,
        sourceTrack: Track? = nil,
        batchSize: Int = 1,
        bpm: Int? = nil,
        musicKey: String? = nil,
        timeSignature: String? = nil
    ) {
        self.prompt = prompt
        self.duration = duration
        self.model = model
        self.genre = genre
        self.seed = seed
        self.lyrics = lyrics
        self.qualityMode = qualityMode
        self.guidanceScale = guidanceScale
        self.taskType = taskType
        self.sourceAudioURL = sourceAudioURL
        self.refAudioStrength = refAudioStrength
        self.repaintingStart = repaintingStart
        self.repaintingEnd = repaintingEnd
        self.sourceTrack = sourceTrack
        self.batchSize = batchSize
        self.bpm = bpm
        self.musicKey = musicKey
        self.timeSignature = timeSignature
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

// MARK: - Music Metadata Options

/// Available musical keys for generation
public enum MusicKey {
    static let allKeys: [String] = [
        "C major", "C minor",
        "C# major", "C# minor",
        "D major", "D minor",
        "Eb major", "Eb minor",
        "E major", "E minor",
        "F major", "F minor",
        "F# major", "F# minor",
        "G major", "G minor",
        "Ab major", "Ab minor",
        "A major", "A minor",
        "Bb major", "Bb minor",
        "B major", "B minor",
    ]
}

/// Available time signatures for generation
public enum MusicTimeSignature {
    static let all: [String] = ["2/4", "3/4", "4/4", "5/4", "6/8", "7/8"]
}
