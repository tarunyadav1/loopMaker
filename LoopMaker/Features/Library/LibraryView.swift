import SwiftUI

struct LibraryView: View {
    @EnvironmentObject var appState: AppState
    @State private var localTrackSelection: Track?
    @State private var viewMode: ViewMode = .grid
    @State private var searchText = ""

    enum ViewMode {
        case grid, list
    }

    var body: some View {
        VStack(spacing: 0) {
            // Header
            headerView

            // Content
            if appState.tracks.isEmpty {
                emptyState
            } else {
                trackContent
            }
        }
        .background(Theme.background)
    }

    // MARK: - Header

    private var headerView: some View {
        HStack(spacing: Spacing.md) {
            VStack(alignment: .leading, spacing: Spacing.xs) {
                Text("Library")
                    .title1Text()

                Text("\(appState.tracks.count) tracks")
                    .font(Typography.caption)
                    .foregroundStyle(Theme.textTertiary)
            }

            Spacer()

            // Search
            SearchBar(text: $searchText, placeholder: "Search library...", showShortcut: false)
                .frame(maxWidth: 250)

            // View toggle
            HStack(spacing: Spacing.xs) {
                ViewModeButton(icon: "square.grid.2x2", isSelected: viewMode == .grid) {
                    viewMode = .grid
                }

                ViewModeButton(icon: "list.bullet", isSelected: viewMode == .list) {
                    viewMode = .list
                }
            }

            // New track button
            ActionButton(title: "New", icon: "plus", variant: .primary, size: .medium) {
                appState.selectedSidebarItem = .generate
            }
        }
        .padding(.horizontal, Spacing.lg)
        .padding(.vertical, Spacing.md)
        .background(Theme.backgroundSecondary)
    }

    // MARK: - Empty State

    private var emptyState: some View {
        VStack(spacing: Spacing.lg) {
            Spacer()

            ZStack {
                Circle()
                    .fill(Theme.backgroundTertiary)
                    .frame(width: 120, height: 120)

                Image(systemName: "music.note.list")
                    .font(.system(size: 48))
                    .foregroundStyle(Theme.textTertiary)
            }

            VStack(spacing: Spacing.sm) {
                Text("No Tracks Yet")
                    .title2Text()

                Text("Generate your first track to see it here")
                    .font(Typography.body)
                    .foregroundStyle(Theme.textSecondary)
            }

            ActionButton(title: "Generate Music", icon: "waveform", variant: .gradient, size: .large) {
                appState.selectedSidebarItem = .generate
            }

            Spacer()
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }

    // MARK: - Track Content

    private var trackContent: some View {
        ScrollView {
            if viewMode == .grid {
                trackGrid
            } else {
                trackList
            }
        }
        .padding(.horizontal, Spacing.lg)
        .padding(.vertical, Spacing.md)
    }

    private var trackGrid: some View {
        LazyVGrid(columns: [
            GridItem(.adaptive(minimum: 200, maximum: 280), spacing: Spacing.md)
        ], spacing: Spacing.md) {
            ForEach(filteredTracks) { track in
                TrackGridItem(
                    track: track,
                    isSelected: localTrackSelection?.id == track.id,
                    onTap: { selectTrack(track) },
                    onDoubleTap: { playTrack(track) }
                )
                .contextMenu { trackContextMenu(for: track) }
            }
        }
    }

    private var trackList: some View {
        VStack(spacing: Spacing.xs) {
            ForEach(filteredTracks) { track in
                DarkTrackRow(
                    track: track,
                    isSelected: localTrackSelection?.id == track.id,
                    onTap: { selectTrack(track) },
                    onDoubleTap: { playTrack(track) }
                )
                .contextMenu { trackContextMenu(for: track) }
            }
        }
    }

    private var filteredTracks: [Track] {
        if searchText.isEmpty {
            return appState.tracks
        }
        return appState.tracks.filter {
            $0.prompt.localizedCaseInsensitiveContains(searchText) ||
            ($0.title?.localizedCaseInsensitiveContains(searchText) ?? false)
        }
    }

    // MARK: - Actions

    private func selectTrack(_ track: Track) {
        localTrackSelection = track
        appState.selectedTrack = track
    }

    private func playTrack(_ track: Track) {
        appState.playTrack(track)
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

// MARK: - View Mode Button

struct ViewModeButton: View {
    let icon: String
    let isSelected: Bool
    let action: () -> Void

    @State private var isHovered = false

    var body: some View {
        Button(action: action) {
            Image(systemName: icon)
                .font(.system(size: 14))
                .foregroundStyle(isSelected ? Theme.accentPrimary : Theme.textSecondary)
                .frame(width: 32, height: 32)
                .background(
                    RoundedRectangle(cornerRadius: Spacing.radiusSm)
                        .fill(isSelected ? Theme.accentPrimary.opacity(0.15) : (isHovered ? Theme.backgroundTertiary : Color.clear))
                )
        }
        .buttonStyle(.plain)
        .onHover { hovering in
            isHovered = hovering
        }
    }
}

// MARK: - Track Grid Item

struct TrackGridItem: View {
    let track: Track
    let isSelected: Bool
    var onTap: () -> Void = {}
    var onDoubleTap: () -> Void = {}

    @State private var isHovered = false

    var body: some View {
        Button(action: onTap) {
            VStack(alignment: .leading, spacing: Spacing.sm) {
                // Thumbnail
                ZStack {
                    RoundedRectangle(cornerRadius: Spacing.radiusMd)
                        .fill(Theme.accentGradient)
                        .aspectRatio(1, contentMode: .fit)

                    Image(systemName: "waveform")
                        .font(.system(size: 32))
                        .foregroundStyle(.white.opacity(0.8))

                    // Play overlay on hover
                    if isHovered {
                        RoundedRectangle(cornerRadius: Spacing.radiusMd)
                            .fill(Color.black.opacity(0.3))

                        Image(systemName: "play.circle.fill")
                            .font(.system(size: 44))
                            .foregroundStyle(.white)
                    }

                    // Favorite badge
                    if track.isFavorite {
                        VStack {
                            HStack {
                                Spacer()
                                Image(systemName: "heart.fill")
                                    .font(.system(size: 14))
                                    .foregroundStyle(.white)
                                    .padding(Spacing.sm)
                            }
                            Spacer()
                        }
                    }
                }

                // Info
                VStack(alignment: .leading, spacing: 2) {
                    Text(track.displayTitle)
                        .font(Typography.bodyMedium)
                        .foregroundStyle(Theme.textPrimary)
                        .lineLimit(1)

                    Text("\(track.duration.displayName) \u{2022} \(track.model.displayName)")
                        .font(Typography.caption)
                        .foregroundStyle(Theme.textTertiary)
                }
            }
            .padding(Spacing.sm)
            .background(
                RoundedRectangle(cornerRadius: Spacing.radiusMd)
                    .fill(isSelected ? Theme.accentPrimary.opacity(0.1) : (isHovered ? Theme.backgroundTertiary : Theme.backgroundSecondary))
            )
            .overlay(
                RoundedRectangle(cornerRadius: Spacing.radiusMd)
                    .strokeBorder(isSelected ? Theme.accentPrimary : Color.clear, lineWidth: 2)
            )
        }
        .buttonStyle(.plain)
        .onHover { hovering in
            withAnimation(.easeInOut(duration: 0.15)) {
                isHovered = hovering
            }
        }
        .onTapGesture(count: 2) {
            onDoubleTap()
        }
        .onTapGesture {
            onTap()
        }
    }
}

// MARK: - Dark Track Row

struct DarkTrackRow: View {
    let track: Track
    let isSelected: Bool
    var onTap: () -> Void = {}
    var onDoubleTap: () -> Void = {}

    @State private var isHovered = false

    var body: some View {
        Button(action: onTap) {
            HStack(spacing: Spacing.md) {
                // Thumbnail
                ZStack {
                    RoundedRectangle(cornerRadius: Spacing.radiusSm)
                        .fill(Theme.accentGradient)
                        .frame(width: 48, height: 48)

                    Image(systemName: "waveform")
                        .font(.system(size: 18))
                        .foregroundStyle(.white)

                    if isHovered {
                        RoundedRectangle(cornerRadius: Spacing.radiusSm)
                            .fill(Color.black.opacity(0.3))
                            .frame(width: 48, height: 48)

                        Image(systemName: "play.fill")
                            .font(.system(size: 16))
                            .foregroundStyle(.white)
                    }
                }

                // Info
                VStack(alignment: .leading, spacing: 2) {
                    HStack(spacing: Spacing.sm) {
                        Text(track.displayTitle)
                            .font(Typography.bodyMedium)
                            .foregroundStyle(Theme.textPrimary)
                            .lineLimit(1)

                        if track.isFavorite {
                            Image(systemName: "heart.fill")
                                .font(.system(size: 12))
                                .foregroundStyle(Theme.error)
                        }
                    }

                    Text(track.prompt)
                        .font(Typography.caption)
                        .foregroundStyle(Theme.textTertiary)
                        .lineLimit(1)
                }

                Spacer()

                // Duration
                Text(track.duration.displayName)
                    .font(Typography.caption)
                    .foregroundStyle(Theme.textSecondary)

                // Date
                Text(track.formattedDate)
                    .font(Typography.caption)
                    .foregroundStyle(Theme.textTertiary)
                    .frame(width: 100, alignment: .trailing)
            }
            .padding(.horizontal, Spacing.md)
            .padding(.vertical, Spacing.sm)
            .background(
                RoundedRectangle(cornerRadius: Spacing.radiusSm)
                    .fill(isSelected ? Theme.accentPrimary.opacity(0.1) : (isHovered ? Theme.backgroundTertiary : Color.clear))
            )
            .overlay(
                RoundedRectangle(cornerRadius: Spacing.radiusSm)
                    .strokeBorder(isSelected ? Theme.accentPrimary.opacity(0.5) : Color.clear, lineWidth: 1)
            )
        }
        .buttonStyle(.plain)
        .onHover { hovering in
            withAnimation(.easeInOut(duration: 0.1)) {
                isHovered = hovering
            }
        }
        .onTapGesture(count: 2) {
            onDoubleTap()
        }
        .onTapGesture {
            onTap()
        }
    }
}

// MARK: - Favorites View

struct FavoritesView: View {
    @EnvironmentObject var appState: AppState
    @State private var localSelection: Track?

    var favorites: [Track] {
        appState.tracks.filter { $0.isFavorite }
    }

    var body: some View {
        VStack(spacing: 0) {
            // Header
            HStack {
                VStack(alignment: .leading, spacing: Spacing.xs) {
                    Text("Favorites")
                        .title1Text()

                    Text("\(favorites.count) tracks")
                        .font(Typography.caption)
                        .foregroundStyle(Theme.textTertiary)
                }

                Spacer()
            }
            .padding(.horizontal, Spacing.lg)
            .padding(.vertical, Spacing.md)
            .background(Theme.backgroundSecondary)

            // Content
            if favorites.isEmpty {
                emptyFavoritesState
            } else {
                ScrollView {
                    VStack(spacing: Spacing.xs) {
                        ForEach(favorites) { track in
                            DarkTrackRow(
                                track: track,
                                isSelected: localSelection?.id == track.id,
                                onTap: {
                                    localSelection = track
                                    appState.selectedTrack = track
                                },
                                onDoubleTap: {
                                    appState.playTrack(track)
                                }
                            )
                        }
                    }
                    .padding(.horizontal, Spacing.lg)
                    .padding(.vertical, Spacing.md)
                }
            }
        }
        .background(Theme.background)
    }

    private var emptyFavoritesState: some View {
        VStack(spacing: Spacing.lg) {
            Spacer()

            ZStack {
                Circle()
                    .fill(Theme.backgroundTertiary)
                    .frame(width: 120, height: 120)

                Image(systemName: "heart")
                    .font(.system(size: 48))
                    .foregroundStyle(Theme.textTertiary)
            }

            VStack(spacing: Spacing.sm) {
                Text("No Favorites")
                    .title2Text()

                Text("Heart a track to add it here")
                    .font(Typography.body)
                    .foregroundStyle(Theme.textSecondary)
            }

            Spacer()
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }
}

#Preview {
    LibraryView()
        .environmentObject(AppState())
}
