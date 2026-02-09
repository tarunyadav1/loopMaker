import SwiftUI
import Sparkle

@main
struct LoopMakerApp: App {
    @StateObject private var appState = AppState()
    @StateObject private var updateService = UpdateService.shared

    var body: some Scene {
        // Main Window - Liquid Glass navigation, hidden title bar
        Window("LoopMaker", id: "main") {
            MainWindow()
                .environmentObject(appState)
                .environmentObject(updateService)
                .onAppear {
                    DispatchQueue.main.async {
                        NSApp.setActivationPolicy(.regular)
                        NSApp.activate(ignoringOtherApps: true)
                        for window in NSApp.windows {
                            if window.contentView != nil && !window.className.contains("StatusBar") {
                                window.makeKeyAndOrderFront(nil)
                                break
                            }
                        }
                    }
                }
        }
        .windowStyle(.hiddenTitleBar)
        .defaultSize(width: 1100, height: 750)
        .commands {
            CommandGroup(replacing: .newItem) {}

            CommandGroup(after: .appInfo) {
                Button("Check for Updates...") {
                    updateService.checkForUpdates()
                }
                .disabled(!updateService.canCheckForUpdates)
            }

            CommandMenu("Generation") {
                Button("New Generation") {
                    appState.showNewGeneration = true
                }
                .keyboardShortcut("n", modifiers: [.command])

                Divider()

                Button("Cancel Generation") {
                    appState.cancelGeneration()
                }
                .keyboardShortcut(".", modifiers: [.command])
                .disabled(!appState.isGenerating)
            }
        }
    }

    init() {
        // Check for updates in background on launch
        Task { @MainActor in
            UpdateService.shared.checkForUpdatesInBackground()
        }

        // Register for app termination to clean up backend process
        NotificationCenter.default.addObserver(
            forName: NSApplication.willTerminateNotification,
            object: nil,
            queue: .main
        ) { _ in
            Task { @MainActor in
                await AppState.shared?.backendManager.stopBackend()
            }
        }
    }
}

// MARK: - Shared AppState Access

extension AppState {
    @MainActor static var shared: AppState?

    @MainActor func registerAsShared() {
        AppState.shared = self
    }
}
