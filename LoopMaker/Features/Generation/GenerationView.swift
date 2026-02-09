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
            // Prompt area
            VStack(alignment: .leading, spacing: Spacing.sm) {
                HStack(spacing: 6) {
                    Image(systemName: "wand.and.stars")
                        .font(.system(size: 13, weight: .medium))
                        .foregroundStyle(DesignSystem.Colors.accent)

                    Text("Music Description")
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
                            Text("Describe the music you want to create...")
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
                    // Instrumental / Lyrics
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

                // Lyrics (when in lyrics mode)
                if !isInstrumental {
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
                    Image(systemName: "waveform")
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
        !prompt.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty && appState.canGenerate
    }

    private var buttonTitle: String {
        if appState.isGenerating {
            return "Generating..."
        }
        if case .downloading = appState.modelDownloadStates[appState.selectedModel] {
            return "Downloading Model..."
        }
        return "Create"
    }

    private func generate() {
        let effectiveLyrics: String? = isInstrumental ? nil : (lyrics.isEmpty ? nil : lyrics)

        let request = GenerationRequest(
            prompt: prompt,
            duration: selectedDuration,
            model: appState.selectedModel,
            lyrics: effectiveLyrics,
            qualityMode: selectedQualityMode
        )
        appState.startGeneration(request: request)
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
