import Foundation

/// Model family categorization
public enum ModelFamily: String, Codable, Sendable {
    case musicgen
    case acestep
}

/// AI model variants for music generation
public enum ModelType: String, CaseIterable, Codable, Sendable {
    case small
    case medium
    case acestep

    /// Model family
    public var family: ModelFamily {
        switch self {
        case .small, .medium: return .musicgen
        case .acestep: return .acestep
        }
    }

    /// Model size in GB
    public var sizeGB: Double {
        switch self {
        case .small: return 1.2
        case .medium: return 6.0
        case .acestep: return 5.0  // v1.5: ~4GB DiT + ~1GB LM (0.6B)
        }
    }

    /// Formatted size string
    public var sizeFormatted: String {
        String(format: "%.1f GB", sizeGB)
    }

    /// Minimum RAM required in GB
    public var minimumRAM: Int {
        switch self {
        case .small: return 8
        case .medium: return 16
        case .acestep: return 8  // v1.5 turbo: DiT ~4GB + 0.6B LM ~1.2GB (float32 ~10GB)
        }
    }

    /// Recommended RAM in GB
    public var recommendedRAM: Int {
        switch self {
        case .small: return 16
        case .medium: return 32
        case .acestep: return 16  // v1.5: comfortable with CPU offload on 16GB
        }
    }

    /// Maximum duration this model supports in seconds.
    /// MusicGen uses chunked continuation with crossfade for durations > 30s.
    public var maxDurationSeconds: Int {
        switch self {
        case .small, .medium: return 60
        case .acestep: return 240
        }
    }

    /// Whether this model supports lyrics/vocals
    public var supportsLyrics: Bool {
        family == .acestep
    }

    /// Human-readable display name
    public var displayName: String {
        switch self {
        case .small: return "Small (Fast)"
        case .medium: return "Medium"
        case .acestep: return "ACE-Step"
        }
    }

    /// Description for UI
    public var modelDescription: String {
        switch self {
        case .small: return "300M params, fast generation"
        case .medium: return "1.5B params, better quality"
        case .acestep: return "2B+0.6B params, lyrics & vocals, up to 4min"
        }
    }

    /// Parameter count
    public var parameters: String {
        switch self {
        case .small: return "300M"
        case .medium: return "1.5B"
        case .acestep: return "2.6B"  // v1.5: 2B DiT + 0.6B LM
        }
    }

    /// Icon for model family
    public var familyIcon: String {
        switch family {
        case .musicgen: return "waveform"
        case .acestep: return "music.mic"
        }
    }

    /// Whether this model requires a Pro license
    public var requiresPro: Bool {
        // TODO: Re-enable Pro gating before release
        return false
    }
}
