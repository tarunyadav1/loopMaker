import SwiftUI

struct LibraryView: View {
    @EnvironmentObject var appState: AppState

    var body: some View {
        Group {
            if appState.tracks.isEmpty {
                emptyState
            } else {
                trackList
            }
        }
        .navigationTitle("Library")
        .searchable(text: $appState.searchQuery, prompt: "Search tracks")
        .toolbar {
            ToolbarItem(placement: .primaryAction) {
                Button {
                    appState.selectedSidebarItem = .generate
                } label: {
                    Label("New", systemImage: "plus")
                }
            }
        }
    }

    private var emptyState: some View {
        VStack(spacing: 16) {
            Image(systemName: "music.note.list")
                .font(.system(size: 64))
                .foregroundStyle(.tertiary)

            Text("No Tracks Yet")
                .font(.title2.bold())

            Text("Generate your first track to see it here")
                .foregroundStyle(.secondary)

            Button("Generate Music") {
                appState.selectedSidebarItem = .generate
            }
            .buttonStyle(.borderedProminent)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }

    private var trackList: some View {
        List(appState.filteredTracks, selection: $appState.selectedTrack) { track in
            TrackRow(track: track)
                .tag(track)
                .contextMenu {
                    trackContextMenu(for: track)
                }
        }
    }

    @ViewBuilder
    private func trackContextMenu(for track: Track) -> some View {
        Button {
            appState.toggleFavorite(track)
        } label: {
            Label(
                track.isFavorite ? "Remove from Favorites" : "Add to Favorites",
                systemImage: track.isFavorite ? "heart.slash" : "heart"
            )
        }

        Button {
            appState.selectedTrack = track
            appState.showExport = true
        } label: {
            Label("Export...", systemImage: "square.and.arrow.up")
        }

        Divider()

        Button(role: .destructive) {
            appState.deleteTrack(track)
        } label: {
            Label("Delete", systemImage: "trash")
        }
    }
}

struct TrackRow: View {
    let track: Track

    var body: some View {
        HStack(spacing: 12) {
            // Thumbnail
            RoundedRectangle(cornerRadius: 8)
                .fill(.blue.gradient)
                .frame(width: 48, height: 48)
                .overlay {
                    Image(systemName: "waveform")
                        .foregroundStyle(.white)
                }

            // Info
            VStack(alignment: .leading, spacing: 4) {
                HStack {
                    Text(track.displayTitle)
                        .font(.headline)
                        .lineLimit(1)

                    if track.isFavorite {
                        Image(systemName: "heart.fill")
                            .foregroundStyle(.red)
                            .font(.caption)
                    }
                }

                Text("\(track.duration.displayName) • \(track.model.displayName)")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }

            Spacer()

            // Date
            Text(track.formattedDate)
                .font(.caption)
                .foregroundStyle(.tertiary)
        }
        .padding(.vertical, 4)
    }
}

struct FavoritesView: View {
    @EnvironmentObject var appState: AppState

    var favorites: [Track] {
        appState.tracks.filter { $0.isFavorite }
    }

    var body: some View {
        Group {
            if favorites.isEmpty {
                VStack(spacing: 16) {
                    Image(systemName: "heart")
                        .font(.system(size: 64))
                        .foregroundStyle(.tertiary)

                    Text("No Favorites")
                        .font(.title2.bold())

                    Text("Heart a track to add it here")
                        .foregroundStyle(.secondary)
                }
                .frame(maxWidth: .infinity, maxHeight: .infinity)
            } else {
                List(favorites, selection: $appState.selectedTrack) { track in
                    TrackRow(track: track)
                        .tag(track)
                }
            }
        }
        .navigationTitle("Favorites")
    }
}

#Preview {
    LibraryView()
        .environmentObject(AppState())
}
