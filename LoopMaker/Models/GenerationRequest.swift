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

public enum VocalLanguageHint: String, Codable, Sendable, CaseIterable {
    case english
    case hindi
    case spanish
    case korean
    case multilingual

    public var displayName: String {
        switch self {
        case .english: return "English"
        case .hindi: return "Hindi"
        case .spanish: return "Spanish"
        case .korean: return "Korean"
        case .multilingual: return "Multilingual"
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
        let trimmedPrompt = prompt.trimmingCharacters(in: .whitespacesAndNewlines)
        guard let languageHint else { return trimmedPrompt }

        let loweredPrompt = trimmedPrompt.lowercased()
        if loweredPrompt.contains("vocal language:") || loweredPrompt.contains("lyrics language:") {
            return trimmedPrompt
        }

        let directive = "Vocal language: \(languageHint.displayName). Keep all sung lyrics in \(languageHint.displayName) only."
        return "\(directive) \(trimmedPrompt)"
    }

    /// Effective lyrics (returns [inst] for instrumental)
    public var effectiveLyrics: String {
        lyrics ?? "[inst]"
    }

    /// Detect intended vocal language from lyrics first, then prompt keywords.
    public var languageHint: VocalLanguageHint? {
        guard shouldInferVocalLanguage else { return nil }

        if let lyricsText = normalizedLyricsForDetection,
           let hint = Self.detectLanguage(from: lyricsText) {
            return hint
        }

        let trimmedPrompt = prompt.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmedPrompt.isEmpty else { return nil }
        return Self.detectLanguage(from: trimmedPrompt)
    }

    private var shouldInferVocalLanguage: Bool {
        guard let rawLyrics = lyrics?.trimmingCharacters(in: .whitespacesAndNewlines) else {
            return false
        }

        // Cover mode uses empty string to preserve source vocals.
        if taskType == .cover && rawLyrics.isEmpty {
            return false
        }

        return !rawLyrics.isEmpty && rawLyrics != "[inst]"
    }

    private var normalizedLyricsForDetection: String? {
        guard let rawLyrics = lyrics?.trimmingCharacters(in: .whitespacesAndNewlines),
              !rawLyrics.isEmpty,
              rawLyrics != "[inst]" else {
            return nil
        }
        return rawLyrics
    }

    private static func detectLanguage(from text: String) -> VocalLanguageHint? {
        if let scriptHint = detectLanguageFromScript(text) {
            return scriptHint
        }
        return detectLanguageFromKeywords(text)
    }

    private static func detectLanguageFromScript(_ text: String) -> VocalLanguageHint? {
        var hasDevanagari = false
        var hasHangul = false
        var hasSpanishMarkers = false

        for scalar in text.unicodeScalars {
            let value = scalar.value

            if (0x0900 ... 0x097F).contains(value) {
                hasDevanagari = true
            }

            if (0xAC00 ... 0xD7AF).contains(value)
                || (0x1100 ... 0x11FF).contains(value)
                || (0x3130 ... 0x318F).contains(value) {
                hasHangul = true
            }

            if spanishMarkerScalarValues.contains(value) {
                hasSpanishMarkers = true
            }
        }

        if hasDevanagari {
            return .hindi
        }
        if hasHangul {
            return .korean
        }
        if hasSpanishMarkers {
            return .spanish
        }
        return nil
    }

    private static func detectLanguageFromKeywords(_ text: String) -> VocalLanguageHint? {
        let lowered = text.lowercased()
        var matches: Set<VocalLanguageHint> = []

        for (hint, keywords) in languageKeywordBuckets {
            if keywords.contains(where: { lowered.contains($0) }) {
                matches.insert(hint)
            }
        }

        if matches.contains(.multilingual) {
            return .multilingual
        }
        if matches.count > 1 {
            return .multilingual
        }
        return matches.first
    }

    private static let languageKeywordBuckets: [(VocalLanguageHint, [String])] = [
        (
            .multilingual,
            [
                "multilingual", "bilingual", "mixed language", "code-switch",
                "hindi and english", "english and hindi",
                "spanish and english", "english and spanish",
                "mix hindi", "mix spanish",
            ]
        ),
        (
            .hindi,
            [
                "hindi", "bollywood", "desi", "punjabi", "urdu", "hindustani",
                "dhol", "tabla", "qawwali", "ghazal",
                "baarish", "saansein", "raaste", "gaayen", "dil", "tera",
            ]
        ),
        (
            .spanish,
            [
                "spanish", "espanol", "latin pop", "latin", "reggaeton", "dembow",
                "salsa", "bachata", "corridos", "en espanol",
            ]
        ),
        (
            .korean,
            [
                "korean", "k-pop", "kpop", "hangul",
            ]
        ),
        (
            .english,
            [
                "english",
            ]
        ),
    ]

    private static let spanishMarkerScalarValues: Set<UInt32> = [
        0x00C1, 0x00C9, 0x00CD, 0x00D1, 0x00D3, 0x00DA, 0x00DC,
        0x00E1, 0x00E9, 0x00ED, 0x00F1, 0x00F3, 0x00FA, 0x00FC,
        0x00BF, 0x00A1,
    ]
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
