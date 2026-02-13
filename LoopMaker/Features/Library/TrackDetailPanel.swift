import SwiftUI
import AppKit

/// Full-screen detail view for a selected track
struct TrackDetailPanel: View {
    @EnvironmentObject var appState: AppState
    let track: Track
    var onBack: () -> Void = {}

    @State private var editingTitle = false
    @State private var titleText = ""
    @State private var showDeleteConfirmation = false
    @State private var didCopyPrompt = false

    private var currentTrack: Track {
        appState.tracks.first(where: { $0.id == track.id }) ?? track
    }

    var body: some View {
        ZStack {
            atmosphericBackground

            VStack(spacing: 0) {
                topBar

                ScrollView {
                    VStack(spacing: Spacing.xl) {
                        heroSection
                        contentSections
                    }
                    .frame(maxWidth: 1_020)
                    .padding(.horizontal, Spacing.xl)
                    .padding(.top, Spacing.md)
                    .padding(.bottom, Spacing.xxxl)
                    .frame(maxWidth: .infinity)
                }
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(Theme.background)
        .onAppear {
            titleText = currentTrack.title ?? ""
        }
        .onChange(of: currentTrack.id) {
            titleText = currentTrack.title ?? ""
            editingTitle = false
            didCopyPrompt = false
        }
        .alert("Delete Track?", isPresented: $showDeleteConfirmation) {
            Button("Cancel", role: .cancel) {}
            Button("Delete", role: .destructive) {
                appState.deleteTrack(currentTrack)
                onBack()
            }
        } message: {
            Text("This will permanently delete \"\(currentTrack.displayTitle)\" and its audio file.")
        }
    }

    private var atmosphericBackground: some View {
        let colors = currentTrack.gradientColors

        return ZStack {
            Theme.background

            RadialGradient(
                colors: [
                    colors.0.opacity(0.24),
                    colors.1.opacity(0.12),
                    .clear
                ],
                center: .topTrailing,
                startRadius: 30,
                endRadius: 760
            )

            LinearGradient(
                colors: [
                    Color.black.opacity(0.08),
                    .clear,
                    Color.black.opacity(0.08)
                ],
                startPoint: .top,
                endPoint: .bottom
            )
        }
        .ignoresSafeArea()
    }

    // MARK: - Top Bar

    private var topBar: some View {
        GlassEffectContainer(spacing: Spacing.sm) {
            HStack(spacing: Spacing.md) {
                Button {
                    onBack()
                } label: {
                    HStack(spacing: Spacing.xs) {
                        Image(systemName: "chevron.left")
                            .font(.system(size: 13, weight: .semibold))
                        Text("Library")
                            .font(Typography.bodyMedium)
                    }
                    .foregroundStyle(Theme.textPrimary)
                    .padding(.horizontal, 12)
                    .padding(.vertical, 7)
                    .glassEffect(
                        .regular.tint(Theme.accentPrimary.opacity(0.16)).interactive(),
                        in: Capsule()
                    )
                }
                .buttonStyle(.plain)

                Spacer(minLength: 0)

                Button {
                    appState.toggleFavorite(currentTrack)
                } label: {
                    Image(systemName: currentTrack.isFavorite ? "heart.fill" : "heart")
                        .font(.system(size: 15, weight: .semibold))
                        .foregroundStyle(currentTrack.isFavorite ? Theme.error : Theme.textPrimary)
                        .frame(width: 34, height: 34)
                        .glassEffect(
                            .regular.tint(currentTrack.isFavorite ? Theme.error.opacity(0.2) : Theme.accentPrimary.opacity(0.12)).interactive(),
                            in: Circle()
                        )
                }
                .buttonStyle(.plain)
                .help(currentTrack.isFavorite ? "Remove from favorites" : "Add to favorites")
            }
        }
        .padding(.horizontal, Spacing.xl)
        .padding(.top, Spacing.md)
        .padding(.bottom, Spacing.sm)
    }

    // MARK: - Hero

    private var heroSection: some View {
        let colors = currentTrack.gradientColors

        return ZStack(alignment: .bottomLeading) {
            RoundedRectangle(cornerRadius: Spacing.radiusXl)
                .fill(
                    LinearGradient(
                        colors: [colors.0, colors.1],
                        startPoint: .topLeading,
                        endPoint: .bottomTrailing
                    )
                )

            RoundedRectangle(cornerRadius: Spacing.radiusXl)
                .fill(.linearGradient(
                    colors: [Color.black.opacity(0.06), Color.black.opacity(0.28)],
                    startPoint: .top,
                    endPoint: .bottom
                ))

            Circle()
                .fill(Color.white.opacity(0.12))
                .frame(width: 260, height: 260)
                .blur(radius: 24)
                .offset(x: 90, y: -100)

            VStack(alignment: .leading, spacing: Spacing.lg) {
                heroTopRow

                Spacer(minLength: 0)

                VStack(alignment: .leading, spacing: Spacing.sm) {
                    heroTitleRow

                    Text(currentTrack.formattedDate)
                        .font(Typography.caption)
                        .foregroundStyle(.white.opacity(0.82))
                }
            }
            .padding(Spacing.xl)

            Image(systemName: heroSymbol)
                .font(.system(size: 96, weight: .light))
                .foregroundStyle(.white.opacity(0.22))
                .padding(.trailing, Spacing.xxl)
                .padding(.bottom, Spacing.xl)
                .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .bottomTrailing)
        }
        .frame(height: 286)
        .shadow(color: Color.black.opacity(0.22), radius: 30, y: 14)
    }

    private var heroTopRow: some View {
        HStack(alignment: .center, spacing: Spacing.sm) {
            HStack(spacing: Spacing.xs) {
                if currentTrack.isCover || currentTrack.isExtended {
                    Image(systemName: currentTrack.isCover ? "arrow.triangle.2.circlepath" : "arrow.forward.to.line")
                        .font(.system(size: 10, weight: .semibold))
                } else {
                    Image(systemName: "waveform")
                        .font(.system(size: 10, weight: .semibold))
                }

                Text(currentTrack.isCover ? "Cover" : currentTrack.isExtended ? "Extended" : "Generated")
                    .font(Typography.captionSemibold)
            }
            .foregroundStyle(.white.opacity(0.94))
            .padding(.horizontal, 10)
            .padding(.vertical, 5)
            .background(
                Capsule()
                    .fill(Color.white.opacity(0.2))
            )

            Spacer(minLength: 0)

            Text(currentTrack.duration.displayName)
                .font(Typography.captionSemibold)
                .foregroundStyle(.white)
                .padding(.horizontal, 10)
                .padding(.vertical, 5)
                .background(
                    Capsule()
                        .fill(Color.white.opacity(0.2))
                )
        }
    }

    private var heroTitleRow: some View {
        HStack(alignment: .top, spacing: Spacing.sm) {
            if editingTitle {
                TextField("Title", text: $titleText, onCommit: {
                    appState.renameTrack(currentTrack, newTitle: titleText)
                    editingTitle = false
                })
                .font(Typography.displayMedium)
                .foregroundStyle(.white)
                .textFieldStyle(.plain)
                .onExitCommand {
                    editingTitle = false
                }
            } else {
                Text(currentTrack.displayTitle)
                    .font(Typography.displayMedium)
                    .foregroundStyle(.white)
                    .lineLimit(2)
                    .minimumScaleFactor(0.85)
                    .onTapGesture(count: 2) {
                        titleText = currentTrack.title ?? currentTrack.prompt
                        editingTitle = true
                    }
            }

            Button {
                titleText = currentTrack.title ?? currentTrack.prompt
                editingTitle = true
            } label: {
                Image(systemName: "pencil")
                    .font(.system(size: 12, weight: .semibold))
                    .foregroundStyle(.white.opacity(0.9))
                    .frame(width: 30, height: 30)
                    .background(
                        RoundedRectangle(cornerRadius: 8)
                            .fill(Color.white.opacity(0.14))
                    )
            }
            .buttonStyle(.plain)
            .help("Rename track")
        }
    }

    private var heroSymbol: String {
        if currentTrack.isCover {
            return "arrow.triangle.2.circlepath"
        }
        if currentTrack.isExtended {
            return "arrow.forward.to.line"
        }
        return "waveform"
    }

    // MARK: - Content

    private var contentSections: some View {
        ViewThatFits(in: .horizontal) {
            HStack(alignment: .top, spacing: Spacing.lg) {
                leftColumn
                    .frame(maxWidth: .infinity, alignment: .leading)

                rightColumn
                    .frame(width: 350)
            }

            VStack(spacing: Spacing.lg) {
                leftColumn
                rightColumn
            }
        }
    }

    private var leftColumn: some View {
        VStack(spacing: Spacing.lg) {
            promptCard

            if currentTrack.hasLyrics {
                lyricsCard
            }
        }
    }

    private var rightColumn: some View {
        VStack(spacing: Spacing.lg) {
            metadataCard
            generationCard
            utilityCard
        }
    }

    // MARK: - Cards

    private var promptCard: some View {
        sectionCard {
            VStack(alignment: .leading, spacing: Spacing.md) {
                HStack {
                    Text("Prompt")
                        .sectionHeaderStyle()

                    Spacer(minLength: 0)

                    Button {
                        copyPromptToClipboard()
                    } label: {
                        Image(systemName: didCopyPrompt ? "checkmark" : "doc.on.doc")
                            .font(.system(size: 12, weight: .medium))
                            .foregroundStyle(didCopyPrompt ? Theme.accentPrimary : Theme.textTertiary)
                            .frame(width: 26, height: 26)
                            .glassEffect(
                                .regular.tint(Theme.accentPrimary.opacity(0.08)).interactive(),
                                in: Circle()
                            )
                    }
                    .buttonStyle(.plain)
                    .help(didCopyPrompt ? "Copied" : "Copy prompt")
                }

                Text(currentTrack.prompt)
                    .font(Typography.body)
                    .foregroundStyle(Theme.textSecondary)
                    .lineSpacing(4)
                    .textSelection(.enabled)
            }
        }
    }

    private var lyricsCard: some View {
        sectionCard {
            VStack(alignment: .leading, spacing: Spacing.md) {
                Text("Lyrics")
                    .sectionHeaderStyle()

                Text(currentTrack.lyrics ?? "")
                    .font(Typography.body)
                    .foregroundStyle(Theme.textSecondary)
                    .lineSpacing(4)
                    .textSelection(.enabled)
            }
        }
    }

    private var metadataCard: some View {
        sectionCard {
            VStack(alignment: .leading, spacing: Spacing.md) {
                Text("Details")
                    .sectionHeaderStyle()

                VStack(spacing: Spacing.sm) {
                    MetadataRow(label: "Duration", value: currentTrack.duration.displayName, icon: "clock")
                    MetadataRow(label: "Created", value: currentTrack.formattedDate, icon: "calendar")

                    if currentTrack.isCover || currentTrack.isExtended {
                        MetadataRow(
                            label: "Type",
                            value: currentTrack.isCover ? "Cover" : "Extended",
                            icon: currentTrack.isCover ? "arrow.triangle.2.circlepath" : "arrow.forward.to.line"
                        )
                    }

                    if let bpm = currentTrack.bpm {
                        MetadataRow(label: "BPM", value: "\(bpm)", icon: "metronome", mono: true)
                    }

                    if let key = currentTrack.musicKey {
                        MetadataRow(label: "Key", value: key, icon: "music.note")
                    }

                    if let timeSig = currentTrack.timeSignature {
                        MetadataRow(label: "Time Sig", value: timeSig, icon: "music.quarternote.3")
                    }
                }
            }
        }
    }

    private var generationCard: some View {
        sectionCard {
            VStack(alignment: .leading, spacing: Spacing.md) {
                Text("Continue")
                    .sectionHeaderStyle()

                GlassEffectContainer(spacing: Spacing.sm) {
                    Button {
                        appState.playTrack(currentTrack)
                    } label: {
                        HStack(spacing: 8) {
                            Image(systemName: "play.fill")
                                .font(.system(size: 12, weight: .semibold))
                            Text("Play")
                                .font(Typography.bodySemibold)
                        }
                        .foregroundStyle(.white)
                        .frame(maxWidth: .infinity)
                        .frame(height: 42)
                        .background(
                            RoundedRectangle(cornerRadius: Spacing.radiusSm)
                                .fill(Theme.accentPrimary)
                        )
                    }
                    .buttonStyle(.plain)

                    Button {
                        queuePrefill(prefillRequest(for: .text2music))
                    } label: {
                        actionLabel(title: "Create More Like This", icon: "sparkles", trailingIcon: "arrow.up.right")
                    }
                    .buttonStyle(.plain)
                    .help("Open Generate with this track's settings")

                    HStack(spacing: Spacing.sm) {
                        Button {
                            queuePrefill(prefillRequest(for: .cover))
                        } label: {
                            compactActionLabel(title: "Remix", icon: "arrow.triangle.2.circlepath")
                        }
                        .buttonStyle(.plain)
                        .help("Create a remix using this track as source audio")

                        Button {
                            queuePrefill(prefillRequest(for: .extend))
                        } label: {
                            compactActionLabel(title: "Extend", icon: "arrow.forward.to.line")
                        }
                        .buttonStyle(.plain)
                        .help("Continue this track with extend mode")
                    }
                }
            }
        }
    }

    private var utilityCard: some View {
        sectionCard {
            HStack(spacing: Spacing.sm) {
                Button {
                    appState.selectedTrack = currentTrack
                    appState.showExport = true
                } label: {
                    utilityLabel(title: "Export", icon: "square.and.arrow.up")
                }
                .buttonStyle(.plain)

                Button {
                    showDeleteConfirmation = true
                } label: {
                    utilityLabel(title: "Delete", icon: "trash", tint: Theme.error, isDestructive: true)
                }
                .buttonStyle(.plain)
            }
        }
    }

    private func sectionCard<Content: View>(@ViewBuilder content: () -> Content) -> some View {
        content()
            .padding(Spacing.lg)
            .frame(maxWidth: .infinity, alignment: .leading)
            .glassEffect(
                .regular,
                in: RoundedRectangle(cornerRadius: Spacing.radiusLg)
            )
    }

    private func actionLabel(title: String, icon: String, trailingIcon: String? = nil) -> some View {
        HStack(spacing: 8) {
            Image(systemName: icon)
                .font(.system(size: 12, weight: .semibold))

            Text(title)
                .font(Typography.captionMedium)

            Spacer(minLength: 0)

            if let trailingIcon {
                Image(systemName: trailingIcon)
                    .font(.system(size: 10, weight: .semibold))
            }
        }
        .foregroundStyle(Theme.textPrimary)
        .padding(.horizontal, 12)
        .frame(maxWidth: .infinity, minHeight: 38, alignment: .leading)
        .glassEffect(
            .regular.tint(Theme.accentPrimary.opacity(0.14)).interactive(),
            in: RoundedRectangle(cornerRadius: Spacing.radiusSm)
        )
    }

    private func compactActionLabel(title: String, icon: String) -> some View {
        HStack(spacing: 6) {
            Image(systemName: icon)
                .font(.system(size: 11, weight: .semibold))

            Text(title)
                .font(Typography.captionMedium)
                .lineLimit(1)
        }
        .foregroundStyle(Theme.textPrimary)
        .frame(maxWidth: .infinity)
        .frame(height: 36)
        .glassEffect(
            .regular.tint(Theme.accentPrimary.opacity(0.12)).interactive(),
            in: RoundedRectangle(cornerRadius: Spacing.radiusSm)
        )
    }

    private func utilityLabel(
        title: String,
        icon: String,
        tint: Color = Theme.textSecondary,
        isDestructive: Bool = false
    ) -> some View {
        HStack(spacing: 6) {
            Image(systemName: icon)
                .font(.system(size: 11, weight: .semibold))

            Text(title)
                .font(Typography.captionMedium)
        }
        .foregroundStyle(tint)
        .frame(maxWidth: .infinity)
        .frame(height: 34)
        .background(
            RoundedRectangle(cornerRadius: Spacing.radiusSm)
                .fill(
                    isDestructive
                        ? Theme.error.opacity(0.12)
                        : Color.primary.opacity(0.06)
                )
        )
    }

    private func queuePrefill(_ request: GenerationRequest) {
        appState.prefillRequest = request
        appState.showNewGeneration = true
        onBack()
    }

    private func copyPromptToClipboard() {
        let pasteboard = NSPasteboard.general
        pasteboard.clearContents()

        // Fallback declaration helps when pasteboard has stale owners/types.
        if !pasteboard.setString(currentTrack.prompt, forType: .string) {
            pasteboard.declareTypes([.string], owner: nil)
            _ = pasteboard.setString(currentTrack.prompt, forType: .string)
        }

        withAnimation(.easeInOut(duration: 0.15)) {
            didCopyPrompt = true
        }

        Task { @MainActor in
            try? await Task.sleep(nanoseconds: 1_200_000_000)
            withAnimation(.easeInOut(duration: 0.15)) {
                didCopyPrompt = false
            }
        }
    }

    private func prefillRequest(for taskType: GenerationTaskType) -> GenerationRequest {
        let trackLyrics = currentTrack.lyrics?.trimmingCharacters(in: .whitespacesAndNewlines)
        let mappedLyrics: String?
        switch taskType {
        case .cover:
            if let trackLyrics {
                if trackLyrics.isEmpty {
                    mappedLyrics = ""
                } else if trackLyrics == "[inst]" {
                    mappedLyrics = "[inst]"
                } else {
                    mappedLyrics = trackLyrics
                }
            } else {
                mappedLyrics = "[inst]"
            }
        case .text2music, .extend:
            if let trackLyrics, !trackLyrics.isEmpty, trackLyrics != "[inst]" {
                mappedLyrics = trackLyrics
            } else {
                mappedLyrics = nil
            }
        }

        let parsedQualityMode: QualityMode
        if let rawQuality = currentTrack.qualityMode,
           let quality = QualityMode(rawValue: rawQuality) {
            parsedQualityMode = quality
        } else {
            parsedQualityMode = .fast
        }

        return GenerationRequest(
            prompt: currentTrack.prompt,
            duration: currentTrack.duration,
            model: currentTrack.model,
            seed: currentTrack.seed,
            lyrics: mappedLyrics,
            qualityMode: parsedQualityMode,
            guidanceScale: currentTrack.guidanceScale ?? 7.0,
            taskType: taskType,
            sourceAudioURL: taskType == .text2music ? nil : currentTrack.audioURL,
            refAudioStrength: 0.5,
            sourceTrack: taskType == .extend ? currentTrack : nil,
            batchSize: 1,
            bpm: currentTrack.bpm,
            musicKey: currentTrack.musicKey,
            timeSignature: currentTrack.timeSignature
        )
    }
}

// MARK: - Metadata Row

private struct MetadataRow: View {
    let label: String
    let value: String
    let icon: String
    var mono: Bool = false

    var body: some View {
        HStack(spacing: Spacing.sm) {
            Image(systemName: icon)
                .font(.system(size: 11, weight: .medium))
                .foregroundStyle(Theme.textTertiary)
                .frame(width: 14)

            Text(label)
                .font(Typography.caption)
                .foregroundStyle(Theme.textTertiary)
                .frame(width: 64, alignment: .leading)

            Text(value)
                .font(mono ? Typography.monoSmall : Typography.captionMedium)
                .foregroundStyle(Theme.textPrimary)
                .textSelection(.enabled)

            Spacer(minLength: 0)
        }
    }
}
