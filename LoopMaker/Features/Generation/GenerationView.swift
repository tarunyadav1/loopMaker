import SwiftUI

struct GenerationView: View {
    @EnvironmentObject var appState: AppState
    @State private var prompt = ""
    @State private var selectedDuration: TrackDuration = .medium
    @State private var selectedGenreCard: GenreCardData?
    @State private var selectedGenre: GenrePreset?
    @State private var isInstrumental = true
    @State private var lyrics = ""
    @State private var selectedQualityMode: QualityMode = .fast

    var body: some View {
        ScrollView {
            VStack(spacing: Spacing.xl) {
                // Hero section
                heroSection

                // Prompt input
                promptSection

                // Mode toggles
                modeToggles

                // Lyrics editor (ACE-Step with vocals)
                if !isInstrumental && appState.selectedModel.supportsLyrics {
                    lyricsSection
                }

                // Genre cards
                GenreCardGrid(
                    genres: GenreCardData.presets,
                    selectedGenre: $selectedGenreCard,
                    onSelect: { genre in
                        // Map to GenrePreset
                        selectedGenre = GenrePreset.allPresets.first { $0.name == genre.name }
                    }
                )

                // Settings section
                settingsSection

                // Generate button
                generateButton

                // Progress section
                if appState.isGenerating {
                    progressSection
                }

                Spacer(minLength: Spacing.xxl)
            }
            .padding(.horizontal, Spacing.xl)
            .padding(.top, Spacing.xl)
        }
        .background(Theme.background)
        .onChange(of: appState.selectedModel) { _, newModel in
            // Adjust duration if current selection is incompatible
            if !selectedDuration.isCompatible(with: newModel) {
                selectedDuration = TrackDuration.available(for: newModel).last ?? .medium
            }
        }
    }

    // MARK: - Hero Section

    private var heroSection: some View {
        VStack(spacing: Spacing.sm) {
            Text("Create something")
                .heroText()

            Text("new today")
                .font(Typography.hero)
                .foregroundStyle(Theme.accentGradient)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, Spacing.lg)
    }

    // MARK: - Prompt Section

    private var promptSection: some View {
        GlassTextField(
            text: $prompt,
            placeholder: "Describe the music you want to create...",
            icon: "wand.and.stars",
            submitLabel: "Generate",
            isEnabled: canGenerate,
            onSubmit: generate
        )
    }

    // MARK: - Mode Toggles

    private var modeToggles: some View {
        HStack(spacing: Spacing.sm) {
            ModeToggleButton(
                title: "Instrumental",
                icon: "pianokeys",
                isSelected: isInstrumental,
                action: { isInstrumental = true }
            )

            ModeToggleButton(
                title: "With Lyrics",
                icon: "music.mic",
                isSelected: !isInstrumental,
                isDisabled: !appState.selectedModel.supportsLyrics,
                action: {
                    if appState.selectedModel.supportsLyrics {
                        isInstrumental = false
                    }
                }
            )

            Spacer()

            // Quick actions
            HStack(spacing: Spacing.sm) {
                QuickActionButton(icon: "dice", tooltip: "Random prompt") {
                    prompt = randomPrompts.randomElement() ?? ""
                }

                QuickActionButton(icon: "clock.arrow.circlepath", tooltip: "Recent") {}

                QuickActionButton(icon: "bookmark", tooltip: "Saved prompts") {}
            }
        }
    }

    // MARK: - Lyrics Section

    private var lyricsSection: some View {
        GlassCard(padding: Spacing.md, cornerRadius: Spacing.radiusMd) {
            VStack(alignment: .leading, spacing: Spacing.sm) {
                HStack {
                    Label("Lyrics", systemImage: "music.mic")
                        .font(Typography.bodyMedium)
                        .foregroundStyle(Theme.textSecondary)

                    Spacer()

                    // Quick structure tags
                    HStack(spacing: Spacing.xs) {
                        LyricsTagButton(tag: "[verse]") { insertLyricsTag("[verse]") }
                        LyricsTagButton(tag: "[chorus]") { insertLyricsTag("[chorus]") }
                        LyricsTagButton(tag: "[bridge]") { insertLyricsTag("[bridge]") }
                    }
                }

                TextEditor(text: $lyrics)
                    .font(Typography.body)
                    .foregroundStyle(Theme.textPrimary)
                    .scrollContentBackground(.hidden)
                    .frame(minHeight: 100, maxHeight: 200)
                    .padding(Spacing.sm)
                    .background(
                        RoundedRectangle(cornerRadius: Spacing.radiusSm)
                            .fill(Theme.backgroundTertiary.opacity(0.5))
                    )

                Text("Use [verse], [chorus], [bridge] tags to structure your song")
                    .font(Typography.caption)
                    .foregroundStyle(Theme.textTertiary)
            }
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

    // MARK: - Settings Section

    private var settingsSection: some View {
        GlassCard(padding: Spacing.md, cornerRadius: Spacing.radiusMd) {
            VStack(spacing: Spacing.md) {
                // Duration
                HStack {
                    Label("Duration", systemImage: "clock")
                        .font(Typography.bodyMedium)
                        .foregroundStyle(Theme.textSecondary)

                    Spacer()

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

                                // Pro lock overlay for extended durations
                                if duration.requiresPro && !appState.isProUser {
                                    FeatureLockOverlay(feature: .extendedDuration)
                                }
                            }
                        }
                    }
                }

                Divider()
                    .background(Theme.glassBorder)

                // Model
                HStack {
                    Label("Model", systemImage: "cpu")
                        .font(Typography.bodyMedium)
                        .foregroundStyle(Theme.textSecondary)

                    Spacer()

                    HStack(spacing: Spacing.xs) {
                        ForEach(ModelType.allCases, id: \.self) { model in
                            ZStack {
                                ModelChip(
                                    model: model,
                                    isSelected: appState.selectedModel == model,
                                    downloadState: appState.modelDownloadStates[model] ?? .notDownloaded,
                                    action: {
                                        if appState.isModelAccessible(model) {
                                            appState.selectedModel = model
                                        }
                                    },
                                    onDownload: {
                                        if appState.isModelAccessible(model) {
                                            appState.downloadModel(model)
                                        }
                                    }
                                )

                                // Pro lock overlay
                                if model.requiresPro && !appState.isProUser {
                                    FeatureLockOverlay(
                                        feature: model == .acestep ? .aceStepModel : .mediumModel
                                    )
                                }
                            }
                        }
                    }
                }

                // Quality mode (ACE-Step only)
                if appState.selectedModel.family == .acestep {
                    Divider()
                        .background(Theme.glassBorder)

                    HStack {
                        Label("Quality", systemImage: "sparkles")
                            .font(Typography.bodyMedium)
                            .foregroundStyle(Theme.textSecondary)

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

                // Backend status warning
                if !appState.backendConnected {
                    Divider()
                        .background(Theme.glassBorder)

                    HStack(spacing: Spacing.sm) {
                        Image(systemName: "exclamationmark.triangle.fill")
                            .foregroundStyle(Theme.warning)

                        Text(appState.backendError ?? "Backend not connected")
                            .font(Typography.caption)
                            .foregroundStyle(Theme.textSecondary)

                        Spacer()

                        ActionButton(title: "Setup", variant: .outline, size: .small) {
                            appState.showSetup = true
                        }
                    }
                }
            }
        }
    }

    /// Durations available for current model
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
                        .font(.system(size: 18, weight: .semibold))
                }

                Text(buttonTitle)
                    .font(Typography.headline)
            }
            .foregroundStyle(.white)
            .frame(maxWidth: .infinity)
            .frame(height: 56)
            .background(
                RoundedRectangle(cornerRadius: Spacing.radiusMd)
                    .fill(canGenerate ? Theme.accentGradient : LinearGradient(
                        colors: [Theme.backgroundTertiary, Theme.backgroundTertiary],
                        startPoint: .leading,
                        endPoint: .trailing
                    ))
            )
            .opacity(canGenerate ? 1 : 0.6)
        }
        .buttonStyle(.plain)
        .disabled(!canGenerate)
    }

    // MARK: - Progress Section

    private var progressSection: some View {
        GlassCard {
            VStack(spacing: Spacing.md) {
                // Progress bar with animated gradient
                GeometryReader { geometry in
                    ZStack(alignment: .leading) {
                        RoundedRectangle(cornerRadius: 4)
                            .fill(Theme.backgroundTertiary)
                            .frame(height: 8)

                        RoundedRectangle(cornerRadius: 4)
                            .fill(Theme.accentGradient)
                            .frame(width: geometry.size.width * appState.generationProgress, height: 8)
                            .animation(.easeInOut(duration: 0.3), value: appState.generationProgress)
                    }
                }
                .frame(height: 8)

                HStack {
                    Text(appState.generationStatus)
                        .font(Typography.caption)
                        .foregroundStyle(Theme.textSecondary)

                    Spacer()

                    Text("\(Int(appState.generationProgress * 100))%")
                        .font(Typography.captionMedium)
                        .foregroundStyle(Theme.textPrimary)
                }

                // Estimated time based on duration and model
                HStack {
                    Image(systemName: "clock")
                        .font(.system(size: 12))
                        .foregroundStyle(Theme.textTertiary)

                    Text(estimatedTimeText)
                        .font(Typography.caption)
                        .foregroundStyle(Theme.textTertiary)

                    Spacer()
                }

                ActionButton(title: "Cancel", icon: "xmark", variant: .outline, size: .small) {
                    appState.cancelGeneration()
                }
            }
        }
    }

    private var estimatedTimeText: String {
        guard let request = appState.currentRequest else {
            return "Estimating..."
        }

        let estimate: String
        if request.model.family == .acestep {
            // ACE-Step v1.5 turbo (8 steps) on CPU (MPS has Metal shader bugs).
            // LM runs fast on MLX, but DiT diffusion on CPU is ~1-2 min per 10s.
            switch request.duration {
            case .short:     estimate = "1-2 minutes"
            case .medium:    estimate = "3-6 minutes"
            case .long:      estimate = "6-12 minutes"
            case .extended:  estimate = "12-20 minutes"
            case .maximum:   estimate = "20-40 minutes"
            }
        } else {
            // MusicGen is slower: ~60s for 30s
            switch request.duration {
            case .short:   estimate = "1-2 minutes"
            case .medium:  estimate = "5-10 minutes"
            case .long:    estimate = "10-20 minutes"
            default:       estimate = "Unknown"
            }
        }

        let cpuNote = request.model.family == .acestep ? "" : " (MusicGen runs on CPU)"
        return "Estimated time: \(estimate)\(cpuNote)"
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
        return "Generate Music"
    }

    private func generate() {
        let effectiveLyrics: String? = isInstrumental ? nil : (lyrics.isEmpty ? nil : lyrics)

        let request = GenerationRequest(
            prompt: prompt,
            duration: selectedDuration,
            model: appState.selectedModel,
            genre: selectedGenre,
            lyrics: effectiveLyrics,
            qualityMode: selectedQualityMode
        )
        appState.startGeneration(request: request)
    }

    private let randomPrompts = [
        "Chill lo-fi beats with vinyl crackle and soft piano",
        "Epic cinematic orchestral with rising strings",
        "Ambient electronic with ethereal pads and gentle arpeggios",
        "Upbeat electronic dance with driving bass and synth leads",
        "Smooth jazz with saxophone and brushed drums",
        "Atmospheric ambient with nature sounds and soft drones"
    ]
}

// MARK: - Mode Toggle Button

struct ModeToggleButton: View {
    let title: String
    let icon: String
    let isSelected: Bool
    var isDisabled: Bool = false
    let action: () -> Void

    @State private var isHovered = false

    var body: some View {
        Button(action: action) {
            HStack(spacing: Spacing.sm) {
                Image(systemName: icon)
                    .font(.system(size: 14))

                Text(title)
                    .font(Typography.bodyMedium)
            }
            .foregroundStyle(foregroundColor)
            .padding(.horizontal, Spacing.md)
            .padding(.vertical, Spacing.sm)
            .background(
                RoundedRectangle(cornerRadius: Spacing.radiusFull)
                    .fill(isSelected ? Theme.accentPrimary.opacity(0.2) : Theme.backgroundTertiary.opacity(0.5))
            )
            .overlay(
                RoundedRectangle(cornerRadius: Spacing.radiusFull)
                    .strokeBorder(isSelected ? Theme.accentPrimary : Color.clear, lineWidth: 1)
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
        .help(isDisabled ? "Only available with ACE-Step model" : "")
    }

    private var foregroundColor: Color {
        if isDisabled {
            return Theme.textTertiary
        }
        return isSelected ? Theme.textPrimary : Theme.textSecondary
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
                .foregroundStyle(Theme.textSecondary)
                .frame(width: 36, height: 36)
                .background(
                    RoundedRectangle(cornerRadius: Spacing.radiusSm)
                        .fill(isHovered ? Theme.backgroundTertiary : Color.clear)
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
                .foregroundStyle(isSelected ? Theme.textPrimary : Theme.textSecondary)
                .padding(.horizontal, Spacing.sm)
                .padding(.vertical, Spacing.xs)
                .background(
                    RoundedRectangle(cornerRadius: Spacing.radiusSm)
                        .fill(isSelected ? Theme.accentPrimary : Theme.backgroundTertiary)
                )
        }
        .buttonStyle(.plain)
        .scaleEffect(isHovered ? 1.05 : 1)
        .onHover { hovering in
            withAnimation(.easeInOut(duration: 0.1)) {
                isHovered = hovering
            }
        }
    }
}

// MARK: - Model Chip

struct ModelChip: View {
    let model: ModelType
    let isSelected: Bool
    let downloadState: ModelDownloadState
    let action: () -> Void
    let onDownload: () -> Void

    @State private var isHovered = false

    var body: some View {
        Button(action: {
            if downloadState.isDownloaded {
                action()
            } else if case .notDownloaded = downloadState {
                onDownload()
            }
        }) {
            HStack(spacing: Spacing.xs) {
                Text(model.displayName)
                    .font(Typography.captionMedium)

                switch downloadState {
                case .notDownloaded:
                    Image(systemName: "arrow.down.circle")
                        .font(.system(size: 12))
                case .downloading(let progress):
                    ProgressView()
                        .progressViewStyle(.circular)
                        .scaleEffect(0.5)
                        .frame(width: 14, height: 14)
                    Text("\(Int(progress * 100))%")
                        .font(Typography.caption2)
                case .downloaded:
                    if isSelected {
                        Image(systemName: "checkmark")
                            .font(.system(size: 10, weight: .bold))
                    }
                case .error:
                    Image(systemName: "exclamationmark.triangle")
                        .font(.system(size: 12))
                        .foregroundStyle(Theme.error)
                }
            }
            .foregroundStyle(isSelected ? Theme.textPrimary : Theme.textSecondary)
            .padding(.horizontal, Spacing.sm)
            .padding(.vertical, Spacing.xs)
            .background(
                RoundedRectangle(cornerRadius: Spacing.radiusSm)
                    .fill(isSelected ? Theme.accentPrimary : Theme.backgroundTertiary)
            )
        }
        .buttonStyle(.plain)
        .scaleEffect(isHovered ? 1.05 : 1)
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
                .foregroundStyle(isSelected ? Theme.textPrimary : Theme.textSecondary)
                .padding(.horizontal, Spacing.sm)
                .padding(.vertical, Spacing.xs)
                .background(
                    RoundedRectangle(cornerRadius: Spacing.radiusSm)
                        .fill(isSelected ? Theme.accentPrimary : Theme.backgroundTertiary)
                )
        }
        .buttonStyle(.plain)
        .scaleEffect(isHovered ? 1.05 : 1)
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
                .foregroundStyle(Theme.accentPrimary)
                .padding(.horizontal, Spacing.xs)
                .padding(.vertical, 2)
                .background(
                    RoundedRectangle(cornerRadius: 4)
                        .fill(Theme.accentPrimary.opacity(0.1))
                )
        }
        .buttonStyle(.plain)
        .scaleEffect(isHovered ? 1.05 : 1)
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
