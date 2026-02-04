import Foundation
import os.log

/// Unified logging system for LoopMaker
public enum Log {
    /// App lifecycle and general events
    public static let app = Logger(subsystem: "com.loopmaker.LoopMaker", category: "app")

    /// UI-related events
    public static let ui = Logger(subsystem: "com.loopmaker.LoopMaker", category: "ui")

    /// Audio playback and processing
    public static let audio = Logger(subsystem: "com.loopmaker.LoopMaker", category: "audio")

    /// ML model operations
    public static let ml = Logger(subsystem: "com.loopmaker.LoopMaker", category: "ml")

    /// Music generation
    public static let generation = Logger(subsystem: "com.loopmaker.LoopMaker", category: "generation")

    /// Data persistence
    public static let data = Logger(subsystem: "com.loopmaker.LoopMaker", category: "data")

    /// Performance metrics
    public static let performance = Logger(subsystem: "com.loopmaker.LoopMaker", category: "performance")

    /// Export operations
    public static let export = Logger(subsystem: "com.loopmaker.LoopMaker", category: "export")

    /// Network/backend communication
    public static let network = Logger(subsystem: "com.loopmaker.LoopMaker", category: "network")
}
