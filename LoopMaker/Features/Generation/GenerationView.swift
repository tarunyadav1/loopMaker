import AVFoundation
import SwiftUI

struct GenerationView: View {
    @EnvironmentObject var appState: AppState
    @State private var prompt = ""
    @State private var selectedDuration: TrackDuration = .medium
    @State private var selectedGenreCard: GenreCardData?
    @State private var isInstrumental = true
    @State private var lyrics = ""
    @State private var selectedQualityMode: QualityMode = .fast
    @State private var suggestions: [SuggestionData] = SuggestionData.randomSet(for: .text2music)
    @State private var showAdvanced = false

    // Seed state
    @State private var seedText = ""
    @State private var lockSeed = false
    @State private var lastUsedSeed: UInt64?

    // Batch variations
    @State private var batchSize = 1

    // Guidance scale
    @State private var guidanceScale: Double = 7.0

    // Music metadata
    @State private var bpmEnabled = false
    @State private var bpm: Double = 120
    @State private var selectedKey: String?
    @State private var selectedTimeSignature: String?

    // Cover mode state
    @State private var taskType: GenerationTaskType = .text2music
    @State private var sourceAudioURL: URL?
    @State private var coverVocalsMode: CoverVocalsMode = .instrumental
    @State private var refAudioStrength: Double = 0.5
    @State private var isDropTargeted = false

    // Extend mode state
    @State private var selectedExtensionAmount: ExtensionAmount = .thirty
    @State private var sourceTrack: Track?
    @State private var cachedExtendSourceDuration: Double?
    @State private var extendDurationReadFailed = false
    @State private var showTrackLibraryPicker = false
    @State private var trackPickerQuery = ""

    // Runtime ETA estimation (adapts to machine speed)
    @State private var generationStartedAt: Date?
    @State private var smoothedRemainingSeconds: TimeInterval?

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
        .sheet(isPresented: $showTrackLibraryPicker) {
            trackLibraryPickerSheet
        }
        .onAppear {
            applyPrefillFromAppState()
            refreshExtendSourceDuration()
            if appState.isGenerating && generationStartedAt == nil {
                handleGenerationStateChange(isGenerating: true)
            }
        }
        .onChange(of: appState.prefillRequest) {
            applyPrefillFromAppState()
        }
        .onChange(of: appState.isGenerating) {
            handleGenerationStateChange(isGenerating: appState.isGenerating)
        }
        .onChange(of: appState.generationProgress) {
            updateDynamicETA(progress: appState.generationProgress)
        }
        .onChange(of: taskType) {
            refreshSuggestions()
            refreshExtendSourceDuration()
            normalizeExtensionSelection()
        }
        .onChange(of: sourceTrack) {
            refreshExtendSourceDuration()
            normalizeExtensionSelection()
        }
        .onChange(of: sourceAudioURL) {
            refreshExtendSourceDuration()
            normalizeExtensionSelection()
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

            // Track picker (extend mode only)
            if taskType == .extend {
                trackPickerSection
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

                    Text(taskType == .cover ? "Style Description" : taskType == .extend ? "Extension Description" : "Music Description")
                        .font(Typography.captionMedium)
                        .foregroundStyle(DesignSystem.Colors.textSecondary)

                    Spacer()

                    if !prompt.isEmpty {
                        Text("\(prompt.count)")
                            .font(Typography.caption2)
                            .foregroundStyle(DesignSystem.Colors.textMuted)
                    }
                }

                if shouldShowLanguageDetection {
                    HStack(spacing: 6) {
                        Image(systemName: "globe")
                            .font(.system(size: 10, weight: .semibold))
                            .foregroundStyle(languageDetectionColor)

                        Text(languageDetectionText)
                            .font(Typography.caption2)
                            .foregroundStyle(languageDetectionColor)
                    }
                    .padding(.horizontal, Spacing.xs + 2)
                    .padding(.vertical, Spacing.xxs + 1)
                    .background(
                        Capsule()
                            .fill(languageDetectionColor.opacity(0.14))
                    )
                    .help("Language is inferred from your lyrics first, then prompt keywords.")
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
                    // Vocals mode pills (different for cover vs generate vs extend)
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

                    // Duration chips or extension amount chips
                    if taskType == .extend {
                        HStack(spacing: Spacing.xs) {
                            ForEach(ExtensionAmount.allCases, id: \.self) { amount in
                                ExtensionAmountChip(
                                    amount: amount,
                                    isSelected: selectedExtensionAmount == amount,
                                    isDisabled: !isExtensionAmountAllowed(amount),
                                    action: {
                                        if isExtensionAmountAllowed(amount) {
                                            selectedExtensionAmount = amount
                                        }
                                    }
                                )
                            }
                        }
                    } else {
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

                if taskType == .extend, !hasValidExtensionSelection {
                    Text("Selected extension exceeds the \(appState.selectedModel.maxDurationSeconds)s engine limit.")
                        .font(Typography.caption)
                        .foregroundStyle(DesignSystem.Colors.warning)
                        .frame(maxWidth: .infinity, alignment: .leading)
                }

                if taskType == .extend,
                   sourceAudioURL != nil,
                   sourceTrack == nil,
                   cachedExtendSourceDuration == nil,
                   !extendDurationReadFailed {
                    Text("Reading source audio duration…")
                        .font(Typography.caption)
                        .foregroundStyle(DesignSystem.Colors.textMuted)
                        .frame(maxWidth: .infinity, alignment: .leading)
                }

                if taskType == .extend, extendDurationReadFailed {
                    Text("Could not read source audio duration. Choose a different file.")
                        .font(Typography.caption)
                        .foregroundStyle(DesignSystem.Colors.warning)
                        .frame(maxWidth: .infinity, alignment: .leading)
                }

                // Lyrics section
                if taskType == .cover && coverVocalsMode == .newLyrics {
                    lyricsSection
                } else if (taskType == .text2music || taskType == .extend) && !isInstrumental {
                    lyricsSection
                }

                if !appState.backendConnected {
                    backendConnectionBanner
                }

                if let status = generationFeedbackStatus {
                    generationStatusBanner(status)
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

            InlinePill(
                title: GenerationTaskType.extend.displayName,
                icon: GenerationTaskType.extend.icon,
                isSelected: taskType == .extend,
                action: {
                    withAnimation(.easeInOut(duration: 0.2)) {
                        taskType = .extend
                        // Auto-populate source track from selected or last generated
                        if sourceTrack == nil {
                            if let selected = appState.selectedTrack {
                                sourceTrack = selected
                                sourceAudioURL = selected.audioURL
                            } else if let last = appState.lastGeneratedTrack {
                                sourceTrack = last
                                sourceAudioURL = last.audioURL
                            }
                        }
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
                Button(action: { browseAudio() }) {
                    VStack(spacing: Spacing.sm) {
                        Image(systemName: "arrow.down.doc")
                            .font(.system(size: 24))
                            .foregroundStyle(DesignSystem.Colors.textMuted)

                        Text("Drop audio or click to browse")
                            .font(Typography.captionMedium)
                            .foregroundStyle(DesignSystem.Colors.textSecondary)

                        Text("WAV, MP3, M4A, FLAC, AAC, AIFF")
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

    // MARK: - Track Picker (extend mode)

    private var trackPickerSection: some View {
        Group {
            if let track = sourceTrack {
                // Selected track display
                HStack(spacing: Spacing.sm) {
                    Image(systemName: "waveform.circle.fill")
                        .font(.system(size: 24))
                        .foregroundStyle(DesignSystem.Colors.accent)

                    VStack(alignment: .leading, spacing: 2) {
                        Text(track.displayTitle)
                            .font(Typography.bodyMedium)
                            .foregroundStyle(DesignSystem.Colors.textPrimary)
                            .lineLimit(1)

                        Text("\(track.duration.displayName) track")
                            .font(Typography.caption)
                            .foregroundStyle(DesignSystem.Colors.textMuted)
                    }

                    Spacer()

                    Button {
                        sourceTrack = nil
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
            } else if let url = sourceAudioURL {
                // Selected external file display
                HStack(spacing: Spacing.sm) {
                    Image(systemName: "waveform.circle.fill")
                        .font(.system(size: 24))
                        .foregroundStyle(DesignSystem.Colors.accent)

                    VStack(alignment: .leading, spacing: 2) {
                        Text(url.lastPathComponent)
                            .font(Typography.bodyMedium)
                            .foregroundStyle(DesignSystem.Colors.textPrimary)
                            .lineLimit(1)

                        Text("File selected for extend")
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
                // Track selection chips
                VStack(alignment: .leading, spacing: Spacing.sm) {
                    Text("Select a track to extend")
                        .font(Typography.captionMedium)
                        .foregroundStyle(DesignSystem.Colors.textSecondary)

                    if appState.tracks.isEmpty {
                        Text("No tracks yet — generate one first")
                            .font(Typography.caption)
                            .foregroundStyle(DesignSystem.Colors.textMuted)
                            .frame(maxWidth: .infinity)
                            .padding(.vertical, Spacing.lg)
                    } else {
                        ScrollView(.horizontal, showsIndicators: false) {
                            HStack(spacing: Spacing.sm) {
                                ForEach(appState.tracks.prefix(10)) { track in
                                    Button {
                                        selectTrackForExtend(track)
                                    } label: {
                                        HStack(spacing: 6) {
                                            Image(systemName: "music.note")
                                                .font(.system(size: 11))
                                            Text(track.displayTitle)
                                                .font(Typography.captionMedium)
                                                .lineLimit(1)
                                        }
                                        .foregroundStyle(DesignSystem.Colors.textSecondary)
                                        .padding(.horizontal, 10)
                                        .padding(.vertical, 6)
                                        .background(
                                            Capsule()
                                                .fill(Color.primary.opacity(0.06))
                                        )
                                    }
                                    .buttonStyle(.plain)
                                }
                            }
                        }
                    }

                    HStack(spacing: Spacing.sm) {
                        if !appState.tracks.isEmpty {
                            Button {
                                trackPickerQuery = ""
                                showTrackLibraryPicker = true
                            } label: {
                                HStack(spacing: 6) {
                                    Image(systemName: "music.note.list")
                                        .font(.system(size: 11))
                                    Text("Choose from library")
                                        .font(Typography.captionMedium)
                                }
                                .foregroundStyle(DesignSystem.Colors.textSecondary)
                                .padding(.horizontal, 10)
                                .padding(.vertical, 6)
                                .background(
                                    Capsule()
                                        .fill(Color.primary.opacity(0.06))
                                )
                            }
                            .buttonStyle(.plain)
                        }

                        Button {
                            browseAudio(for: .extend)
                        } label: {
                            HStack(spacing: 6) {
                                Image(systemName: "folder")
                                    .font(.system(size: 11))
                                Text("Browse audio file")
                                    .font(Typography.captionMedium)
                            }
                            .foregroundStyle(DesignSystem.Colors.textSecondary)
                            .padding(.horizontal, 10)
                            .padding(.vertical, 6)
                            .background(
                                Capsule()
                                    .fill(Color.primary.opacity(0.06))
                            )
                        }
                        .buttonStyle(.plain)
                    }
                }
            }
        }
    }

    private var trackLibraryPickerSheet: some View {
        VStack(alignment: .leading, spacing: Spacing.md) {
            HStack {
                Text("Choose a track to extend")
                    .font(Typography.title3)
                    .foregroundStyle(DesignSystem.Colors.textPrimary)

                Spacer()

                Button("Done") {
                    showTrackLibraryPicker = false
                }
                .buttonStyle(.plain)
                .foregroundStyle(DesignSystem.Colors.accent)
            }

            TextField("Search tracks", text: $trackPickerQuery)
                .textFieldStyle(.roundedBorder)

            if filteredTracksForExtendPicker.isEmpty {
                Text("No tracks match your search.")
                    .font(Typography.caption)
                    .foregroundStyle(DesignSystem.Colors.textMuted)
                    .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .center)
            } else {
                List(filteredTracksForExtendPicker) { track in
                    Button {
                        selectTrackForExtend(track)
                        showTrackLibraryPicker = false
                    } label: {
                        HStack {
                            VStack(alignment: .leading, spacing: 2) {
                                Text(track.displayTitle)
                                    .font(Typography.bodyMedium)
                                    .foregroundStyle(DesignSystem.Colors.textPrimary)
                                Text(track.formattedDate)
                                    .font(Typography.caption)
                                    .foregroundStyle(DesignSystem.Colors.textMuted)
                            }
                            Spacer()
                            Text(track.duration.displayName)
                                .font(Typography.caption)
                                .foregroundStyle(DesignSystem.Colors.textSecondary)
                        }
                    }
                    .buttonStyle(.plain)
                }
                .listStyle(.inset)
            }
        }
        .padding(Spacing.lg)
        .frame(minWidth: 520, minHeight: 420)
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
                                applyGenrePresetPromptSuffix(preset.promptSuffix)
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
                Label("Quality", systemImage: "sparkles")
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

                    Slider(value: $refAudioStrength, in: 0.0...1.0, step: 0.1)
                        .tint(DesignSystem.Colors.accent)

                    Text(String(format: "%.0f%%", refAudioStrength * 100))
                        .font(Typography.captionMedium)
                        .foregroundStyle(DesignSystem.Colors.textPrimary)
                        .frame(width: 36, alignment: .trailing)
                }
            }

            // Seed
            HStack(spacing: Spacing.sm) {
                Label("Seed", systemImage: lockSeed ? "lock.fill" : "lock.open")
                    .font(Typography.captionMedium)
                    .foregroundStyle(DesignSystem.Colors.textSecondary)

                TextField("Random", text: $seedText)
                    .font(Typography.caption)
                    .textFieldStyle(.plain)
                    .frame(width: 100)
                    .padding(.horizontal, 8)
                    .padding(.vertical, 4)
                    .background(
                        RoundedRectangle(cornerRadius: 6)
                            .fill(Color.primary.opacity(0.06))
                    )
                    .onChange(of: seedText) {
                        // Strip non-numeric characters
                        seedText = seedText.filter { $0.isNumber }
                    }

                Button {
                    lockSeed.toggle()
                    if lockSeed, seedText.isEmpty, let last = lastUsedSeed {
                        seedText = String(last)
                    }
                } label: {
                    Image(systemName: lockSeed ? "lock.fill" : "lock.open")
                        .font(.system(size: 12))
                        .foregroundStyle(lockSeed ? DesignSystem.Colors.accent : DesignSystem.Colors.textMuted)
                        .frame(width: 28, height: 28)
                        .background(
                            RoundedRectangle(cornerRadius: 6)
                                .fill(lockSeed ? DesignSystem.Colors.accent.opacity(0.12) : Color.clear)
                        )
                }
                .buttonStyle(.plain)
                .help(lockSeed ? "Unlock seed (use random)" : "Lock seed for reproducible results")

                Button {
                    seedText = String(UInt64.random(in: 0...UInt64(Int32.max)))
                } label: {
                    Image(systemName: "dice")
                        .font(.system(size: 12))
                        .foregroundStyle(DesignSystem.Colors.textMuted)
                        .frame(width: 28, height: 28)
                        .background(
                            RoundedRectangle(cornerRadius: 6)
                                .fill(Color.primary.opacity(0.06))
                        )
                }
                .buttonStyle(.plain)
                .help("Generate random seed")

                Spacer()
            }

            // Variations (batch size)
            HStack {
                Label("Variations", systemImage: "square.stack")
                    .font(Typography.captionMedium)
                    .foregroundStyle(DesignSystem.Colors.textSecondary)

                Spacer()

                HStack(spacing: Spacing.xs) {
                    ForEach([1, 2, 4], id: \.self) { count in
                        Button {
                            batchSize = count
                        } label: {
                            Text("\(count)x")
                                .font(Typography.captionMedium)
                                .foregroundStyle(batchSize == count ? DesignSystem.Colors.accent : DesignSystem.Colors.textSecondary)
                                .padding(.horizontal, Spacing.sm)
                                .padding(.vertical, Spacing.xs)
                                .background(
                                    RoundedRectangle(cornerRadius: 6)
                                        .fill(batchSize == count
                                            ? DesignSystem.Colors.accent.opacity(0.15)
                                            : Color.primary.opacity(0.06))
                                )
                        }
                        .buttonStyle(.plain)
                    }
                }
            }

            // Guidance Scale
            HStack {
                Label("Guidance", systemImage: "scope")
                    .font(Typography.captionMedium)
                    .foregroundStyle(DesignSystem.Colors.textSecondary)

                Slider(value: $guidanceScale, in: 1.0...15.0, step: 0.5)
                    .tint(DesignSystem.Colors.accent)

                Text(String(format: "%.1f", guidanceScale))
                    .font(Typography.captionMedium)
                    .foregroundStyle(DesignSystem.Colors.textPrimary)
                    .frame(width: 32, alignment: .trailing)
            }

            // BPM
            HStack {
                Button {
                    withAnimation(.easeInOut(duration: 0.15)) {
                        bpmEnabled.toggle()
                    }
                } label: {
                    Label("BPM", systemImage: "metronome")
                        .font(Typography.captionMedium)
                        .foregroundStyle(bpmEnabled ? DesignSystem.Colors.textSecondary : DesignSystem.Colors.textMuted)
                }
                .buttonStyle(.plain)

                if bpmEnabled {
                    Slider(value: $bpm, in: 30...300, step: 1)
                        .tint(DesignSystem.Colors.accent)

                    Text("\(Int(bpm))")
                        .font(Typography.captionMedium)
                        .foregroundStyle(DesignSystem.Colors.textPrimary)
                        .frame(width: 32, alignment: .trailing)
                } else {
                    Spacer()

                    Text("Off")
                        .font(Typography.caption)
                        .foregroundStyle(DesignSystem.Colors.textMuted)
                }
            }

            // Key / Time Signature row
            HStack(spacing: Spacing.md) {
                // Key picker
                HStack(spacing: Spacing.xs) {
                    Label("Key", systemImage: "music.note")
                        .font(Typography.captionMedium)
                        .foregroundStyle(DesignSystem.Colors.textSecondary)

                    Picker("", selection: $selectedKey) {
                        Text("Any").tag(String?.none)
                        ForEach(MusicKey.allKeys, id: \.self) { key in
                            Text(key).tag(Optional(key))
                        }
                    }
                    .labelsHidden()
                    .frame(width: 110)
                }

                Spacer()

                // Time signature picker
                HStack(spacing: Spacing.xs) {
                    Label("Time", systemImage: "clock.badge.checkmark")
                        .font(Typography.captionMedium)
                        .foregroundStyle(DesignSystem.Colors.textSecondary)

                    Picker("", selection: $selectedTimeSignature) {
                        Text("Any").tag(String?.none)
                        ForEach(MusicTimeSignature.all, id: \.self) { ts in
                            Text(ts).tag(Optional(ts))
                        }
                    }
                    .labelsHidden()
                    .frame(width: 70)
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

    private var modelState: ModelDownloadState {
        appState.modelDownloadStates[appState.selectedModel] ?? .notDownloaded
    }

    private var needsModelDownload: Bool {
        !modelState.isDownloaded && !modelState.isDownloading
    }

    private var backendConnectionBanner: some View {
        HStack(spacing: Spacing.sm) {
            if appState.backendManager.state.isSetupPhase {
                ProgressView()
                    .progressViewStyle(.circular)
                    .scaleEffect(0.6)
                    .frame(width: 13, height: 13)

                Text(UIRedaction.redactModelNames(in: appState.backendManager.state.userMessage))
                    .font(Typography.caption)
                    .foregroundStyle(DesignSystem.Colors.textSecondary)

                Spacer()
            } else {
                Image(systemName: "exclamationmark.triangle")
                    .font(.system(size: 13))
                    .foregroundStyle(DesignSystem.Colors.warning)

                Text(UIRedaction.redactModelNames(in: appState.backendError ?? "Music engine is offline."))
                    .font(Typography.caption)
                    .foregroundStyle(.secondary)
                    .lineLimit(2)

                Spacer()

                Button("Retry") {
                    Task { await appState.restartBackend() }
                }
                .font(Typography.captionMedium)
                .foregroundStyle(DesignSystem.Colors.accent)
                .buttonStyle(.plain)
            }
        }
    }

    private var generateButton: some View {
        VStack(spacing: Spacing.sm) {
            if modelState.isDownloading {
                modelDownloadProgressBanner
            } else if let errorMsg = modelState.errorMessage {
                modelErrorBanner(errorMsg)
            } else if needsModelDownload {
                modelDownloadBanner
            }

            Button(action: generateButtonAction) {
                HStack(spacing: Spacing.sm) {
                    if appState.isGenerating {
                        ProgressView()
                            .progressViewStyle(.circular)
                            .scaleEffect(0.8)
                            .frame(width: 18, height: 18)
                            .tint(.white)
                    } else if modelState.isDownloading {
                        ProgressView()
                            .progressViewStyle(.circular)
                            .scaleEffect(0.8)
                            .frame(width: 18, height: 18)
                            .tint(.white)
                    } else if needsModelDownload {
                        Image(systemName: "arrow.down.circle")
                            .font(.system(size: 16, weight: .semibold))
                    } else {
                        Image(systemName: taskType == .cover ? "arrow.triangle.2.circlepath" : taskType == .extend ? "arrow.forward.to.line" : "waveform")
                            .font(.system(size: 16, weight: .semibold))
                    }

                    Text(buttonTitle)
                        .font(Typography.headline)
                }
                .foregroundStyle(canGenerateOrDownload ? .white : .secondary)
                .frame(maxWidth: .infinity)
                .frame(height: 44)
                .background(
                    RoundedRectangle(cornerRadius: Spacing.radiusSm)
                        .fill(canGenerateOrDownload
                              ? AnyShapeStyle(DesignSystem.Colors.accent)
                              : AnyShapeStyle(Color.primary.opacity(0.08)))
                )
            }
            .buttonStyle(.plain)
            .disabled(!canGenerateOrDownload)
        }
    }

    private var modelDownloadBanner: some View {
        HStack(spacing: Spacing.sm) {
            Image(systemName: "arrow.down.circle")
                .font(.system(size: 13))
                .foregroundStyle(.orange)

            Text("First time only: LoopMaker will download music engine files (\(appState.selectedModel.sizeFormatted)). This can take 10-30 minutes.")
                .font(Typography.caption)
                .foregroundStyle(.secondary)

            Spacer()
        }
    }

    private var modelDownloadProgressBanner: some View {
        VStack(alignment: .leading, spacing: 4) {
            HStack(spacing: Spacing.sm) {
                ProgressView()
                    .progressViewStyle(.circular)
                    .scaleEffect(0.6)
                    .frame(width: 13, height: 13)

                Text("Preparing music engine…")
                    .font(Typography.caption)
                    .foregroundStyle(.secondary)

                Spacer()

                Text("\(Int((modelState.progress ?? 0) * 100))%")
                    .font(Typography.caption)
                    .foregroundStyle(.secondary)
            }

            GeometryReader { geometry in
                ZStack(alignment: .leading) {
                    RoundedRectangle(cornerRadius: 2)
                        .fill(Color.primary.opacity(0.08))

                    RoundedRectangle(cornerRadius: 2)
                        .fill(DesignSystem.Colors.accent)
                        .frame(width: geometry.size.width * (modelState.progress ?? 0))
                        .animation(.linear(duration: 0.3), value: modelState.progress)
                }
            }
            .frame(height: 4)

            if let message = appState.modelDownloadMessages[appState.selectedModel], !message.isEmpty {
                Text(UIRedaction.redactModelNames(in: message))
                    .font(Typography.caption)
                    .foregroundStyle(DesignSystem.Colors.textMuted)
                    .lineLimit(2)
            } else {
                Text("This download happens once. Keep LoopMaker open while it finishes.")
                    .font(Typography.caption)
                    .foregroundStyle(DesignSystem.Colors.textMuted)
                    .lineLimit(2)
            }
        }
    }

    private func modelErrorBanner(_ message: String) -> some View {
        HStack(spacing: Spacing.sm) {
            Image(systemName: "exclamationmark.triangle")
                .font(.system(size: 13))
                .foregroundStyle(.red)

            Text(UIRedaction.redactModelNames(in: message))
                .font(Typography.caption)
                .foregroundStyle(.secondary)
                .lineLimit(2)

            Spacer()

            Button("Retry") {
                generate()
            }
            .font(Typography.caption)
            .foregroundStyle(DesignSystem.Colors.accent)
        }
    }

    // MARK: - Progress Section

    private var progressSection: some View {
        VStack(spacing: Spacing.md) {
            HStack {
                Text(progressTitle)
                    .font(Typography.captionMedium)
                    .foregroundStyle(DesignSystem.Colors.textSecondary)

                Spacer()

                Text("\(Int(appState.generationProgress * 100))%")
                    .font(Typography.captionMedium)
                    .foregroundStyle(DesignSystem.Colors.textPrimary)
                    .monospacedDigit()
            }

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
                Label(remainingTimeLine, systemImage: "clock")
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

            if !appState.generationStatus.isEmpty {
                Text(appState.generationStatus)
                    .font(Typography.caption)
                    .foregroundStyle(DesignSystem.Colors.textSecondary)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .lineLimit(2)
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
            onSelect: { suggestion, mode in
                applySuggestion(suggestion, mode: mode)
            },
            onRefresh: {
                withAnimation(.easeInOut(duration: 0.2)) {
                    refreshSuggestions()
                }
            }
        )
    }

    private func refreshSuggestions() {
        suggestions = SuggestionData.randomSet(for: taskType)
    }

    private func applySuggestion(_ suggestion: SuggestionData, mode: SuggestionApplyMode) {
        withAnimation(.easeInOut(duration: 0.2)) {
            prompt = suggestion.prompt
            selectedGenreCard = nil
        }

        guard mode == .promptAndLyrics else { return }
        guard let template = suggestion.lyricsTemplate else { return }

        withAnimation(.easeInOut(duration: 0.2)) {
            lyrics = template
            if taskType == .cover {
                coverVocalsMode = .newLyrics
            } else {
                isInstrumental = false
            }
        }
    }

    private func applyGenrePresetPromptSuffix(_ suffix: String) {
        let trimmedSuffix = suffix.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmedSuffix.isEmpty else { return }

        let trimmedPrompt = prompt.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmedPrompt.isEmpty else {
            prompt = trimmedSuffix
            return
        }

        if trimmedPrompt.localizedCaseInsensitiveContains(trimmedSuffix) {
            return
        }

        let separator = (trimmedPrompt.hasSuffix(",")
            || trimmedPrompt.hasSuffix(".")
            || trimmedPrompt.hasSuffix(";")) ? " " : ", "
        prompt = "\(trimmedPrompt)\(separator)\(trimmedSuffix)"
    }

    private var generationFeedbackStatus: String? {
        guard !appState.isGenerating else { return nil }
        let status = appState.generationStatus.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !status.isEmpty else { return nil }
        return status
    }

    private func generationStatusBanner(_ status: String) -> some View {
        HStack(spacing: Spacing.sm) {
            Image(systemName: generationStatusIcon(for: status))
                .font(.system(size: 13, weight: .semibold))
                .foregroundStyle(generationStatusColor(for: status))
            Text(status)
                .font(Typography.caption)
                .foregroundStyle(DesignSystem.Colors.textSecondary)
                .lineLimit(2)
            Spacer()
        }
        .padding(Spacing.sm)
        .background(
            RoundedRectangle(cornerRadius: Spacing.radiusSm)
                .fill(generationStatusColor(for: status).opacity(0.12))
        )
        .overlay(
            RoundedRectangle(cornerRadius: Spacing.radiusSm)
                .strokeBorder(generationStatusColor(for: status).opacity(0.2), lineWidth: 1)
        )
    }

    private func generationStatusIcon(for status: String) -> String {
        if status.hasPrefix("Error:") {
            return "exclamationmark.triangle.fill"
        }
        if status == "Cancelled" {
            return "xmark.circle.fill"
        }
        if status.hasPrefix("Complete") {
            return "checkmark.circle.fill"
        }
        return "info.circle.fill"
    }

    private func generationStatusColor(for status: String) -> Color {
        if status.hasPrefix("Error:") {
            return DesignSystem.Colors.error
        }
        if status == "Cancelled" {
            return DesignSystem.Colors.warning
        }
        if status.hasPrefix("Complete") {
            return DesignSystem.Colors.success
        }
        return DesignSystem.Colors.textSecondary
    }

    // MARK: - Helpers

    private var progressTitle: String {
        let progress = appState.generationProgress
        if progress < 0.12 {
            return "Preparing"
        }
        if progress >= 0.88 {
            return "Finalizing audio"
        }

        switch appState.currentRequest?.taskType ?? .text2music {
        case .text2music:
            return "Generating audio"
        case .cover:
            return "Creating remix"
        case .extend:
            return "Extending track"
        }
    }

    private var remainingTimeLine: String {
        guard appState.generationProgress < 0.99 else { return "Almost done" }
        guard let remaining = smoothedRemainingSeconds else {
            return "Estimating for this Mac..."
        }
        return "About \(formattedDuration(remaining)) left"
    }

    private func formattedDuration(_ seconds: TimeInterval) -> String {
        let total = max(0, Int(seconds.rounded()))
        if total < 60 { return "< 1 min" }

        let hours = total / 3600
        let minutes = (total % 3600) / 60
        if hours > 0 {
            return "\(hours)h \(minutes)m"
        }
        return "\(minutes)m"
    }

    private func handleGenerationStateChange(isGenerating: Bool) {
        if isGenerating {
            generationStartedAt = Date()
            smoothedRemainingSeconds = nil
        } else {
            generationStartedAt = nil
            smoothedRemainingSeconds = nil
        }
    }

    private func updateDynamicETA(progress: Double) {
        guard appState.isGenerating else { return }
        guard let startedAt = generationStartedAt else { return }

        let normalized = min(max(progress, 0), 1)
        if normalized >= 0.99 {
            smoothedRemainingSeconds = 0
            return
        }

        guard normalized > 0.03 else { return }

        let elapsed = Date().timeIntervalSince(startedAt)
        guard elapsed >= 4 else { return }

        let rawRemaining = max(0, (elapsed / normalized) - elapsed)
        let clamped = min(rawRemaining, 90 * 60)
        if let current = smoothedRemainingSeconds {
            smoothedRemainingSeconds = current * 0.7 + clamped * 0.3
        } else {
            smoothedRemainingSeconds = clamped
        }
    }

    private func applyPrefillFromAppState() {
        guard let req = appState.prefillRequest else { return }

        prompt = req.prompt
        selectedDuration = req.duration
        selectedQualityMode = req.qualityMode
        guidanceScale = req.guidanceScale
        taskType = req.taskType
        sourceTrack = req.sourceTrack
        sourceAudioURL = req.sourceAudioURL
        refAudioStrength = req.refAudioStrength
        batchSize = req.batchSize
        selectedKey = req.musicKey
        selectedTimeSignature = req.timeSignature
        showAdvanced = true

        if appState.isModelAccessible(req.model) {
            appState.selectedModel = req.model
        }

        if let seed = req.seed {
            seedText = String(seed)
            lockSeed = true
        } else {
            seedText = ""
            lockSeed = false
        }

        if let bpmValue = req.bpm {
            bpmEnabled = true
            bpm = Double(bpmValue)
        } else {
            bpmEnabled = false
        }

        switch req.taskType {
        case .cover:
            switch req.lyrics {
            case "":
                coverVocalsMode = .keep
                isInstrumental = false
                lyrics = ""
            case nil, "[inst]":
                coverVocalsMode = .instrumental
                isInstrumental = true
                lyrics = ""
            case let text?:
                coverVocalsMode = .newLyrics
                isInstrumental = false
                lyrics = text
            }
        case .text2music, .extend:
            coverVocalsMode = .instrumental
            if let text = req.lyrics, !text.isEmpty, text != "[inst]" {
                isInstrumental = false
                lyrics = text
            } else {
                isInstrumental = true
                lyrics = ""
            }
        }

        appState.prefillRequest = nil
        refreshExtendSourceDuration()
    }

    private var hasPrompt: Bool {
        !prompt.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
    }

    private var hasRequiredSourceForTask: Bool {
        taskType == .text2music || sourceAudioURL != nil
    }

    private var hasReadableExtendDuration: Bool {
        taskType != .extend || extendSourceDuration != nil
    }

    private var canGenerate: Bool {
        hasPrompt && hasRequiredSourceForTask && hasReadableExtendDuration && hasValidExtensionSelection && appState.canGenerate
    }

    private var hasValidExtensionSelection: Bool {
        taskType != .extend || isExtensionAmountAllowed(selectedExtensionAmount)
    }

    private func isExtensionAmountAllowed(_ amount: ExtensionAmount) -> Bool {
        guard taskType == .extend else { return true }
        guard let sourceDuration = extendSourceDuration else { return true }
        let targetDuration = sourceDuration + Double(amount.seconds)
        return targetDuration <= Double(appState.selectedModel.maxDurationSeconds)
    }

    /// Whether the button should be interactive — either for generating or downloading.
    private var canGenerateOrDownload: Bool {
        if canGenerate { return true }
        if needsModelDownload &&
            hasPrompt &&
            hasRequiredSourceForTask &&
            hasReadableExtendDuration &&
            hasValidExtensionSelection &&
            appState.backendConnected &&
            !appState.isGenerating {
            return true
        }
        return false
    }

    private var buttonTitle: String {
        if appState.isGenerating {
            return "Generating..."
        }
        if modelState.isDownloading {
            let progress = modelState.progress ?? 0
            return "Preparing… \(Int(progress * 100))%"
        }
        switch taskType {
        case .cover: return "Create Cover"
        case .extend: return "Extend Track"
        case .text2music: return "Create"
        }
    }

    private func generateButtonAction() {
        generate()
    }

    private var promptPlaceholder: String {
        switch taskType {
        case .cover:
            return "Describe the style for your cover..."
        case .extend:
            return "Describe how the extension should sound..."
        case .text2music:
            return "Describe the music you want to create..."
        }
    }

    private var effectiveLyricsForCurrentState: String? {
        if taskType == .cover {
            switch coverVocalsMode {
            case .keep:
                return ""  // Empty string preserves source vocals
            case .instrumental:
                return "[inst]"  // Explicitly request instrumental
            case .newLyrics:
                return lyrics.isEmpty ? nil : lyrics
            }
        }
        return isInstrumental ? nil : (lyrics.isEmpty ? nil : lyrics)
    }

    private var shouldShowLanguageDetection: Bool {
        if taskType == .cover {
            return coverVocalsMode == .newLyrics
        }
        return !isInstrumental
    }

    private var detectedVocalLanguageHint: VocalLanguageHint? {
        let request = GenerationRequest(
            prompt: prompt,
            duration: selectedDuration,
            model: appState.selectedModel,
            lyrics: effectiveLyricsForCurrentState,
            taskType: taskType
        )
        return request.languageHint
    }

    private var languageDetectionText: String {
        if let detectedVocalLanguageHint {
            return "Detected language: \(detectedVocalLanguageHint.displayName)"
        }
        return "Detected language: Unknown"
    }

    private var languageDetectionColor: Color {
        detectedVocalLanguageHint == nil ? DesignSystem.Colors.warning : DesignSystem.Colors.accent
    }

    private func generate() {
        let effectiveLyrics = effectiveLyricsForCurrentState

        // Calculate repaint parameters for extend mode
        var repaintingStart: Double?
        var repaintingEnd: Double?
        if taskType == .extend {
            guard let sourceDuration = extendSourceDuration else {
                appState.generationStatus = "Error: Could not read source audio duration."
                return
            }
            let targetDuration = sourceDuration + Double(selectedExtensionAmount.seconds)
            guard targetDuration <= Double(appState.selectedModel.maxDurationSeconds) else {
                appState.generationStatus =
                    "Error: Extension exceeds the \(appState.selectedModel.maxDurationSeconds)s engine limit."
                return
            }
            repaintingStart = max(0, sourceDuration - 5.0)  // 5s overlap for seamless transition
            repaintingEnd = targetDuration
        }

        // Parse seed from text field
        let seed: UInt64? = seedText.isEmpty ? nil : UInt64(seedText)
        if let seed { lastUsedSeed = seed }

        let request = GenerationRequest(
            prompt: prompt,
            duration: selectedDuration,
            model: appState.selectedModel,
            seed: seed,
            lyrics: effectiveLyrics,
            qualityMode: selectedQualityMode,
            guidanceScale: guidanceScale,
            taskType: taskType,
            sourceAudioURL: sourceAudioURL,
            refAudioStrength: refAudioStrength,
            repaintingStart: repaintingStart,
            repaintingEnd: repaintingEnd,
            sourceTrack: sourceTrack,
            batchSize: batchSize,
            bpm: bpmEnabled ? Int(bpm) : nil,
            musicKey: selectedKey,
            timeSignature: selectedTimeSignature
        )
        appState.startGenerationEnsuringModel(request: request)

        // Clear seed if not locked
        if !lockSeed {
            seedText = ""
        }
    }

    // MARK: - Audio File Handling

    private var filteredTracksForExtendPicker: [Track] {
        let query = trackPickerQuery.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !query.isEmpty else { return appState.tracks }
        return appState.tracks.filter { track in
            track.displayTitle.localizedCaseInsensitiveContains(query)
                || track.prompt.localizedCaseInsensitiveContains(query)
        }
    }

    private func selectTrackForExtend(_ track: Track) {
        sourceTrack = track
        sourceAudioURL = track.audioURL
    }

    private func refreshExtendSourceDuration() {
        guard taskType == .extend else {
            cachedExtendSourceDuration = nil
            extendDurationReadFailed = false
            return
        }

        if let track = sourceTrack {
            cachedExtendSourceDuration = track.durationSeconds
            extendDurationReadFailed = false
            return
        }

        guard let sourceAudioURL else {
            cachedExtendSourceDuration = nil
            extendDurationReadFailed = false
            return
        }

        guard let player = try? AVAudioPlayer(contentsOf: sourceAudioURL) else {
            cachedExtendSourceDuration = nil
            extendDurationReadFailed = true
            return
        }
        let seconds = player.duration
        guard seconds.isFinite, seconds > 0 else {
            cachedExtendSourceDuration = nil
            extendDurationReadFailed = true
            return
        }
        cachedExtendSourceDuration = seconds
        extendDurationReadFailed = false
    }

    private var extendSourceDuration: Double? {
        cachedExtendSourceDuration
    }

    private func browseAudio(for taskOverride: GenerationTaskType? = nil) {
        let effectiveTask = taskOverride ?? taskType
        let panel = NSOpenPanel()
        panel.allowedContentTypes = [.audio]
        panel.allowsMultipleSelection = false
        panel.canChooseDirectories = false
        panel.message = effectiveTask == .extend
            ? "Select an audio file to extend"
            : "Select an audio file to use as cover source"

        if panel.runModal() == .OK {
            sourceAudioURL = panel.url
            sourceTrack = nil
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
                    self.sourceTrack = nil
                }
            }
        }
        return true
    }

    private func normalizeExtensionSelection() {
        guard taskType == .extend else { return }
        guard !isExtensionAmountAllowed(selectedExtensionAmount) else { return }
        if let fallback = ExtensionAmount.allCases.first(where: { isExtensionAmountAllowed($0) }) {
            selectedExtensionAmount = fallback
        }
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

// MARK: - Extension Amount Chip

struct ExtensionAmountChip: View {
    let amount: ExtensionAmount
    let isSelected: Bool
    var isDisabled: Bool = false
    let action: () -> Void

    @State private var isHovered = false

    var body: some View {
        Button(action: action) {
            Text(amount.displayName)
                .font(Typography.captionMedium)
                .foregroundStyle(foregroundColor)
                .padding(.horizontal, Spacing.sm)
                .padding(.vertical, Spacing.xs)
                .background(
                    RoundedRectangle(cornerRadius: 6)
                        .fill(isSelected ? DesignSystem.Colors.accent.opacity(0.15) : Color.primary.opacity(0.06))
                )
        }
        .buttonStyle(.plain)
        .scaleEffect(isHovered && !isDisabled ? 1.03 : 1)
        .opacity(isDisabled ? 0.5 : 1)
        .onHover { hovering in
            withAnimation(.easeInOut(duration: 0.1)) {
                isHovered = hovering
            }
        }
        .disabled(isDisabled)
    }

    private var foregroundColor: Color {
        if isDisabled {
            return DesignSystem.Colors.textMuted
        }
        return isSelected ? DesignSystem.Colors.accent : DesignSystem.Colors.textSecondary
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

#if PREVIEWS
#Preview {
    GenerationView()
        .environmentObject(AppState())
}
#endif
