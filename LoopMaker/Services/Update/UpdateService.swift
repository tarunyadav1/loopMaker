import Foundation
import Sparkle

/// Service for managing application updates using Sparkle.
/// Gracefully handles missing bundle identifier (e.g. SPM debug builds run from Xcode).
@MainActor
final class UpdateService: NSObject, ObservableObject, SPUUpdaterDelegate {
    /// Shared instance
    static let shared = UpdateService()

    /// The Sparkle updater controller - nil when bundle identifier is missing
    private var updaterController: SPUStandardUpdaterController?

    /// Whether Sparkle is available (requires valid bundle identifier)
    private var sparkleAvailable: Bool { updaterController != nil }

    /// Whether an update is currently being checked
    @Published var isCheckingForUpdates = false

    /// Whether an update is available
    @Published var updateAvailable = false

    /// The last check date
    @Published var lastCheckDate: Date?

    /// Whether automatic update checks are enabled
    var automaticUpdateChecks: Bool {
        get { updaterController?.updater.automaticallyChecksForUpdates ?? false }
        set { updaterController?.updater.automaticallyChecksForUpdates = newValue }
    }

    /// Whether automatic downloads are enabled
    var automaticDownloads: Bool {
        get { updaterController?.updater.automaticallyDownloadsUpdates ?? false }
        set { updaterController?.updater.automaticallyDownloadsUpdates = newValue }
    }

    /// Update check interval in seconds (default: 1 day)
    var updateCheckInterval: TimeInterval {
        get { updaterController?.updater.updateCheckInterval ?? 0 }
        set { updaterController?.updater.updateCheckInterval = newValue }
    }

    /// Whether the updater can check for updates
    var canCheckForUpdates: Bool {
        updaterController?.updater.canCheckForUpdates ?? false
    }

    private override init() {
        super.init()

        // Guard: Sparkle requires a valid bundle identifier to function.
        // In SPM debug builds run from Xcode, the bundle has no identifier,
        // which causes Sparkle to crash with a fatal error. Skip initialization.
        guard Bundle.main.bundleIdentifier != nil else {
            Log.app.warning("No bundle identifier - Sparkle updates disabled (development build)")
            return
        }

        // Create the updater controller with self as delegate
        updaterController = SPUStandardUpdaterController(
            startingUpdater: true,
            updaterDelegate: self,
            userDriverDelegate: nil
        )

        // Set default update check interval to 1 day
        if let controller = updaterController, controller.updater.updateCheckInterval == 0 {
            controller.updater.updateCheckInterval = Constants.Update.checkInterval
        }

        // Load last check date
        lastCheckDate = updaterController?.updater.lastUpdateCheckDate

        let interval = updaterController?.updater.updateCheckInterval ?? 0
        Log.app.info("UpdateService initialized, check interval: \(interval)s")
    }

    /// Check for updates interactively (shows UI)
    func checkForUpdates() {
        guard canCheckForUpdates else {
            Log.app.warning("Cannot check for updates right now")
            return
        }

        isCheckingForUpdates = true
        updaterController?.checkForUpdates(nil)
    }

    /// Check for updates in the background (no UI unless update found)
    func checkForUpdatesInBackground() {
        guard canCheckForUpdates else { return }
        updaterController?.updater.checkForUpdatesInBackground()
    }

    /// Get the current app version string
    var currentVersion: String {
        Bundle.main.infoDictionary?["CFBundleShortVersionString"] as? String ?? "1.0.0"
    }

    /// Get the current build number
    var currentBuild: String {
        Bundle.main.infoDictionary?["CFBundleVersion"] as? String ?? "1"
    }

    /// Format the last check date for display
    var lastCheckDateFormatted: String {
        guard let date = lastCheckDate else {
            return "Never"
        }

        let formatter = RelativeDateTimeFormatter()
        formatter.unitsStyle = .full
        return formatter.localizedString(for: date, relativeTo: Date())
    }

    // MARK: - SPUUpdaterDelegate

    nonisolated func updater(
        _ updater: SPUUpdater,
        didFinishUpdateCycleFor updateCheck: SPUUpdateCheck,
        error: (any Error)?
    ) {
        let checkDate = updater.lastUpdateCheckDate
        let errorDesc = error?.localizedDescription
        Task { @MainActor in
            self.isCheckingForUpdates = false
            self.lastCheckDate = checkDate

            if let errorDesc {
                Log.app.error("Update check failed: \(errorDesc)")
            }
        }
    }

    nonisolated func updater(_ updater: SPUUpdater, didFindValidUpdate item: SUAppcastItem) {
        let versionString = item.displayVersionString
        Task { @MainActor in
            self.updateAvailable = true
            Log.app.info("Update available: \(versionString)")
        }
    }

    nonisolated func updaterDidNotFindUpdate(_ updater: SPUUpdater, error: any Error) {
        let checkDate = updater.lastUpdateCheckDate
        Task { @MainActor in
            self.updateAvailable = false
            self.isCheckingForUpdates = false
            self.lastCheckDate = checkDate
        }
    }
}
