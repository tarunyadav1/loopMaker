import Foundation
import SwiftUI

/// A generated music track
public struct Track: Identifiable, Codable, Sendable, Hashable {
    private static let displayDateStyle = Date.FormatStyle(date: .abbreviated, time: .shortened)

    public static func == (lhs: Track, rhs: Track) -> Bool {
        lhs.id == rhs.id
    }

    public func hash(into hasher: inout Hasher) {
        hasher.combine(id)
    }

    public let id: UUID
    public let prompt: String
    public let duration: TrackDuration
    public let model: ModelType
    public let audioURL: URL
    public let createdAt: Date
    public var title: String?
    public var isFavorite: Bool
    public var lyrics: String?
    public var taskType: String?
    public var sourceAudioName: String?
    public var sourceTrackID: UUID?
    public var actualDurationSeconds: Double?

    // Generation metadata (optional, nil for older tracks)
    public var seed: UInt64?
    public var bpm: Int?
    public var musicKey: String?
    public var timeSignature: String?
    public var guidanceScale: Double?
    public var qualityMode: String?

    public init(
        id: UUID = UUID(),
        prompt: String,
        duration: TrackDuration,
        model: ModelType,
        audioURL: URL,
        createdAt: Date = Date(),
        title: String? = nil,
        isFavorite: Bool = false,
        lyrics: String? = nil,
        taskType: String? = nil,
        sourceAudioName: String? = nil,
        sourceTrackID: UUID? = nil,
        actualDurationSeconds: Double? = nil,
        seed: UInt64? = nil,
        bpm: Int? = nil,
        musicKey: String? = nil,
        timeSignature: String? = nil,
        guidanceScale: Double? = nil,
        qualityMode: String? = nil
    ) {
        self.id = id
        self.prompt = prompt
        self.duration = duration
        self.model = model
        self.audioURL = audioURL
        self.createdAt = createdAt
        self.title = title
        self.isFavorite = isFavorite
        self.lyrics = lyrics
        self.taskType = taskType
        self.sourceAudioName = sourceAudioName
        self.sourceTrackID = sourceTrackID
        self.actualDurationSeconds = actualDurationSeconds
        self.seed = seed
        self.bpm = bpm
        self.musicKey = musicKey
        self.timeSignature = timeSignature
        self.guidanceScale = guidanceScale
        self.qualityMode = qualityMode
    }

    /// Real audio duration in seconds (actual if available, otherwise enum value)
    public var durationSeconds: Double {
        actualDurationSeconds ?? Double(duration.seconds)
    }

    /// Whether this track was created via cover/style transfer
    public var isCover: Bool {
        taskType == "cover"
    }

    /// Whether this track was created via extend/repaint
    public var isExtended: Bool {
        taskType == "extend"
    }

    /// Display title - custom title or truncated prompt
    public var displayTitle: String {
        if let title = title, !title.isEmpty {
            return title
        }
        if prompt.count > 30 {
            return String(prompt.prefix(30)) + "..."
        }
        return prompt
    }

    /// Formatted creation date
    public var formattedDate: String {
        createdAt.formatted(Self.displayDateStyle)
    }

    /// Deterministic hue (0.0-1.0) derived from the prompt, for unique card colors
    public var promptHue: Double {
        var hash: UInt64 = 5381
        for byte in prompt.utf8 {
            hash = ((hash &<< 5) &+ hash) &+ UInt64(byte)
        }
        return Double(hash % 1000) / 1000.0
    }

    /// 12 curated gradient palettes matching the GenreCardData aesthetic
    private static let gradientPalettes: [(String, String)] = [
        ("1E1B4B", "4F46B5"), // Deep indigo
        ("4A0D29", "9D174D"), // Rich magenta
        ("042F2E", "0F766E"), // Deep teal
        ("451A03", "B45309"), // Warm amber
        ("052E16", "166534"), // Forest green
        ("450A0A", "991B1B"), // Deep red
        ("172554", "1D4ED8"), // Ocean blue
        ("3B0764", "7E22CE"), // Royal purple
        ("422006", "A16207"), // Warm gold
        ("1E3A5F", "3B82F6"), // Sky blue
        ("4C1D95", "8B5CF6"), // Violet
        ("064E3B", "059669"), // Emerald
    ]

    /// Curated gradient colors derived deterministically from the prompt
    public var gradientColors: (Color, Color) {
        var hash: UInt64 = 5381
        for byte in prompt.utf8 {
            hash = ((hash &<< 5) &+ hash) &+ UInt64(byte)
        }
        let index = Int(hash % UInt64(Self.gradientPalettes.count))
        let palette = Self.gradientPalettes[index]
        return (Color(hex: palette.0), Color(hex: palette.1))
    }

    /// Whether this track has lyrics
    public var hasLyrics: Bool {
        guard let lyrics = lyrics else { return false }
        return !lyrics.isEmpty && lyrics != "[inst]"
    }
}
