import Foundation

/// Duration options for generated tracks
public enum TrackDuration: String, CaseIterable, Codable, Sendable {
    case short
    case medium
    case long

    /// Duration in seconds
    public var seconds: Int {
        switch self {
        case .short: return 10
        case .medium: return 30
        case .long: return 60
        }
    }

    /// Human-readable display name
    public var displayName: String {
        "\(seconds) sec"
    }

    /// Icon for UI
    public var icon: String {
        switch self {
        case .short: return "hare"
        case .medium: return "timer"
        case .long: return "tortoise"
        }
    }
}
