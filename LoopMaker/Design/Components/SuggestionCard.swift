import SwiftUI

// MARK: - Suggestion Card Data

enum SuggestionKind: String, CaseIterable, Identifiable {
    case instrumental = "Instrumental"
    case lyrics = "With Lyrics"

    var id: String { rawValue }

    var icon: String {
        switch self {
        case .instrumental: return "pianokeys"
        case .lyrics: return "music.mic"
        }
    }
}

enum SuggestionApplyMode {
    case promptOnly
    case promptAndLyrics
}

struct SuggestionData: Identifiable {
    let id = UUID()
    let title: String
    let prompt: String
    let notes: String
    let tags: [String]
    let kind: SuggestionKind
    let supportedTaskTypes: Set<GenerationTaskType>
    let lyricsTemplate: String?
    let gradientColors: [Color]

    static let library: [SuggestionData] = [
        SuggestionData(
            title: "Late-night lo-fi focus",
            prompt: "lo-fi hip hop, warm piano, dusty vinyl crackle, steady head-nod groove",
            notes: "Simple mellow starter for studying, coding, or reading",
            tags: ["Lo-fi", "Warm", "90 BPM"],
            kind: .instrumental,
            supportedTaskTypes: [.text2music],
            lyricsTemplate: nil,
            gradientColors: [Color(hex: "1E1B4B"), Color(hex: "312E81")]
        ),
        SuggestionData(
            title: "Neon city synthwave",
            prompt: "retro synthwave, analog bassline, night-drive arpeggios, wide cinematic drums",
            notes: "Works well for intros, gaming, and futuristic visuals",
            tags: ["Synthwave", "Retro", "118 BPM"],
            kind: .instrumental,
            supportedTaskTypes: [.text2music],
            lyricsTemplate: nil,
            gradientColors: [Color(hex: "4C1D95"), Color(hex: "BE185D")]
        ),
        SuggestionData(
            title: "Epic trailer build",
            prompt: "cinematic orchestral build, taiko drums, brass stabs, dramatic rise and impact",
            notes: "Great when you want fast energy with a clear climax",
            tags: ["Cinematic", "Epic", "Hybrid"],
            kind: .instrumental,
            supportedTaskTypes: [.text2music, .extend],
            lyricsTemplate: nil,
            gradientColors: [Color(hex: "3F1D0D"), Color(hex: "B45309")]
        ),
        SuggestionData(
            title: "Jazz lounge evening",
            prompt: "intimate jazz trio, brushed drums, upright bass walking line, soft Rhodes chords",
            notes: "Clean background feel without overpowering vocals",
            tags: ["Jazz", "Smooth", "88 BPM"],
            kind: .instrumental,
            supportedTaskTypes: [.text2music],
            lyricsTemplate: nil,
            gradientColors: [Color(hex: "052E16"), Color(hex: "166534")]
        ),
        SuggestionData(
            title: "Indie pop chorus-ready",
            prompt: "indie pop anthem, bright guitars, punchy kick, emotional lift in chorus",
            notes: "Includes a clean verse/chorus lyric scaffold",
            tags: ["Pop", "Hook", "Verse/Chorus"],
            kind: .lyrics,
            supportedTaskTypes: [.text2music, .cover],
            lyricsTemplate: """
                [verse]
                City lights are fading, but my heartbeat stays awake
                Every little mistake becomes a line we cannot break

                [chorus]
                We can turn this night into a song we never lose
                Hold me through the noise, we are louder than the blues
                """,
            gradientColors: [Color(hex: "4A0D29"), Color(hex: "9D174D")]
        ),
        SuggestionData(
            title: "Afro house summer chant",
            prompt: "afro house groove, percussive log drums, uplifting vocal chops, festival energy",
            notes: "Fast way to test dance vocals and rhythm-first lyrics",
            tags: ["Afro House", "Dance", "128 BPM"],
            kind: .lyrics,
            supportedTaskTypes: [.text2music],
            lyricsTemplate: """
                [verse]
                Feet on the sand and the sky turning gold
                Drums in my chest and the story unfolds

                [chorus]
                Higher, higher, take me to the light
                Fire, fire, dancing through the night
                """,
            gradientColors: [Color(hex: "7C2D12"), Color(hex: "EA580C")]
        ),
        SuggestionData(
            title: "R&B midnight confession",
            prompt: "modern R&B, deep sub bass, airy pads, intimate lead vocal space",
            notes: "Useful for testing softer lyrics and close vocal tone",
            tags: ["R&B", "Moody", "72 BPM"],
            kind: .lyrics,
            supportedTaskTypes: [.text2music, .cover],
            lyricsTemplate: """
                [verse]
                You said forever in a whisper on the train
                I still hear it when the city starts to rain

                [chorus]
                If you call me in the midnight glow
                I will come, you already know
                """,
            gradientColors: [Color(hex: "312E81"), Color(hex: "7E22CE")]
        ),
        SuggestionData(
            title: "Acoustic story ballad",
            prompt: "acoustic folk ballad, fingerpicked guitar, subtle strings, heartfelt vocal tone",
            notes: "A clean storytelling structure that is easy to edit",
            tags: ["Folk", "Story", "Acoustic"],
            kind: .lyrics,
            supportedTaskTypes: [.text2music, .cover],
            lyricsTemplate: """
                [verse]
                We wrote our names in dust along the road
                Promised we would always carry the load

                [bridge]
                Time moved fast but love moved faster

                [chorus]
                Stay for one more sunrise, one more mile
                Give me one more reason to keep this smile
                """,
            gradientColors: [Color(hex: "422006"), Color(hex: "A16207")]
        ),
        SuggestionData(
            title: "Acoustic cover makeover",
            prompt: "strip-down acoustic cover, intimate vocal front, soft percussion, room reverb",
            notes: "Turns a dense track into a close, emotional cover",
            tags: ["Cover", "Acoustic", "Intimate"],
            kind: .instrumental,
            supportedTaskTypes: [.cover],
            lyricsTemplate: nil,
            gradientColors: [Color(hex: "1F2937"), Color(hex: "374151")]
        ),
        SuggestionData(
            title: "Hyperpop cover flip",
            prompt: "hyperpop cover, bright saw synths, pitch-bent vocal FX, aggressive sidechain pump",
            notes: "High-contrast style swap for bold cover experiments",
            tags: ["Cover", "Hyperpop", "Bold"],
            kind: .lyrics,
            supportedTaskTypes: [.cover],
            lyricsTemplate: """
                [verse]
                Lights flash fast and the floor is spinning
                Every glitch in my heart feels like winning

                [chorus]
                Crash into color, louder than fear
                Say my name and pull me near
                """,
            gradientColors: [Color(hex: "4C0519"), Color(hex: "BE123C")]
        ),
        SuggestionData(
            title: "Future bass cover uplift",
            prompt: "future bass cover, emotional supersaws, chopped vocal layers, wide snare fills",
            notes: "Good for testing big drops while keeping vocal focus",
            tags: ["Cover", "Future Bass", "Drop"],
            kind: .lyrics,
            supportedTaskTypes: [.cover],
            lyricsTemplate: """
                [verse]
                We were just sparks in a midnight storm
                Learning how to bend without changing form

                [chorus]
                Lift me up where the skyline shakes
                We are the sound that the silence makes
                """,
            gradientColors: [Color(hex: "312E81"), Color(hex: "7C3AED")]
        ),
        SuggestionData(
            title: "Seamless drop extension",
            prompt: "extend with tension riser, filtered drums, then release into a heavier drop",
            notes: "Great default when you want the extension to feel intentional",
            tags: ["Extend", "Drop", "Energy"],
            kind: .instrumental,
            supportedTaskTypes: [.extend],
            lyricsTemplate: nil,
            gradientColors: [Color(hex: "0F172A"), Color(hex: "334155")]
        ),
        SuggestionData(
            title: "Ambient outro extension",
            prompt: "extend into ambient outro, long reverb tails, sparse piano, gradual decay",
            notes: "Smooth way to close a track without a hard stop",
            tags: ["Extend", "Outro", "Ambient"],
            kind: .instrumental,
            supportedTaskTypes: [.extend],
            lyricsTemplate: nil,
            gradientColors: [Color(hex: "042F2E"), Color(hex: "115E59")]
        ),
        SuggestionData(
            title: "Second verse extension",
            prompt: "extend with a second verse arrangement, lighter drums, then chorus payoff",
            notes: "Adds narrative arc if your original track already has vocals",
            tags: ["Extend", "Song Form", "Verse 2"],
            kind: .lyrics,
            supportedTaskTypes: [.extend],
            lyricsTemplate: """
                [verse]
                Another page, another late-night train
                Same old street but I don't feel the same

                [chorus]
                Say it again till the skyline glows
                We are alive in the undertow
                """,
            gradientColors: [Color(hex: "1D4ED8"), Color(hex: "0EA5E9")]
        ),
        SuggestionData(
            title: "Drum and bass sprint",
            prompt: "drum and bass roller, fast breakbeats, reese bass motion, dark club texture",
            notes: "Useful for stress-testing high BPM generation quickly",
            tags: ["DnB", "Fast", "174 BPM"],
            kind: .instrumental,
            supportedTaskTypes: [.text2music],
            lyricsTemplate: nil,
            gradientColors: [Color(hex: "172554"), Color(hex: "1D4ED8")]
        )
    ]

    static func randomSet(for taskType: GenerationTaskType, count: Int = 6) -> [SuggestionData] {
        let pool = library.filter { $0.supportedTaskTypes.contains(taskType) }
        let fallback = pool.isEmpty ? library : pool
        return Array(fallback.shuffled().prefix(count))
    }
}

// MARK: - Suggestion Card

struct SuggestionCard: View {
    let data: SuggestionData
    let onApply: (SuggestionApplyMode) -> Void

    @State private var isHovered = false

    var body: some View {
        VStack(alignment: .leading, spacing: Spacing.sm) {
            HStack(spacing: 6) {
                Image(systemName: data.kind.icon)
                    .font(.system(size: 10, weight: .semibold))
                    .foregroundStyle(.white.opacity(0.95))

                Text(data.kind.rawValue.uppercased())
                    .font(Typography.micro)
                    .foregroundStyle(.white.opacity(0.9))

                Spacer()
            }

            Text(data.title)
                .font(Typography.headline)
                .foregroundStyle(.white)
                .lineLimit(2)
                .multilineTextAlignment(.leading)

            Text(data.prompt)
                .font(Typography.caption)
                .foregroundStyle(.white.opacity(0.8))
                .lineLimit(3)
                .multilineTextAlignment(.leading)

            Text(data.notes)
                .font(Typography.caption2)
                .foregroundStyle(.white.opacity(0.7))
                .lineLimit(2)
                .multilineTextAlignment(.leading)

            HStack(spacing: 6) {
                ForEach(Array(data.tags.prefix(3)), id: \.self) { tag in
                    Text(tag)
                        .font(Typography.micro)
                        .foregroundStyle(.white.opacity(0.85))
                        .padding(.horizontal, 6)
                        .padding(.vertical, 3)
                        .background(Capsule().fill(Color.white.opacity(0.15)))
                }
                Spacer()
            }

            HStack(spacing: 6) {
                SuggestionActionButton(
                    title: "Use Prompt",
                    emphasized: true,
                    action: { onApply(.promptOnly) }
                )

                if data.lyricsTemplate != nil {
                    SuggestionActionButton(
                        title: "Use + Lyrics",
                        emphasized: false,
                        action: { onApply(.promptAndLyrics) }
                    )
                }
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(12)
        .background(
            RoundedRectangle(cornerRadius: 10)
                .fill(
                    LinearGradient(
                        colors: data.gradientColors,
                        startPoint: .topLeading,
                        endPoint: .bottomTrailing
                    )
                )
        )
        .overlay(
            RoundedRectangle(cornerRadius: 10)
                .fill(Color.white.opacity(isHovered ? 0.07 : 0))
        )
        .overlay(
            RoundedRectangle(cornerRadius: 10)
                .strokeBorder(Color.white.opacity(0.1), lineWidth: 1)
        )
        .contentShape(RoundedRectangle(cornerRadius: 10))
        .gesture(
            TapGesture().onEnded {
                onApply(defaultApplyMode)
            },
            including: .gesture
        )
        .scaleEffect(isHovered ? 1.015 : 1)
        .onHover { hovering in
            withAnimation(.easeInOut(duration: 0.15)) {
                isHovered = hovering
            }
        }
        .help(data.lyricsTemplate == nil
              ? "Click to use this prompt"
              : "Click to use this prompt and lyrics")
    }

    private var defaultApplyMode: SuggestionApplyMode {
        data.lyricsTemplate == nil ? .promptOnly : .promptAndLyrics
    }
}

// MARK: - Suggestion Grid

private enum SuggestionFilter: String, CaseIterable, Identifiable {
    case all = "All"
    case instrumental = "Instrumental"
    case lyrics = "With Lyrics"

    var id: String { rawValue }
}

struct SuggestionGrid: View {
    let suggestions: [SuggestionData]
    let onSelect: (SuggestionData, SuggestionApplyMode) -> Void
    let onRefresh: () -> Void

    @State private var selectedFilter: SuggestionFilter = .all
    @State private var isRefreshHovered = false

    var body: some View {
        VStack(alignment: .leading, spacing: Spacing.sm) {
            HStack(alignment: .top) {
                VStack(alignment: .leading, spacing: 2) {
                    Text("Suggestions")
                        .font(Typography.title3)
                        .foregroundStyle(DesignSystem.Colors.textPrimary)

                    Text("Try a starter, then tweak prompt or lyrics.")
                        .font(Typography.caption)
                        .foregroundStyle(DesignSystem.Colors.textMuted)
                }

                Spacer()

                Button(action: onRefresh) {
                    HStack(spacing: 6) {
                        Image(systemName: "arrow.triangle.2.circlepath")
                            .font(.system(size: 12, weight: .medium))
                        Text("Shuffle")
                            .font(Typography.captionMedium)
                    }
                    .foregroundStyle(isRefreshHovered ? DesignSystem.Colors.textPrimary : DesignSystem.Colors.textSecondary)
                }
                .buttonStyle(.plain)
                .onHover { hovering in
                    isRefreshHovered = hovering
                }
                .help("Refresh suggestions")
            }

            HStack(spacing: Spacing.xs) {
                ForEach(SuggestionFilter.allCases) { filter in
                    SuggestionFilterChip(
                        title: filter.rawValue,
                        isSelected: selectedFilter == filter,
                        action: { selectedFilter = filter }
                    )
                }
                Spacer()
            }

            let columns = [GridItem(.adaptive(minimum: 220, maximum: 380), spacing: Spacing.sm)]
            if filteredSuggestions.isEmpty {
                HStack(spacing: Spacing.xs) {
                    Image(systemName: "lightbulb")
                        .font(.system(size: 12))
                        .foregroundStyle(DesignSystem.Colors.textMuted)

                    Text("No matches in this set. Try Shuffle or switch filter.")
                        .font(Typography.caption)
                        .foregroundStyle(DesignSystem.Colors.textMuted)
                }
                .padding(.vertical, 6)
            } else {
                LazyVGrid(columns: columns, spacing: Spacing.sm) {
                    ForEach(filteredSuggestions) { suggestion in
                        SuggestionCard(data: suggestion) { mode in
                            onSelect(suggestion, mode)
                        }
                    }
                }
            }
        }
    }

    private var filteredSuggestions: [SuggestionData] {
        switch selectedFilter {
        case .all:
            return suggestions
        case .instrumental:
            return suggestions.filter { $0.kind == .instrumental }
        case .lyrics:
            return suggestions.filter { $0.kind == .lyrics }
        }
    }
}

private struct SuggestionActionButton: View {
    let title: String
    let emphasized: Bool
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            Text(title)
                .font(Typography.captionSemibold)
                .foregroundStyle(.white.opacity(emphasized ? 1 : 0.88))
                .padding(.horizontal, 8)
                .padding(.vertical, 5)
                .background(
                    RoundedRectangle(cornerRadius: 6)
                        .fill(Color.white.opacity(emphasized ? 0.22 : 0.12))
                )
        }
        .buttonStyle(.plain)
    }
}

private struct SuggestionFilterChip: View {
    let title: String
    let isSelected: Bool
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            Text(title)
                .font(Typography.captionMedium)
                .foregroundStyle(isSelected ? DesignSystem.Colors.accent : DesignSystem.Colors.textSecondary)
                .padding(.horizontal, Spacing.sm)
                .padding(.vertical, Spacing.xs)
                .background(
                    Capsule()
                        .fill(isSelected ? DesignSystem.Colors.accent.opacity(0.14) : Color.primary.opacity(0.06))
                )
        }
        .buttonStyle(.plain)
    }
}

// MARK: - Preview

#Preview {
    ZStack {
        Color(nsColor: .windowBackgroundColor).ignoresSafeArea()

        SuggestionGrid(
            suggestions: SuggestionData.randomSet(for: .text2music),
            onSelect: { _, _ in },
            onRefresh: {}
        )
        .padding(24)
        .frame(maxWidth: 500)
    }
}
