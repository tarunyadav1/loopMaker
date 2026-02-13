import Foundation

/// AI model for music generation
public enum ModelType: String, CaseIterable, Codable, Sendable {
    case acestep

    /// Model size in GB
    public var sizeGB: Double {
        5.0  // v1.5: ~4GB DiT + ~1GB LM (0.6B)
    }

    /// Formatted size string
    public var sizeFormatted: String {
        String(format: "%.1f GB", sizeGB)
    }

    /// Minimum RAM required in GB
    public var minimumRAM: Int {
        8  // v1.5 turbo: DiT ~4GB + 0.6B LM ~1.2GB (float32 ~10GB)
    }

    /// Recommended RAM in GB
    public var recommendedRAM: Int {
        16  // v1.5: comfortable with CPU offload on 16GB
    }

    /// Maximum duration this model supports in seconds.
    public var maxDurationSeconds: Int {
        240
    }

    /// Whether this model supports lyrics/vocals
    public var supportsLyrics: Bool {
        true
    }

    /// Human-readable display name
    public var displayName: String {
        "LoopMaker AI"
    }

    /// Description for UI
    public var modelDescription: String {
        "Lyrics & vocals, up to 4min"
    }

    /// Parameter count
    public var parameters: String {
        ""
    }

    /// Icon for model
    public var familyIcon: String {
        "music.mic"
    }

    /// Whether this model requires a Pro license
    public var requiresPro: Bool {
        false
    }
}
