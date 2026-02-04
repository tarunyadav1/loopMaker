import Foundation

/// MusicGen model variants
public enum ModelType: String, CaseIterable, Codable, Sendable {
    case small
    case medium

    /// Model size in GB
    public var sizeGB: Double {
        switch self {
        case .small: return 1.2
        case .medium: return 6.0
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
        }
    }

    /// Recommended RAM in GB
    public var recommendedRAM: Int {
        switch self {
        case .small: return 16
        case .medium: return 32
        }
    }

    /// Human-readable display name
    public var displayName: String {
        switch self {
        case .small: return "Small (Fast)"
        case .medium: return "Medium (Quality)"
        }
    }

    /// Description for UI
    public var description: String {
        switch self {
        case .small: return "300M parameters, ~90s generation"
        case .medium: return "1.5B parameters, ~4min generation"
        }
    }

    /// Parameter count
    public var parameters: String {
        switch self {
        case .small: return "300M"
        case .medium: return "1.5B"
        }
    }
}
