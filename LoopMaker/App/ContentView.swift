import SwiftUI

struct ContentView: View {
    @EnvironmentObject var appState: AppState
    @State private var localSelection: SidebarItem = .generate

    var body: some View {
        ZStack {
            // Background
            Theme.background
                .ignoresSafeArea()

            // Main layout
            VStack(spacing: 0) {
                // Content area
                HStack(spacing: 0) {
                    // Sidebar
                    NewSidebarView(selection: $localSelection)

                    // Divider
                    Rectangle()
                        .fill(Theme.glassBorder)
                        .frame(width: 1)

                    // Detail view
                    DetailView()
                        .frame(maxWidth: .infinity, maxHeight: .infinity)
                }

                // Player bar (only when track selected)
                PlayerBar(
                    track: appState.selectedTrack,
                    isPlaying: appState.audioPlayer.isPlaying,
                    progress: appState.audioPlayer.progress,
                    currentTime: appState.audioPlayer.currentTimeFormatted,
                    duration: appState.audioPlayer.durationFormatted,
                    onPlayPause: {
                        appState.togglePlayPause()
                    },
                    onSeek: { position in
                        appState.seekPlayback(to: position)
                    }
                )
            }
        }
        .preferredColorScheme(.dark)
        .onChange(of: localSelection) { _, newValue in
            Task { @MainActor in
                appState.selectedSidebarItem = newValue
            }
        }
        .onAppear {
            localSelection = appState.selectedSidebarItem
        }
        .sheet(isPresented: $appState.showSettings) {
            SettingsView()
        }
        .sheet(isPresented: $appState.showExport) {
            if let track = appState.selectedTrack {
                ExportView(track: track)
            }
        }
        .sheet(isPresented: $appState.showSetup) {
            SetupView()
        }
    }
}

struct DetailView: View {
    @EnvironmentObject var appState: AppState

    var body: some View {
        Group {
            switch appState.selectedSidebarItem {
            case .generate:
                GenerationView()
            case .library:
                LibraryView()
            case .favorites:
                FavoritesView()
            case .settings:
                SettingsView()
            }
        }
        .background(Theme.background)
    }
}

#Preview {
    ContentView()
        .environmentObject(AppState())
}
