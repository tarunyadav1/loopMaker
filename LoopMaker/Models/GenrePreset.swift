import Foundation

/// Genre presets with prompt suffixes
public struct GenrePreset: Identifiable, Codable, Sendable, Hashable {
    public let id: String
    public let name: String
    public let icon: String
    public let promptSuffix: String
    public let color: String

    public init(id: String, name: String, icon: String, promptSuffix: String, color: String) {
        self.id = id
        self.name = name
        self.icon = icon
        self.promptSuffix = promptSuffix
        self.color = color
    }

    /// All available genre presets (must match GenreCardData names)
    public static let allPresets: [GenrePreset] = [
        GenrePreset(
            id: "lofi",
            name: "Lo-Fi",
            icon: "headphones",
            promptSuffix: "lo-fi hip hop, vinyl crackle, mellow beats, jazzy chords, relaxing",
            color: "purple"
        ),
        GenrePreset(
            id: "cinematic",
            name: "Cinematic",
            icon: "film",
            promptSuffix: "cinematic orchestral, epic, dramatic, film score, Hans Zimmer style",
            color: "orange"
        ),
        GenrePreset(
            id: "ambient",
            name: "Ambient",
            icon: "cloud",
            promptSuffix: "ambient, atmospheric, ethereal pads, dreamy, Brian Eno style",
            color: "blue"
        ),
        GenrePreset(
            id: "electronic",
            name: "Electronic",
            icon: "bolt",
            promptSuffix: "electronic, synth, modern beats, EDM influenced, energetic",
            color: "pink"
        ),
        GenrePreset(
            id: "hiphop",
            name: "Hip-Hop",
            icon: "beats.headphones",
            promptSuffix: "hip hop beats, 808 bass, trap hi-hats, boom bap, rhythmic",
            color: "red"
        ),
        GenrePreset(
            id: "jazz",
            name: "Jazz",
            icon: "music.quarternote.3",
            promptSuffix: "jazz, smooth saxophone, brushed drums, upright bass, swing feel",
            color: "green"
        )
    ]
}
