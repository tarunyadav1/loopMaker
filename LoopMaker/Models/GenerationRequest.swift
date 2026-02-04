import Foundation

/// Request parameters for music generation
public struct GenerationRequest: Sendable {
    public let prompt: String
    public let duration: TrackDuration
    public let model: ModelType
    public let genre: GenrePreset?
    public let seed: UInt64?

    public init(
        prompt: String,
        duration: TrackDuration,
        model: ModelType,
        genre: GenrePreset? = nil,
        seed: UInt64? = nil
    ) {
        self.prompt = prompt
        self.duration = duration
        self.model = model
        self.genre = genre
        self.seed = seed
    }

    /// Full prompt including genre suffix if selected
    public var fullPrompt: String {
        if let genre = genre {
            return "\(prompt), \(genre.promptSuffix)"
        }
        return prompt
    }
}
