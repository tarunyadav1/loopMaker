import SwiftUI

struct LibraryView: View {
    @EnvironmentObject var appState: AppState
    @State private var localTrackSelection: Track?
    @State private var viewMode: ViewMode = .grid
    @State private var searchText = ""
    @State private var showDetail = false
    @State private var sortOrder: LibrarySortOrder = .newestFirst
    @State private var activeFilter: LibraryFilter = .all
    @State private var isMultiSelectMode = false
    @State private var selectedTrackIDs: Set<UUID> = []
    @State private var showDeleteSelectedConfirmation = false
    @State private var showBatchExportResultAlert = false
    @State private var batchExportResultMessage = ""

    enum ViewMode {
        case grid, list
    }

    enum LibrarySortOrder: String, CaseIterable {
        case newestFirst = "Newest First"
        case oldestFirst = "Oldest First"
        case nameAZ = "Name A-Z"
        case nameZA = "Name Z-A"
        case durationAsc = "Shortest First"
        case durationDesc = "Longest First"
    }

    enum LibraryFilter: String, CaseIterable {
        case all = "All"
        case favorites = "Favorites"
        case covers = "Covers"
        case extended = "Extended"
        case withLyrics = "With Lyrics"
    }

    var body: some View {
        Group {
            if showDetail, !isMultiSelectMode, let selected = localTrackSelection {
                TrackDetailPanel(track: selected) {
                    withAnimation(.easeInOut(duration: 0.2)) {
                        showDetail = false
                    }
                }
                .transition(.move(edge: .trailing).combined(with: .opacity))
            } else {
                libraryContent
            }
        }
        .background(Theme.background)
        .alert("Batch Export", isPresented: $showBatchExportResultAlert) {
            Button("OK", role: .cancel) {}
        } message: {
            Text(batchExportResultMessage)
        }
    }

    private var libraryContent: some View {
        VStack(spacing: 0) {
            // Header
            headerView

            // Content
            ZStack(alignment: .bottom) {
                if appState.tracks.isEmpty {
                    emptyState
                } else {
                    trackContent
                }

                // Multi-select floating action bar
                if isMultiSelectMode && !selectedTrackIDs.isEmpty {
                    multiSelectActionBar
                        .transition(.move(edge: .bottom).combined(with: .opacity))
                }
            }
        }
    }

    // MARK: - Header

    private var headerView: some View {
        VStack(spacing: 0) {
            HStack(spacing: Spacing.md) {
                VStack(alignment: .leading, spacing: Spacing.xs) {
                    Text("Library")
                        .title1Text()

                    Text("\(appState.tracks.count) tracks")
                        .font(Typography.caption)
                        .foregroundStyle(Theme.textTertiary)
                }

                Spacer()

                HStack(spacing: Spacing.sm) {
                    // Search
                    SearchBar(text: $searchText, placeholder: "Search library...", showShortcut: false)
                        .frame(maxWidth: 280)

                    // Sort menu
                    Menu {
                        ForEach(LibrarySortOrder.allCases, id: \.self) { order in
                            Button {
                                sortOrder = order
                            } label: {
                                HStack {
                                    Text(order.rawValue)
                                    if sortOrder == order {
                                        Image(systemName: "checkmark")
                                    }
                                }
                            }
                        }
                    } label: {
                        HStack(spacing: 4) {
                            Image(systemName: "arrow.up.arrow.down")
                                .font(.system(size: 12))
                            Text(sortOrder.rawValue)
                                .font(Typography.caption)
                        }
                        .foregroundStyle(Theme.textSecondary)
                        .padding(.horizontal, 8)
                        .padding(.vertical, 6)
                        .background(
                            RoundedRectangle(cornerRadius: 6)
                                .fill(Color.primary.opacity(0.06))
                        )
                    }
                    .menuStyle(.borderlessButton)
                    .fixedSize()

                    // View toggle
                    HStack(spacing: Spacing.xs) {
                        ViewModeButton(icon: "square.grid.2x2", isSelected: viewMode == .grid) {
                            viewMode = .grid
                        }

                        ViewModeButton(icon: "list.bullet", isSelected: viewMode == .list) {
                            viewMode = .list
                        }

                        ViewModeButton(icon: "checkmark.circle", isSelected: isMultiSelectMode) {
                            withAnimation(.easeInOut(duration: 0.2)) {
                                isMultiSelectMode.toggle()
                                if !isMultiSelectMode {
                                    selectedTrackIDs.removeAll()
                                }
                            }
                        }
                    }

                    // New track button
                    ActionButton(title: "New", icon: "plus", variant: .primary, size: .medium) {
                        appState.showNewGeneration = true
                    }
                }
            }
            .padding(.horizontal, Spacing.lg)
            .padding(.vertical, Spacing.md)

            // Filter chips
            if !appState.tracks.isEmpty {
                ScrollView(.horizontal, showsIndicators: false) {
                    HStack(spacing: Spacing.sm) {
                        ForEach(LibraryFilter.allCases, id: \.self) { filter in
                            FilterChip(
                                title: filter.rawValue,
                                isSelected: activeFilter == filter,
                                action: {
                                    withAnimation(.easeInOut(duration: 0.15)) {
                                        activeFilter = filter
                                    }
                                }
                            )
                        }
                    }
                    .padding(.horizontal, Spacing.lg)
                    .padding(.bottom, Spacing.sm)
                }
            }
        }
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
                appState.showNewGeneration = true
            }

            Spacer()
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }

    // MARK: - Track Content

    private var trackContent: some View {
        ScrollView {
            if filteredTracks.isEmpty {
                noResultsState
            } else if viewMode == .grid {
                trackGrid
            } else {
                trackList
            }
        }
        .padding(.horizontal, Spacing.lg)
        .padding(.vertical, Spacing.md)
    }

    private var noResultsState: some View {
        VStack(spacing: Spacing.md) {
            Image(systemName: "magnifyingglass")
                .font(.system(size: 28))
                .foregroundStyle(Theme.textTertiary)

            VStack(spacing: Spacing.xs) {
                Text("No Matching Tracks")
                    .title3Text()

                Text("Try a different search term or clear filters.")
                    .font(Typography.body)
                    .foregroundStyle(Theme.textSecondary)
            }

            HStack(spacing: Spacing.sm) {
                if !searchText.isEmpty {
                    Button("Clear Search") {
                        searchText = ""
                    }
                    .buttonStyle(.bordered)
                }

                if activeFilter != .all {
                    Button("Reset Filters") {
                        activeFilter = .all
                    }
                    .buttonStyle(.bordered)
                }
            }
        }
        .frame(maxWidth: .infinity, minHeight: 260)
        .padding(.top, Spacing.xl)
    }

    private func isTrackSelected(_ track: Track) -> Bool {
        if isMultiSelectMode {
            return selectedTrackIDs.contains(track.id)
        }
        return localTrackSelection?.id == track.id
    }

    private func isNowPlaying(_ track: Track) -> Bool {
        appState.audioPlayer.isPlaying && appState.audioPlayer.isCurrentTrack(track.audioURL)
    }

    private var trackGrid: some View {
        LazyVGrid(columns: [
            GridItem(.adaptive(minimum: 200, maximum: 280), spacing: Spacing.md)
        ], spacing: Spacing.md) {
            ForEach(filteredTracks) { track in
                TrackGridItem(
                    track: track,
                    isSelected: isTrackSelected(track),
                    isNowPlaying: isNowPlaying(track),
                    onTap: { selectTrack(track) },
                    onDoubleTap: { if !isMultiSelectMode { playTrack(track) } }
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
                    isSelected: isTrackSelected(track),
                    isNowPlaying: isNowPlaying(track),
                    onTap: { selectTrack(track) },
                    onDoubleTap: { if !isMultiSelectMode { playTrack(track) } }
                )
                .contextMenu { trackContextMenu(for: track) }
            }
        }
    }

    private var filteredTracks: [Track] {
        var tracks = appState.tracks

        // 1. Apply filter
        switch activeFilter {
        case .all: break
        case .favorites: tracks = tracks.filter { $0.isFavorite }
        case .covers: tracks = tracks.filter { $0.isCover }
        case .extended: tracks = tracks.filter { $0.isExtended }
        case .withLyrics: tracks = tracks.filter { $0.hasLyrics }
        }

        // 2. Apply search
        if !searchText.isEmpty {
            tracks = tracks.filter {
                $0.prompt.localizedCaseInsensitiveContains(searchText) ||
                ($0.title?.localizedCaseInsensitiveContains(searchText) ?? false)
            }
        }

        // 3. Apply sort
        switch sortOrder {
        case .newestFirst:
            tracks.sort { $0.createdAt > $1.createdAt }
        case .oldestFirst:
            tracks.sort { $0.createdAt < $1.createdAt }
        case .nameAZ:
            tracks.sort { $0.displayTitle.localizedCaseInsensitiveCompare($1.displayTitle) == .orderedAscending }
        case .nameZA:
            tracks.sort { $0.displayTitle.localizedCaseInsensitiveCompare($1.displayTitle) == .orderedDescending }
        case .durationAsc:
            tracks.sort { $0.durationSeconds < $1.durationSeconds }
        case .durationDesc:
            tracks.sort { $0.durationSeconds > $1.durationSeconds }
        }

        return tracks
    }

    // MARK: - Multi-Select Action Bar

    private var multiSelectActionBar: some View {
        HStack(spacing: Spacing.md) {
            Text("\(selectedTrackIDs.count) selected")
                .font(Typography.bodyMedium)
                .foregroundStyle(Theme.textPrimary)

            Spacer()

            Button {
                for id in selectedTrackIDs {
                    if let track = appState.tracks.first(where: { $0.id == id }), !track.isFavorite {
                        appState.toggleFavorite(track)
                    }
                }
                selectedTrackIDs.removeAll()
            } label: {
                Label("Favorite", systemImage: "heart")
                    .font(Typography.captionMedium)
            }
            .buttonStyle(.bordered)

            // Batch export
            Button {
                batchExportSelectedTracks()
            } label: {
                Label("Export", systemImage: "square.and.arrow.up")
                    .font(Typography.captionMedium)
            }
            .buttonStyle(.bordered)

            Button(role: .destructive) {
                showDeleteSelectedConfirmation = true
            } label: {
                Label("Delete", systemImage: "trash")
                    .font(Typography.captionMedium)
            }
            .buttonStyle(.bordered)
            .tint(.red)
            .alert("Delete Selected Tracks?", isPresented: $showDeleteSelectedConfirmation) {
                Button("Cancel", role: .cancel) {}
                Button("Delete", role: .destructive) {
                    appState.deleteMultipleTracks(selectedTrackIDs)
                    selectedTrackIDs.removeAll()
                    isMultiSelectMode = false
                }
            } message: {
                Text("This permanently deletes \(selectedTrackIDs.count) track(s) and their audio files.")
            }

            Button {
                selectedTrackIDs.removeAll()
                isMultiSelectMode = false
            } label: {
                Text("Cancel")
                    .font(Typography.captionMedium)
            }
            .buttonStyle(.bordered)
        }
        .padding(.horizontal, Spacing.lg)
        .padding(.vertical, Spacing.md)
        .background(
            RoundedRectangle(cornerRadius: Spacing.radiusMd)
                .fill(.regularMaterial)
                .shadow(color: .black.opacity(0.2), radius: 8, y: -2)
        )
        .padding(.horizontal, Spacing.sm)
        .padding(.bottom, Spacing.sm)
    }

    private func batchExportSelectedTracks() {
        let tracks = appState.tracks.filter { selectedTrackIDs.contains($0.id) }
        guard !tracks.isEmpty else { return }

        let panel = NSOpenPanel()
        panel.canChooseFiles = false
        panel.canChooseDirectories = true
        panel.canCreateDirectories = true
        panel.prompt = "Export Here"
        panel.message = "Choose a folder to export \(tracks.count) track(s) as WAV"

        panel.begin { response in
            guard response == .OK, let folderURL = panel.url else { return }
            var exportedCount = 0
            var failedNames: [String] = []
            for track in tracks {
                let baseName = sanitizedFilenameComponent(track.displayTitle)
                let destURL = uniqueDestinationURL(
                    in: folderURL,
                    preferredBaseName: baseName,
                    fileExtension: "wav"
                )
                do {
                    try FileManager.default.copyItem(at: track.audioURL, to: destURL)
                    exportedCount += 1
                } catch {
                    failedNames.append(track.displayTitle)
                    Log.export.error("Batch export error for \(track.displayTitle): \(error.localizedDescription)")
                }
            }

            if failedNames.isEmpty {
                batchExportResultMessage = "Exported \(exportedCount) track(s) successfully."
            } else {
                let preview = failedNames.prefix(3).joined(separator: ", ")
                let suffix = failedNames.count > 3 ? ", and \(failedNames.count - 3) more" : ""
                batchExportResultMessage =
                    "Exported \(exportedCount) of \(tracks.count). Failed: \(preview)\(suffix)."
            }
            showBatchExportResultAlert = true
            selectedTrackIDs.removeAll()
            isMultiSelectMode = false
        }
    }

    private func sanitizedFilenameComponent(_ raw: String) -> String {
        let invalidCharacters = CharacterSet(charactersIn: "/:\\?%*|\"<>")
        let components = raw.components(separatedBy: invalidCharacters)
        let collapsed = components.joined(separator: "-")
            .trimmingCharacters(in: .whitespacesAndNewlines)
        let cleaned = collapsed.isEmpty ? "Track" : collapsed
        return String(cleaned.prefix(80))
    }

    private func uniqueDestinationURL(in folder: URL, preferredBaseName: String, fileExtension: String) -> URL {
        var candidate = folder.appendingPathComponent("\(preferredBaseName).\(fileExtension)")
        var suffix = 2
        while FileManager.default.fileExists(atPath: candidate.path) {
            candidate = folder.appendingPathComponent("\(preferredBaseName)-\(suffix).\(fileExtension)")
            suffix += 1
        }
        return candidate
    }

    // MARK: - Actions

    private func selectTrack(_ track: Track) {
        if isMultiSelectMode {
            if selectedTrackIDs.contains(track.id) {
                selectedTrackIDs.remove(track.id)
            } else {
                selectedTrackIDs.insert(track.id)
            }
        } else {
            localTrackSelection = track
            appState.selectedTrack = track
            withAnimation(.easeInOut(duration: 0.2)) {
                showDetail = true
            }
        }
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
                    Group {
                        if isSelected {
                            RoundedRectangle(cornerRadius: Spacing.radiusSm)
                                .glassEffect(
                                    .regular.tint(Theme.accentPrimary.opacity(0.16)).interactive(),
                                    in: RoundedRectangle(cornerRadius: Spacing.radiusSm)
                                )
                        } else {
                            RoundedRectangle(cornerRadius: Spacing.radiusSm)
                                .fill(isHovered ? Theme.backgroundTertiary : Color.clear)
                        }
                    }
                )
        }
        .buttonStyle(.plain)
        .onHover { hovering in
            isHovered = hovering
        }
    }
}

// MARK: - Filter Chip

struct FilterChip: View {
    let title: String
    let isSelected: Bool
    let action: () -> Void

    @State private var isHovered = false

    var body: some View {
        Button(action: action) {
            Text(title)
                .font(Typography.captionMedium)
                .foregroundStyle(isSelected ? Theme.accentPrimary : Theme.textSecondary)
                .padding(.horizontal, Spacing.md)
                .padding(.vertical, 6)
                .background(
                    Group {
                        if isSelected {
                            Capsule()
                                .glassEffect(
                                    .regular.tint(Theme.accentPrimary.opacity(0.16)).interactive(),
                                    in: Capsule()
                                )
                        } else {
                            Capsule()
                                .fill(
                                    isHovered
                                        ? Theme.backgroundTertiary
                                        : Color.primary.opacity(0.06)
                                )
                        }
                    }
                )
        }
        .buttonStyle(.plain)
        .onHover { hovering in
            withAnimation(.easeInOut(duration: 0.1)) {
                isHovered = hovering
            }
        }
    }
}

// MARK: - Track Grid Item

struct TrackGridItem: View {
    let track: Track
    let isSelected: Bool
    var isNowPlaying: Bool = false
    var onTap: () -> Void = {}
    var onDoubleTap: () -> Void = {}

    @State private var isHovered = false

    private var thumbnailView: some View {
        let colors = track.gradientColors

        return ZStack {
            RoundedRectangle(cornerRadius: Spacing.radiusMd)
                .fill(
                    LinearGradient(
                        colors: [colors.0, colors.1],
                        startPoint: .topLeading,
                        endPoint: .bottomTrailing
                    )
                )
                .aspectRatio(4.0 / 3.0, contentMode: .fit)

            if isNowPlaying && !isHovered {
                // Now-playing equalizer indicator
                NowPlayingIndicator()
            } else {
                Image(systemName: "waveform")
                    .font(.system(size: 24))
                    .foregroundStyle(.white.opacity(0.4))
            }

            // Play overlay on hover
            if isHovered {
                RoundedRectangle(cornerRadius: Spacing.radiusMd)
                    .fill(Color.black.opacity(0.3))

                Image(systemName: "play.circle.fill")
                    .font(.system(size: 40))
                    .foregroundStyle(.white.opacity(0.9))
            }

            // Badges
            VStack {
                HStack {
                    if track.isCover {
                        Image(systemName: "arrow.triangle.2.circlepath.circle.fill")
                            .font(.system(size: 14))
                            .foregroundStyle(.white)
                            .padding(Spacing.sm)
                    } else if track.isExtended {
                        Image(systemName: "arrow.forward.to.line.circle.fill")
                            .font(.system(size: 14))
                            .foregroundStyle(.white)
                            .padding(Spacing.sm)
                    }

                    Spacer()

                    if track.isFavorite {
                        Image(systemName: "heart.fill")
                            .font(.system(size: 14))
                            .foregroundStyle(.white)
                            .padding(Spacing.sm)
                    }
                }
                Spacer()
                HStack {
                    // Now-playing badge bottom-left
                    if isNowPlaying {
                        HStack(spacing: 3) {
                            Image(systemName: "speaker.wave.2.fill")
                                .font(.system(size: 8))
                            Text("Playing")
                                .font(.system(size: 9, weight: .semibold))
                        }
                        .foregroundStyle(.white)
                        .padding(.horizontal, 6)
                        .padding(.vertical, 2)
                        .background(
                            Capsule()
                                .fill(DesignSystem.Colors.accent.opacity(0.8))
                        )
                        .padding(Spacing.sm)
                    }

                    Spacer()
                    // Glass-style duration pill
                    Text(track.duration.displayName)
                        .font(.system(size: 10, weight: .medium))
                        .foregroundStyle(.white)
                        .padding(.horizontal, 6)
                        .padding(.vertical, 2)
                        .background(
                            Capsule()
                                .fill(Color.white.opacity(0.15))
                        )
                        .padding(Spacing.sm)
                }
            }
        }
    }

    var body: some View {
        Button(action: onTap) {
            VStack(alignment: .leading, spacing: Spacing.sm) {
                thumbnailView

                // Info
                VStack(alignment: .leading, spacing: 2) {
                    Text(track.displayTitle)
                        .font(.system(size: 13, weight: .semibold))
                        .foregroundStyle(Theme.textPrimary)
                        .lineLimit(2)

                    Text(track.prompt)
                        .font(.system(size: 11))
                        .foregroundStyle(Theme.textTertiary)
                        .lineLimit(1)
                }
                .padding(.horizontal, Spacing.xs)
                .padding(.bottom, Spacing.xs)
            }
            .background(
                RoundedRectangle(cornerRadius: Spacing.radiusMd)
                    .fill(
                        isNowPlaying
                            ? Theme.accentPrimary.opacity(0.1)
                            : (isSelected ? Theme.accentPrimary.opacity(0.08) : Color.clear)
                    )
            )
            .overlay(
                RoundedRectangle(cornerRadius: Spacing.radiusMd)
                    .strokeBorder(
                        isNowPlaying
                            ? Theme.accentPrimary.opacity(0.6)
                            : (isSelected ? Theme.accentPrimary : Color.clear),
                        lineWidth: isNowPlaying ? 2 : 1.5
                    )
            )
            .scaleEffect(isHovered ? 1.02 : 1)
            .brightness(isHovered ? 0.05 : 0)
        }
        .buttonStyle(.plain)
        .onHover { hovering in
            withAnimation(.easeInOut(duration: 0.15)) {
                isHovered = hovering
            }
        }
        .simultaneousGesture(TapGesture(count: 2).onEnded {
            onDoubleTap()
        })
    }
}

// MARK: - Dark Track Row

struct DarkTrackRow: View {
    let track: Track
    let isSelected: Bool
    var isNowPlaying: Bool = false
    var onTap: () -> Void = {}
    var onDoubleTap: () -> Void = {}

    @State private var isHovered = false

    var body: some View {
        let colors = track.gradientColors

        Button(action: onTap) {
            HStack(spacing: Spacing.md) {
                // Thumbnail with curated gradient
                ZStack {
                    RoundedRectangle(cornerRadius: 8)
                        .fill(
                            LinearGradient(
                                colors: [colors.0, colors.1],
                                startPoint: .topLeading,
                                endPoint: .bottomTrailing
                            )
                        )
                        .frame(width: 40, height: 40)

                    if isNowPlaying && !isHovered {
                        NowPlayingIndicator(barCount: 3, barWidth: 3, height: 16)
                    } else {
                        Image(systemName: "waveform")
                            .font(.system(size: 15))
                            .foregroundStyle(.white.opacity(0.6))
                    }

                    if isHovered {
                        RoundedRectangle(cornerRadius: 8)
                            .fill(Color.black.opacity(0.35))
                            .frame(width: 40, height: 40)

                        Image(systemName: "play.fill")
                            .font(.system(size: 14))
                            .foregroundStyle(.white)
                    }
                }

                // Info
                VStack(alignment: .leading, spacing: 2) {
                    HStack(spacing: Spacing.sm) {
                        Text(track.displayTitle)
                            .font(Typography.bodyMedium)
                            .foregroundStyle(isNowPlaying ? Theme.accentPrimary : Theme.textPrimary)
                            .lineLimit(1)

                        if track.isCover {
                            Image(systemName: "arrow.triangle.2.circlepath.circle.fill")
                                .font(.system(size: 12))
                                .foregroundStyle(Theme.accentPrimary)
                        } else if track.isExtended {
                            Image(systemName: "arrow.forward.to.line.circle.fill")
                                .font(.system(size: 12))
                                .foregroundStyle(Theme.accentPrimary)
                        }

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
                    .lineLimit(1)
                    .truncationMode(.tail)
                    .frame(width: 170, alignment: .trailing)
            }
            .padding(.horizontal, Spacing.md)
            .padding(.vertical, 6)
            .background(
                RoundedRectangle(cornerRadius: Spacing.radiusSm)
                    .fill(
                        isNowPlaying
                            ? Theme.accentPrimary.opacity(0.08)
                            : (isSelected ? Theme.accentPrimary.opacity(0.1) : (isHovered ? Theme.backgroundTertiary : Color.clear))
                    )
            )
            .overlay(
                RoundedRectangle(cornerRadius: Spacing.radiusSm)
                    .strokeBorder(
                        isNowPlaying
                            ? Theme.accentPrimary.opacity(0.4)
                            : (isSelected ? Theme.accentPrimary.opacity(0.5) : Color.clear),
                        lineWidth: 1
                    )
            )
        }
        .buttonStyle(.plain)
        .onHover { hovering in
            withAnimation(.easeInOut(duration: 0.1)) {
                isHovered = hovering
            }
        }
        .simultaneousGesture(TapGesture(count: 2).onEnded {
            onDoubleTap()
        })
    }
}

// MARK: - Favorites View

struct FavoritesView: View {
    @EnvironmentObject var appState: AppState
    @State private var localSelection: Track?
    @State private var showDetail = false
    @State private var playbackIsPlaying = false

    var favorites: [Track] {
        appState.tracks.filter { $0.isFavorite }
    }

    private var selectedFavoriteTrack: Track? {
        guard let id = localSelection?.id else { return nil }
        return favorites.first(where: { $0.id == id })
    }

    var body: some View {
        Group {
            if showDetail, let selected = selectedFavoriteTrack {
                TrackDetailPanel(track: selected) {
                    withAnimation(.easeInOut(duration: 0.2)) {
                        showDetail = false
                    }
                }
                .transition(.move(edge: .trailing).combined(with: .opacity))
            } else {
                favoritesList
            }
        }
        .background(Theme.background)
        .onChange(of: favorites.map(\.id)) {
            guard let selected = localSelection else { return }
            guard !favorites.contains(where: { $0.id == selected.id }) else { return }
            localSelection = nil
            showDetail = false
        }
        .onAppear {
            playbackIsPlaying = appState.audioPlayer.isPlaying
        }
        .onReceive(appState.audioPlayer.$isPlaying) { isPlaying in
            playbackIsPlaying = isPlaying
        }
    }

    private var favoritesList: some View {
        VStack(spacing: 0) {
            HStack {
                VStack(alignment: .leading, spacing: Spacing.xs) {
                    Text("Favorites")
                        .title1Text()

                    Text("\(favorites.count) \(favorites.count == 1 ? "track" : "tracks")")
                        .font(Typography.caption)
                        .foregroundStyle(Theme.textTertiary)
                }

                Spacer()
            }
            .padding(.horizontal, Spacing.lg)
            .padding(.vertical, Spacing.md)
            .background(Theme.backgroundSecondary)

            if favorites.isEmpty {
                emptyFavoritesState
            } else {
                ScrollView {
                    VStack(spacing: Spacing.xs) {
                        ForEach(favorites) { track in
                            HStack(spacing: Spacing.sm) {
                                DarkTrackRow(
                                    track: track,
                                    isSelected: localSelection?.id == track.id,
                                    isNowPlaying: playbackIsPlaying && appState.audioPlayer.isCurrentTrack(track.audioURL),
                                    onTap: {
                                        localSelection = track
                                        appState.selectedTrack = track
                                        withAnimation(.easeInOut(duration: 0.2)) {
                                            showDetail = true
                                        }
                                    },
                                    onDoubleTap: {
                                        appState.playTrack(track)
                                    }
                                )
                                .contextMenu {
                                    Button {
                                        appState.toggleFavorite(track)
                                    } label: {
                                        Label("Remove from Favorites", systemImage: "heart.slash")
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

                                Button {
                                    togglePlay(for: track)
                                } label: {
                                    Image(systemName: playIcon(for: track))
                                        .font(.system(size: 14, weight: .semibold))
                                        .foregroundStyle(Theme.textPrimary)
                                        .frame(width: 32, height: 32)
                                        .background(
                                            Circle()
                                                .fill(Theme.backgroundTertiary)
                                        )
                                }
                                .buttonStyle(.plain)
                                .help(playHelpText(for: track))
                            }
                        }
                    }
                    .padding(.horizontal, Spacing.lg)
                    .padding(.vertical, Spacing.md)
                }
            }
        }
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

    private func playIcon(for track: Track) -> String {
        let isCurrent = appState.audioPlayer.isCurrentTrack(track.audioURL)
        return isCurrent && playbackIsPlaying ? "pause.fill" : "play.fill"
    }

    private func playHelpText(for track: Track) -> String {
        let isCurrent = appState.audioPlayer.isCurrentTrack(track.audioURL)
        return isCurrent && playbackIsPlaying ? "Pause track" : "Play track"
    }

    private func togglePlay(for track: Track) {
        if appState.audioPlayer.isCurrentTrack(track.audioURL) {
            appState.togglePlayPause()
        } else {
            appState.playTrack(track)
        }
        playbackIsPlaying = appState.audioPlayer.isPlaying
    }
}

// MARK: - Now Playing Indicator (animated equalizer bars)

struct NowPlayingIndicator: View {
    var barCount: Int = 4
    var barWidth: CGFloat = 3
    var height: CGFloat = 20
    var color: Color = .white

    @State private var animating = false

    var body: some View {
        HStack(spacing: 2) {
            ForEach(0..<barCount, id: \.self) { index in
                RoundedRectangle(cornerRadius: barWidth / 2)
                    .fill(color)
                    .frame(width: barWidth, height: animating ? barHeight(for: index) : height * 0.3)
                    .animation(
                        .easeInOut(duration: barDuration(for: index))
                            .repeatForever(autoreverses: true),
                        value: animating
                    )
            }
        }
        .frame(height: height)
        .onAppear { animating = true }
    }

    private func barHeight(for index: Int) -> CGFloat {
        let heights: [CGFloat] = [0.9, 0.6, 1.0, 0.7]
        return height * heights[index % heights.count]
    }

    private func barDuration(for index: Int) -> Double {
        let durations: [Double] = [0.45, 0.55, 0.35, 0.5]
        return durations[index % durations.count]
    }
}

#if PREVIEWS
#Preview {
    LibraryView()
        .environmentObject(AppState())
}
#endif
