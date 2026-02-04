import SwiftUI

@main
struct LoopMakerApp: App {
    @StateObject private var appState = AppState()

    var body: some Scene {
        WindowGroup {
            ContentView()
                .environmentObject(appState)
        }
        .windowStyle(.automatic)
        .defaultSize(width: 1200, height: 800)
        .commands {
            CommandGroup(replacing: .newItem) {}

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
}
