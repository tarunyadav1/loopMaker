import Foundation

/// Duration options for generated tracks
public enum TrackDuration: String, CaseIterable, Codable, Sendable {
    case short      // 10s
    case medium     // 30s
    case long       // 60s
    case extended   // 120s - ACE-Step only
    case maximum    // 240s - ACE-Step only

    /// Duration in seconds
    public var seconds: Int {
        switch self {
        case .short: return 10
        case .medium: return 30
        case .long: return 60
        case .extended: return 120
        case .maximum: return 240
        }
    }

    /// Human-readable display name
    public var displayName: String {
        switch self {
        case .short: return "10 sec"
        case .medium: return "30 sec"
        case .long: return "1 min"
        case .extended: return "2 min"
        case .maximum: return "4 min"
        }
    }

    /// Icon for UI
    public var icon: String {
        switch self {
        case .short: return "hare"
        case .medium: return "timer"
        case .long: return "tortoise"
        case .extended: return "clock"
        case .maximum: return "hourglass"
        }
    }

    /// Whether this duration requires a Pro license
    public var requiresPro: Bool {
        // TODO: Re-enable Pro gating before release
        return false
    }

    /// Check if this duration is compatible with a given model
    public func isCompatible(with model: ModelType) -> Bool {
        seconds <= model.maxDurationSeconds
    }

    /// Get durations available for a specific model
    public static func available(for model: ModelType) -> [TrackDuration] {
        allCases.filter { $0.isCompatible(with: model) }
    }
}
