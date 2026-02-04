import Foundation

/// Supported audio export formats
public enum AudioExportFormat: String, CaseIterable, Codable, Sendable {
    case wav
    case m4a

    /// File extension
    public var fileExtension: String {
        rawValue
    }

    /// MIME type
    public var mimeType: String {
        switch self {
        case .wav: return "audio/wav"
        case .m4a: return "audio/mp4"
        }
    }

    /// Display name
    public var displayName: String {
        switch self {
        case .wav: return "WAV (Lossless)"
        case .m4a: return "M4A (Compressed)"
        }
    }

    /// Description
    public var description: String {
        switch self {
        case .wav: return "Uncompressed, best quality"
        case .m4a: return "Smaller file size, good quality"
        }
    }
}
