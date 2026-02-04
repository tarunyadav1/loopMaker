import Foundation

/// A generated music track
public struct Track: Identifiable, Codable, Sendable, Hashable {
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

    public init(
        id: UUID = UUID(),
        prompt: String,
        duration: TrackDuration,
        model: ModelType,
        audioURL: URL,
        createdAt: Date = Date(),
        title: String? = nil,
        isFavorite: Bool = false
    ) {
        self.id = id
        self.prompt = prompt
        self.duration = duration
        self.model = model
        self.audioURL = audioURL
        self.createdAt = createdAt
        self.title = title
        self.isFavorite = isFavorite
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
        let formatter = DateFormatter()
        formatter.dateStyle = .medium
        formatter.timeStyle = .short
        return formatter.string(from: createdAt)
    }
}
