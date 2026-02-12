import SwiftUI

struct GenerationView: View {
    @EnvironmentObject var appState: AppState
    @State private var prompt = ""
    @State private var selectedDuration: TrackDuration = .medium
    @State private var selectedGenreCard: GenreCardData?
    @State private var isInstrumental = true
    @State private var lyrics = ""
    @State private var selectedQualityMode: QualityMode = .fast
    @State private var suggestions: [SuggestionData] = SuggestionData.randomSet()
    @State private var showAdvanced = false

    // Cover mode state
    @State private var taskType: GenerationTaskType = .text2music
    @State private var sourceAudioURL: URL?
    @State private var coverVocalsMode: CoverVocalsMode = .instrumental
    @State private var refAudioStrength: Double = 0.5
    @State private var isDropTargeted = false

    var body: some View {
        ScrollView {
            VStack(spacing: Spacing.xl) {
                // Main creation card: prompt + essential controls + create
                creationCard

                // Progress (when generating)
                if appState.isGenerating {
                    progressSection
                }

                // Suggestions (when not generating)
                if !appState.isGenerating {
                    suggestionsSection
                }
            }
            .padding(.horizontal, Spacing.xl)
            .padding(.vertical, Spacing.lg)
        }
    }

    // MARK: - Creation Card (prompt + controls + create, all in one card)

    private var creationCard: some View {
        VStack(alignment: .leading, spacing: 0) {
            // Mode toggle: Generate / Cover
            modeToggle
                .padding(Spacing.md)

            Rectangle()
                .fill(Color.primary.opacity(0.06))
                .frame(height: 1)

            // Audio drop zone (cover mode only)
            if taskType == .cover {
                audioDropZone
                    .padding(Spacing.md)

                Rectangle()
                    .fill(Color.primary.opacity(0.06))
                    .frame(height: 1)
            }

            // Prompt area
            VStack(alignment: .leading, spacing: Spacing.sm) {
                HStack(spacing: 6) {
                    Image(systemName: "wand.and.stars")
                        .font(.system(size: 13, weight: .medium))
                        .foregroundStyle(DesignSystem.Colors.accent)

                    Text(taskType == .cover ? "Style Description" : "Music Description")
                        .font(Typography.captionMedium)
                        .foregroundStyle(DesignSystem.Colors.textSecondary)

                    Spacer()

                    if !prompt.isEmpty {
                        Text("\(prompt.count)")
                            .font(Typography.caption2)
                            .foregroundStyle(DesignSystem.Colors.textMuted)
                    }
                }

                TextEditor(text: $prompt)
                    .font(Typography.body)
                    .foregroundStyle(DesignSystem.Colors.textPrimary)
                    .scrollContentBackground(.hidden)
                    .frame(minHeight: 72, maxHeight: 120)
                    .overlay(alignment: .topLeading) {
                        if prompt.isEmpty {
                            Text(promptPlaceholder)
                                .font(Typography.body)
                                .foregroundStyle(DesignSystem.Colors.textMuted)
                                .padding(.top, 8)
                                .padding(.leading, 4)
                                .allowsHitTesting(false)
                        }
                    }
            }
            .padding(Spacing.md)

            // Divider
            Rectangle()
                .fill(Color.primary.opacity(0.06))
                .frame(height: 1)

            // Controls footer: mode + duration + advanced toggle + create
            VStack(spacing: Spacing.md) {
                HStack(spacing: Spacing.sm) {
                    // Vocals mode pills (different for cover vs generate)
                    if taskType == .cover {
                        coverVocalsPills
                    } else {
                        InlinePill(
                            title: "Instrumental",
                            icon: "pianokeys",
                            isSelected: isInstrumental,
                            action: { isInstrumental = true }
                        )

                        InlinePill(
                            title: "Lyrics",
                            icon: "music.mic",
                            isSelected: !isInstrumental,
                            action: { isInstrumental = false }
                        )
                    }

                    Spacer()

                    // Duration
                    HStack(spacing: Spacing.xs) {
                        ForEach(availableDurations, id: \.self) { duration in
                            ZStack {
                                DurationChip(
                                    duration: duration,
                                    isSelected: selectedDuration == duration,
                                    action: {
                                        if !duration.requiresPro || appState.isProUser {
                                            selectedDuration = duration
                                        }
                                    }
                                )

                                if duration.requiresPro && !appState.isProUser {
                                    FeatureLockOverlay(feature: .extendedDuration)
                                }
                            }
                        }
                    }

                    // Advanced toggle
                    Button {
                        withAnimation(.easeInOut(duration: 0.2)) {
                            showAdvanced.toggle()
                        }
                    } label: {
                        Image(systemName: "slider.horizontal.3")
                            .font(.system(size: 14))
                            .foregroundStyle(showAdvanced ? DesignSystem.Colors.accent : DesignSystem.Colors.textSecondary)
                            .frame(width: 32, height: 32)
                            .background(
                                RoundedRectangle(cornerRadius: 6)
                                    .fill(showAdvanced ? DesignSystem.Colors.accent.opacity(0.12) : Color.clear)
                            )
                    }
                    .buttonStyle(.plain)
                    .help("More options")
                }

                // Advanced options (collapsed by default)
                if showAdvanced {
                    advancedOptions
                }

                // Lyrics section
                if taskType == .cover && coverVocalsMode == .newLyrics {
                    lyricsSection
                } else if taskType == .text2music && !isInstrumental {
                    lyricsSection
                }

                // Create button
                generateButton
            }
            .padding(Spacing.md)
        }
        .background(
            RoundedRectangle(cornerRadius: Spacing.radiusMd)
                .fill(Color.primary.opacity(0.04))
        )
        .overlay(
            RoundedRectangle(cornerRadius: Spacing.radiusMd)
                .strokeBorder(Color.primary.opacity(0.06), lineWidth: 1)
        )
    }

    // MARK: - Mode Toggle (Generate / Cover)

    private var modeToggle: some View {
        HStack(spacing: Spacing.sm) {
            InlinePill(
                title: GenerationTaskType.text2music.displayName,
                icon: GenerationTaskType.text2music.icon,
                isSelected: taskType == .text2music,
                action: {
                    withAnimation(.easeInOut(duration: 0.2)) {
                        taskType = .text2music
                    }
                }
            )

            InlinePill(
                title: GenerationTaskType.cover.displayName,
                icon: GenerationTaskType.cover.icon,
                isSelected: taskType == .cover,
                action: {
                    withAnimation(.easeInOut(duration: 0.2)) {
                        taskType = .cover
                    }
                }
            )

            Spacer()
        }
    }

    // MARK: - Audio Drop Zone (cover mode)

    private var audioDropZone: some View {
        Group {
            if let url = sourceAudioURL {
                // Selected file display
                HStack(spacing: Spacing.sm) {
                    Image(systemName: "waveform.circle.fill")
                        .font(.system(size: 24))
                        .foregroundStyle(DesignSystem.Colors.accent)

                    VStack(alignment: .leading, spacing: 2) {
                        Text(url.lastPathComponent)
                            .font(Typography.bodyMedium)
                            .foregroundStyle(DesignSystem.Colors.textPrimary)
                            .lineLimit(1)

                        Text("Source audio for cover")
                            .font(Typography.caption)
                            .foregroundStyle(DesignSystem.Colors.textMuted)
                    }

                    Spacer()

                    Button {
                        sourceAudioURL = nil
                    } label: {
                        Image(systemName: "xmark.circle.fill")
                            .font(.system(size: 16))
                            .foregroundStyle(DesignSystem.Colors.textMuted)
                    }
                    .buttonStyle(.plain)
                }
                .padding(Spacing.md)
                .background(
                    RoundedRectangle(cornerRadius: Spacing.radiusSm)
                        .fill(DesignSystem.Colors.accent.opacity(0.08))
                )
                .overlay(
                    RoundedRectangle(cornerRadius: Spacing.radiusSm)
                        .strokeBorder(DesignSystem.Colors.accent.opacity(0.2), lineWidth: 1)
                )
            } else {
                // Drop zone / browse
                Button(action: browseAudio) {
                    VStack(spacing: Spacing.sm) {
                        Image(systemName: "arrow.down.doc")
                            .font(.system(size: 24))
                            .foregroundStyle(DesignSystem.Colors.textMuted)

                        Text("Drop audio or click to browse")
                            .font(Typography.captionMedium)
                            .foregroundStyle(DesignSystem.Colors.textSecondary)

                        Text("WAV, MP3, M4A, FLAC")
                            .font(Typography.caption)
                            .foregroundStyle(DesignSystem.Colors.textMuted)
                    }
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, Spacing.lg)
                    .background(
                        RoundedRectangle(cornerRadius: Spacing.radiusSm)
                            .fill(isDropTargeted ? DesignSystem.Colors.accent.opacity(0.08) : Color.primary.opacity(0.03))
                    )
                    .overlay(
                        RoundedRectangle(cornerRadius: Spacing.radiusSm)
                            .strokeBorder(
                                isDropTargeted ? DesignSystem.Colors.accent : Color.primary.opacity(0.1),
                                style: StrokeStyle(lineWidth: 1.5, dash: [6, 4])
                            )
                    )
                }
                .buttonStyle(.plain)
                .onDrop(of: [.fileURL], isTargeted: $isDropTargeted) { providers in
                    handleAudioDrop(providers)
                }
            }
        }
    }

    // MARK: - Cover Vocals Pills

    private var coverVocalsPills: some View {
        ForEach(CoverVocalsMode.allCases, id: \.self) { mode in
            InlinePill(
                title: mode.displayName,
                icon: mode.icon,
                isSelected: coverVocalsMode == mode,
                action: {
                    withAnimation(.easeInOut(duration: 0.15)) {
                        coverVocalsMode = mode
                    }
                }
            )
        }
    }

    // MARK: - Advanced Options (collapsed by default)

    private var advancedOptions: some View {
        VStack(spacing: Spacing.md) {
            // Genre chips
            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: Spacing.sm) {
                    ForEach(GenreCardData.presets) { genre in
                        Button {
                            withAnimation(.easeInOut(duration: 0.15)) {
                                selectedGenreCard = genre
                            }
                            if let preset = GenrePreset.allPresets.first(where: { $0.name == genre.name }) {
                                prompt = preset.promptSuffix
                            }
                        } label: {
                            HStack(spacing: 6) {
                                Image(systemName: genre.icon)
                                    .font(.system(size: 11))
                                Text(genre.name)
                                    .font(Typography.captionMedium)
                            }
                            .foregroundStyle(selectedGenreCard?.id == genre.id ? .white : DesignSystem.Colors.textSecondary)
                            .padding(.horizontal, 10)
                            .padding(.vertical, 6)
                            .background(
                                Capsule()
                                    .fill(selectedGenreCard?.id == genre.id
                                        ? AnyShapeStyle(LinearGradient(
                                            colors: genre.gradientColors,
                                            startPoint: .leading,
                                            endPoint: .trailing
                                        ))
                                        : AnyShapeStyle(Color.primary.opacity(0.06)))
                            )
                        }
                        .buttonStyle(.plain)
                    }
                }
            }

            // Quality
            HStack {
                Label("Quality", systemImage: "cpu")
                    .font(Typography.captionMedium)
                    .foregroundStyle(DesignSystem.Colors.textSecondary)

                Spacer()

                HStack(spacing: Spacing.xs) {
                    ForEach(QualityMode.allCases, id: \.self) { mode in
                        QualityChip(
                            mode: mode,
                            isSelected: selectedQualityMode == mode,
                            action: { selectedQualityMode = mode }
                        )
                    }
                }
            }

            // Style Strength slider (cover mode only)
            if taskType == .cover {
                HStack {
                    Label("Style Strength", systemImage: "dial.medium")
                        .font(Typography.captionMedium)
                        .foregroundStyle(DesignSystem.Colors.textSecondary)

                    Slider(value: $refAudioStrength, in: 0.1...0.9, step: 0.1)
                        .tint(DesignSystem.Colors.accent)

                    Text(String(format: "%.0f%%", refAudioStrength * 100))
                        .font(Typography.captionMedium)
                        .foregroundStyle(DesignSystem.Colors.textPrimary)
                        .frame(width: 36, alignment: .trailing)
                }
            }
        }
        .padding(.top, 4)
        .transition(.opacity.combined(with: .move(edge: .top)))
    }

    // MARK: - Lyrics Section

    private var lyricsSection: some View {
        VStack(alignment: .leading, spacing: Spacing.sm) {
            HStack {
                Label("Lyrics", systemImage: "music.mic")
                    .font(Typography.captionMedium)
                    .foregroundStyle(DesignSystem.Colors.textSecondary)

                Spacer()

                HStack(spacing: Spacing.xs) {
                    LyricsTagButton(tag: "[verse]") { insertLyricsTag("[verse]") }
                    LyricsTagButton(tag: "[chorus]") { insertLyricsTag("[chorus]") }
                    LyricsTagButton(tag: "[bridge]") { insertLyricsTag("[bridge]") }
                }
            }

            TextEditor(text: $lyrics)
                .font(Typography.body)
                .foregroundStyle(DesignSystem.Colors.textPrimary)
                .scrollContentBackground(.hidden)
                .frame(minHeight: 80, maxHeight: 160)
                .padding(Spacing.sm)
                .background(
                    RoundedRectangle(cornerRadius: Spacing.radiusSm)
                        .fill(Color.primary.opacity(0.04))
                )

            Text("Use [verse], [chorus], [bridge] tags to structure your song")
                .font(Typography.caption)
                .foregroundStyle(DesignSystem.Colors.textMuted)
        }
    }

    private func insertLyricsTag(_ tag: String) {
        if lyrics.isEmpty {
            lyrics = tag + "\n"
        } else if !lyrics.hasSuffix("\n") {
            lyrics += "\n" + tag + "\n"
        } else {
            lyrics += tag + "\n"
        }
    }

    private var availableDurations: [TrackDuration] {
        TrackDuration.available(for: appState.selectedModel)
    }

    // MARK: - Generate Button

    private var generateButton: some View {
        Button(action: generate) {
            HStack(spacing: Spacing.sm) {
                if appState.isGenerating {
                    ProgressView()
                        .progressViewStyle(.circular)
                        .scaleEffect(0.8)
                        .frame(width: 18, height: 18)
                        .tint(.white)
                } else if case .downloading = appState.modelDownloadStates[appState.selectedModel] {
                    ProgressView()
                        .progressViewStyle(.circular)
                        .scaleEffect(0.8)
                        .frame(width: 18, height: 18)
                        .tint(.white)
                } else {
                    Image(systemName: taskType == .cover ? "arrow.triangle.2.circlepath" : "waveform")
                        .font(.system(size: 16, weight: .semibold))
                }

                Text(buttonTitle)
                    .font(Typography.headline)
            }
            .foregroundStyle(canGenerate ? .white : .secondary)
            .frame(maxWidth: .infinity)
            .frame(height: 44)
            .background(
                RoundedRectangle(cornerRadius: Spacing.radiusSm)
                    .fill(canGenerate ? AnyShapeStyle(DesignSystem.Colors.accent) : AnyShapeStyle(Color.primary.opacity(0.08)))
            )
        }
        .buttonStyle(.plain)
        .disabled(!canGenerate)
    }

    // MARK: - Progress Section

    private var progressSection: some View {
        VStack(spacing: Spacing.md) {
            GeometryReader { geometry in
                ZStack(alignment: .leading) {
                    RoundedRectangle(cornerRadius: 4)
                        .fill(Color.primary.opacity(0.06))
                        .frame(height: 6)

                    RoundedRectangle(cornerRadius: 4)
                        .fill(DesignSystem.Colors.accent)
                        .frame(width: geometry.size.width * appState.generationProgress, height: 6)
                        .animation(.easeInOut(duration: 0.3), value: appState.generationProgress)
                }
            }
            .frame(height: 6)

            HStack {
                Text(appState.generationStatus)
                    .font(Typography.caption)
                    .foregroundStyle(DesignSystem.Colors.textSecondary)

                Spacer()

                Text("\(Int(appState.generationProgress * 100))%")
                    .font(Typography.captionMedium)
                    .foregroundStyle(DesignSystem.Colors.textPrimary)
            }

            HStack {
                Image(systemName: "clock")
                    .font(.system(size: 11))
                    .foregroundStyle(DesignSystem.Colors.textMuted)

                Text(estimatedTimeText)
                    .font(Typography.caption)
                    .foregroundStyle(DesignSystem.Colors.textMuted)

                Spacer()

                Button {
                    appState.cancelGeneration()
                } label: {
                    Text("Cancel")
                        .font(Typography.captionMedium)
                        .foregroundStyle(DesignSystem.Colors.textSecondary)
                        .padding(.horizontal, 10)
                        .padding(.vertical, 4)
                        .background(
                            RoundedRectangle(cornerRadius: 6)
                                .fill(Color.primary.opacity(0.06))
                        )
                }
                .buttonStyle(.plain)
            }
        }
        .padding(Spacing.md)
        .background(
            RoundedRectangle(cornerRadius: Spacing.radiusMd)
                .fill(Color.primary.opacity(0.04))
        )
    }

    // MARK: - Suggestions

    private var suggestionsSection: some View {
        SuggestionGrid(
            suggestions: suggestions,
            onSelect: { suggestion in
                withAnimation(.easeInOut(duration: 0.2)) {
                    prompt = suggestion.subtitle
                    selectedGenreCard = nil
                }
            },
            onRefresh: {
                withAnimation(.easeInOut(duration: 0.2)) {
                    suggestions = SuggestionData.randomSet()
                }
            }
        )
    }

    private var estimatedTimeText: String {
        guard let request = appState.currentRequest else {
            return "Estimating..."
        }

        let estimate: String
        switch request.duration {
        case .short:     estimate = "1-2 minutes"
        case .medium:    estimate = "3-6 minutes"
        case .long:      estimate = "6-12 minutes"
        case .extended:  estimate = "12-20 minutes"
        case .maximum:   estimate = "20-40 minutes"
        }

        return "Estimated time: \(estimate)"
    }

    // MARK: - Helpers

    private var canGenerate: Bool {
        let hasPrompt = !prompt.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
        let hasSource = taskType == .text2music || sourceAudioURL != nil
        return hasPrompt && hasSource && appState.canGenerate
    }

    private var buttonTitle: String {
        if appState.isGenerating {
            return "Generating..."
        }
        if case .downloading = appState.modelDownloadStates[appState.selectedModel] {
            return "Downloading Model..."
        }
        return taskType == .cover ? "Create Cover" : "Create"
    }

    private var promptPlaceholder: String {
        taskType == .cover
            ? "Describe the style for your cover..."
            : "Describe the music you want to create..."
    }

    private func generate() {
        let effectiveLyrics: String?

        if taskType == .cover {
            switch coverVocalsMode {
            case .keep:
                effectiveLyrics = nil
            case .instrumental:
                effectiveLyrics = nil
            case .newLyrics:
                effectiveLyrics = lyrics.isEmpty ? nil : lyrics
            }
        } else {
            effectiveLyrics = isInstrumental ? nil : (lyrics.isEmpty ? nil : lyrics)
        }

        let request = GenerationRequest(
            prompt: prompt,
            duration: selectedDuration,
            model: appState.selectedModel,
            lyrics: effectiveLyrics,
            qualityMode: selectedQualityMode,
            taskType: taskType,
            sourceAudioURL: sourceAudioURL,
            refAudioStrength: refAudioStrength
        )
        appState.startGeneration(request: request)
    }

    // MARK: - Audio File Handling

    private func browseAudio() {
        let panel = NSOpenPanel()
        panel.allowedContentTypes = [.audio, .wav, .mp3, .mpeg4Audio]
        panel.allowsMultipleSelection = false
        panel.canChooseDirectories = false
        panel.message = "Select an audio file to use as cover source"

        if panel.runModal() == .OK {
            sourceAudioURL = panel.url
        }
    }

    private func handleAudioDrop(_ providers: [NSItemProvider]) -> Bool {
        guard let provider = providers.first else { return false }

        _ = provider.loadObject(ofClass: URL.self) { url, _ in
            guard let url else { return }
            let audioExtensions = ["wav", "mp3", "m4a", "flac", "aac", "aiff"]
            if audioExtensions.contains(url.pathExtension.lowercased()) {
                DispatchQueue.main.async {
                    self.sourceAudioURL = url
                }
            }
        }
        return true
    }
}

// MARK: - Inline Pill

struct InlinePill: View {
    let title: String
    let icon: String
    let isSelected: Bool
    var isDisabled: Bool = false
    let action: () -> Void

    @State private var isHovered = false

    var body: some View {
        Button(action: action) {
            HStack(spacing: 5) {
                Image(systemName: icon)
                    .font(.system(size: 12))

                Text(title)
                    .font(Typography.captionMedium)
            }
            .foregroundStyle(foregroundColor)
            .padding(.horizontal, Spacing.md)
            .padding(.vertical, 6)
            .background(
                Capsule()
                    .fill(isSelected ? DesignSystem.Colors.accent.opacity(0.15) : Color.primary.opacity(0.06))
            )
            .overlay(
                Capsule()
                    .strokeBorder(isSelected ? DesignSystem.Colors.accent.opacity(0.3) : Color.clear, lineWidth: 1)
            )
        }
        .buttonStyle(.plain)
        .scaleEffect(isHovered && !isDisabled ? 1.02 : 1)
        .opacity(isDisabled ? 0.5 : 1)
        .onHover { hovering in
            withAnimation(.easeInOut(duration: 0.15)) {
                isHovered = hovering
            }
        }
        .disabled(isDisabled)
    }

    private var foregroundColor: Color {
        if isDisabled {
            return DesignSystem.Colors.textMuted
        }
        return isSelected ? DesignSystem.Colors.textPrimary : DesignSystem.Colors.textSecondary
    }
}

// MARK: - Quick Action Button

struct QuickActionButton: View {
    let icon: String
    let tooltip: String
    let action: () -> Void

    @State private var isHovered = false

    var body: some View {
        Button(action: action) {
            Image(systemName: icon)
                .font(.system(size: 16))
                .foregroundStyle(DesignSystem.Colors.textSecondary)
                .frame(width: 32, height: 32)
                .background(
                    RoundedRectangle(cornerRadius: 6)
                        .fill(isHovered ? Color.primary.opacity(0.08) : Color.clear)
                )
        }
        .buttonStyle(.plain)
        .help(tooltip)
        .onHover { hovering in
            isHovered = hovering
        }
    }
}

// MARK: - Duration Chip

struct DurationChip: View {
    let duration: TrackDuration
    let isSelected: Bool
    let action: () -> Void

    @State private var isHovered = false

    var body: some View {
        Button(action: action) {
            Text(duration.displayName)
                .font(Typography.captionMedium)
                .foregroundStyle(isSelected ? DesignSystem.Colors.accent : DesignSystem.Colors.textSecondary)
                .padding(.horizontal, Spacing.sm)
                .padding(.vertical, Spacing.xs)
                .background(
                    RoundedRectangle(cornerRadius: 6)
                        .fill(isSelected ? DesignSystem.Colors.accent.opacity(0.15) : Color.primary.opacity(0.06))
                )
        }
        .buttonStyle(.plain)
        .scaleEffect(isHovered ? 1.03 : 1)
        .onHover { hovering in
            withAnimation(.easeInOut(duration: 0.1)) {
                isHovered = hovering
            }
        }
    }
}

// MARK: - Quality Chip

struct QualityChip: View {
    let mode: QualityMode
    let isSelected: Bool
    let action: () -> Void

    @State private var isHovered = false

    var body: some View {
        Button(action: action) {
            Text(mode.displayName)
                .font(Typography.captionMedium)
                .foregroundStyle(isSelected ? DesignSystem.Colors.accent : DesignSystem.Colors.textSecondary)
                .padding(.horizontal, Spacing.sm)
                .padding(.vertical, Spacing.xs)
                .background(
                    RoundedRectangle(cornerRadius: 6)
                        .fill(isSelected ? DesignSystem.Colors.accent.opacity(0.15) : Color.primary.opacity(0.06))
                )
        }
        .buttonStyle(.plain)
        .scaleEffect(isHovered ? 1.03 : 1)
        .onHover { hovering in
            withAnimation(.easeInOut(duration: 0.1)) {
                isHovered = hovering
            }
        }
    }
}

// MARK: - Lyrics Tag Button

struct LyricsTagButton: View {
    let tag: String
    let action: () -> Void

    @State private var isHovered = false

    var body: some View {
        Button(action: action) {
            Text(tag)
                .font(Typography.caption)
                .foregroundStyle(DesignSystem.Colors.textSecondary)
                .padding(.horizontal, Spacing.xs)
                .padding(.vertical, 2)
                .background(
                    RoundedRectangle(cornerRadius: 4)
                        .fill(Color.primary.opacity(isHovered ? 0.12 : 0.06))
                )
        }
        .buttonStyle(.plain)
        .scaleEffect(isHovered ? 1.03 : 1)
        .onHover { hovering in
            withAnimation(.easeInOut(duration: 0.1)) {
                isHovered = hovering
            }
        }
    }
}

#Preview {
    GenerationView()
        .environmentObject(AppState())
}
