import Foundation

/// State of model download
public enum ModelDownloadState: Sendable, Equatable {
    case notDownloaded
    case downloading(progress: Double)
    case downloaded
    case error(String)

    /// Whether model is ready to use
    public var isDownloaded: Bool {
        if case .downloaded = self {
            return true
        }
        return false
    }

    /// Whether download is in progress
    public var isDownloading: Bool {
        if case .downloading = self {
            return true
        }
        return false
    }

    /// Download progress (0-1), nil if not downloading
    public var progress: Double? {
        if case .downloading(let progress) = self {
            return progress
        }
        return nil
    }

    /// Error message if in error state
    public var errorMessage: String? {
        if case .error(let message) = self {
            return message
        }
        return nil
    }
}
