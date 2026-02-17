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

    var tint: Color {
        switch self {
        case .instrumental: return DesignSystem.Colors.audioPrimary
        case .lyrics: return DesignSystem.Colors.accent
        }
    }
}

enum SuggestionApplyMode {
    case promptOnly
    case promptAndLyrics
}

enum SuggestionLanguage: String, CaseIterable, Identifiable {
    case noLyrics = "No Lyrics"
    case english = "English"
    case hindi = "Hindi"
    case spanish = "Spanish"
    case korean = "Korean"
    case multilingual = "Multilingual"

    var id: String { rawValue }

    var icon: String {
        switch self {
        case .noLyrics: return "waveform"
        case .english: return "character.book.closed"
        case .hindi: return "music.note.list"
        case .spanish: return "guitars"
        case .korean: return "sparkles"
        case .multilingual: return "globe"
        }
    }

    var order: Int {
        switch self {
        case .noLyrics: return 0
        case .english: return 1
        case .hindi: return 2
        case .spanish: return 3
        case .korean: return 4
        case .multilingual: return 5
        }
    }
}

struct SuggestionData: Identifiable {
    let id = UUID()
    let title: String
    let prompt: String
    let notes: String
    let tags: [String]
    let kind: SuggestionKind
    let language: SuggestionLanguage
    let supportedTaskTypes: Set<GenerationTaskType>
    let lyricsTemplate: String?
    let gradientColors: [Color]

    static let library: [SuggestionData] = [
        SuggestionData(
            title: "Late-night lo-fi focus",
            prompt: "lo-fi hip hop instrumental, 90 BPM, warm piano loop, dusty vinyl crackle, soft side-chained pads, relaxed head-nod groove",
            notes: "Simple mellow starter for studying, coding, and deep-focus background tracks",
            tags: ["Lo-fi", "Warm", "90 BPM"],
            kind: .instrumental,
            language: .noLyrics,
            supportedTaskTypes: [.text2music],
            lyricsTemplate: nil,
            gradientColors: [Color(hex: "1E1B4B"), Color(hex: "312E81")]
        ),
        SuggestionData(
            title: "Neon city synthwave",
            prompt: "retro synthwave instrumental, 118 BPM, analog bassline, gated pads, night-drive arpeggios, wide cinematic drums, glossy 80s mix",
            notes: "Works well for intros, gaming, and futuristic visuals",
            tags: ["Synthwave", "Retro", "118 BPM"],
            kind: .instrumental,
            language: .noLyrics,
            supportedTaskTypes: [.text2music],
            lyricsTemplate: nil,
            gradientColors: [Color(hex: "4C1D95"), Color(hex: "BE185D")]
        ),
        SuggestionData(
            title: "Epic trailer build",
            prompt: "cinematic trailer hybrid instrumental, 132 BPM, taiko drums, brass stabs, tension risers, low string ostinato, dramatic impact hit",
            notes: "Great when you need high energy with a clear rise-and-hit climax",
            tags: ["Cinematic", "Epic", "Hybrid"],
            kind: .instrumental,
            language: .noLyrics,
            supportedTaskTypes: [.text2music, .extend],
            lyricsTemplate: nil,
            gradientColors: [Color(hex: "3F1D0D"), Color(hex: "B45309")]
        ),
        SuggestionData(
            title: "Jazz lounge evening",
            prompt: "intimate jazz trio instrumental, 88 BPM swing, brushed drums, upright bass walking line, soft Rhodes chords, warm room ambience",
            notes: "Clean background feel that leaves space for vocals or narration",
            tags: ["Jazz", "Smooth", "88 BPM"],
            kind: .instrumental,
            language: .noLyrics,
            supportedTaskTypes: [.text2music],
            lyricsTemplate: nil,
            gradientColors: [Color(hex: "052E16"), Color(hex: "166534")]
        ),
        SuggestionData(
            title: "Bollywood monsoon romance",
            prompt: "bollywood romantic ballad in Hindi, 96 BPM, acoustic guitar intro, tabla pulse, airy strings, emotional female lead, soaring chorus lift",
            notes: "Classic film-style romance starter with expressive Hindi phrasing",
            tags: ["Bollywood", "Hindi", "Romantic"],
            kind: .lyrics,
            language: .hindi,
            supportedTaskTypes: [.text2music],
            lyricsTemplate: """
                [verse]
                baarish ki raat mein tera naam likha
                bheege se sheher mein dil phir se dikha

                [chorus]
                tu jo mile to saansein geet ban jaayein
                hum jo chalein to raaste roshni paayein
                """,
            gradientColors: [Color(hex: "6A1B2E"), Color(hex: "C44569")]
        ),
        SuggestionData(
            title: "Hindi indie roadtrip pop",
            prompt: "Hindi indie pop with upbeat guitars, 108 BPM live drums, bright plucks, sing-along hook, youthful roadtrip energy",
            notes: "Useful for cheerful Hindi pop demos with sticky chorus hooks",
            tags: ["Hindi Pop", "Upbeat", "Hook"],
            kind: .lyrics,
            language: .hindi,
            supportedTaskTypes: [.text2music],
            lyricsTemplate: """
                [verse]
                khidki se hawa bole chal nikalte hain
                shehron ke pare sapne sambhalte hain

                [chorus]
                raaston pe hum gaayen bina rukke
                dil ke saare rang aaj khulke
                """,
            gradientColors: [Color(hex: "7F5539"), Color(hex: "D9A066")]
        ),
        SuggestionData(
            title: "Desi rap cypher fire",
            prompt: "Hindi rap with trap drums, 144 BPM hi-hat rolls, heavy 808 glide, aggressive lead vocal, punchy ad-libs, tight street cypher mix",
            notes: "Fast stress test for hard-hitting rap flow and dense rhyme delivery",
            tags: ["Rap", "Hindi", "Trap"],
            kind: .lyrics,
            language: .hindi,
            supportedTaskTypes: [.text2music, .cover],
            lyricsTemplate: """
                [verse]
                galiyon ka dhuaan, par nazar seedhi rehti
                sapno ki bhookh mein meri chaal tez rehti

                [verse]
                beat pe waar, lafz mere steel ki dhaar
                scene ka taaj chahiye, bas yahi ikraar

                [chorus]
                awaaz utha, shehar ko jaga
                hum likhen daur naya, ab rukna mana
                """,
            gradientColors: [Color(hex: "341A5A"), Color(hex: "8E44AD")]
        ),
        SuggestionData(
            title: "Indie pop chorus-ready",
            prompt: "english indie pop anthem, 112 BPM, bright guitars, punchy kick, airy backing vocals, emotional lift in chorus",
            notes: "Balanced default for clean verse/chorus songwriting and topline testing",
            tags: ["Pop", "Hook", "Verse/Chorus"],
            kind: .lyrics,
            language: .english,
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
            title: "Spanish reggaeton pulse",
            prompt: "spanish reggaeton club track, 96 BPM dembow groove, subby kick, syncopated synth stabs, confident male-female vocal trade-offs",
            notes: "Reliable starting point for modern spanish dance and urban pop crossovers",
            tags: ["Spanish", "Reggaeton", "Club"],
            kind: .lyrics,
            language: .spanish,
            supportedTaskTypes: [.text2music],
            lyricsTemplate: """
                [verse]
                bajo la luna tu mirada me quema
                cuando te acercas todo cambia de tema

                [chorus]
                pegate lento, sube la presion
                toda la noche late el corazon
                """,
            gradientColors: [Color(hex: "4A3C00"), Color(hex: "A67C00")]
        ),
        SuggestionData(
            title: "Latin pop beach hook",
            prompt: "spanish latin pop, 104 BPM, acoustic strums, tropical percussion, wide chorus harmonies, sunlit summer energy",
            notes: "Soft-lift pop profile that works for romantic and feel-good vocals",
            tags: ["Latin Pop", "Spanish", "Summer"],
            kind: .lyrics,
            language: .spanish,
            supportedTaskTypes: [.text2music, .cover],
            lyricsTemplate: """
                [verse]
                sobre la arena prometimos volver
                con cada ola te vuelvo a querer

                [chorus]
                baila conmigo, dejate llevar
                en tu sonrisa quiero naufragar
                """,
            gradientColors: [Color(hex: "04545C"), Color(hex: "0E9594")]
        ),
        SuggestionData(
            title: "R&B midnight confession",
            prompt: "modern english R&B, 72 BPM, deep sub bass, airy pads, close vocal chain, sparse snare, intimate late-night tone",
            notes: "Useful for testing soft dynamics and emotional vocal storytelling",
            tags: ["R&B", "Moody", "72 BPM"],
            kind: .lyrics,
            language: .english,
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
            title: "K-pop neon danceline",
            prompt: "k-pop dance pop in Korean, 122 BPM, glossy synth bass, snappy clap layers, pre-chorus tension, explosive drop chorus with chant hook",
            notes: "Great for high-energy choreography-ready arrangements and layered hooks",
            tags: ["K-pop", "Dance", "Korean"],
            kind: .lyrics,
            language: .korean,
            supportedTaskTypes: [.text2music],
            lyricsTemplate: """
                [verse]
                bichi naneun bam georeum majchwo
                simjang soge neoui rhythmul dam-a

                [chorus]
                uri son kkwak jaba, fly up tonight
                modeun geot-i bichna, we own the light
                """,
            gradientColors: [Color(hex: "2D1E6B"), Color(hex: "DA3B8A")]
        ),
        SuggestionData(
            title: "Afro house summer chant",
            prompt: "afro house groove, 124 BPM, percussive log drums, uplifting vocal chops, call-and-response hook, festival-ready movement",
            notes: "Fast way to test dance vocals with chant-style multilingual phrasing",
            tags: ["Afro House", "Dance", "124 BPM"],
            kind: .lyrics,
            language: .multilingual,
            supportedTaskTypes: [.text2music],
            lyricsTemplate: """
                [verse]
                feet on the sand and the sky turning gold
                drums in my chest and the story unfolds

                [chorus]
                higher, higher, llevame al sol
                fire, fire, nacho dil se bol
                """,
            gradientColors: [Color(hex: "7C2D12"), Color(hex: "EA580C")]
        ),
        SuggestionData(
            title: "Acoustic story ballad",
            prompt: "acoustic folk ballad in english, 84 BPM, fingerpicked guitar, soft cello, intimate vocal tone, cinematic bridge",
            notes: "A clean storytelling structure that is easy to edit and personalize",
            tags: ["Folk", "Story", "Acoustic"],
            kind: .lyrics,
            language: .english,
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
            title: "Drum and bass sprint",
            prompt: "drum and bass roller instrumental, 174 BPM breakbeats, reese bass motion, dark club texture, punchy transient shaping",
            notes: "Useful for stress-testing high BPM generation and drum articulation quickly",
            tags: ["DnB", "Fast", "174 BPM"],
            kind: .instrumental,
            language: .noLyrics,
            supportedTaskTypes: [.text2music],
            lyricsTemplate: nil,
            gradientColors: [Color(hex: "172554"), Color(hex: "1D4ED8")]
        ),
        SuggestionData(
            title: "Acoustic cover makeover",
            prompt: "cover reinterpretation, strip-down acoustic arrangement, intimate vocal front, soft percussion, close room reverb",
            notes: "Turns a dense original into a close, emotional cover performance",
            tags: ["Cover", "Acoustic", "Intimate"],
            kind: .instrumental,
            language: .noLyrics,
            supportedTaskTypes: [.cover],
            lyricsTemplate: nil,
            gradientColors: [Color(hex: "1F2937"), Color(hex: "374151")]
        ),
        SuggestionData(
            title: "Hyperpop cover flip",
            prompt: "hyperpop cover, 150 BPM, bright saw synth stacks, pitch-bent vocal FX, aggressive sidechain pump, glitch transitions",
            notes: "High-contrast style swap for bold cover experiments",
            tags: ["Cover", "Hyperpop", "Bold"],
            kind: .lyrics,
            language: .english,
            supportedTaskTypes: [.cover],
            lyricsTemplate: """
                [verse]
                lights flash fast and the floor is spinning
                every glitch in my heart feels like winning

                [chorus]
                crash into color, louder than fear
                say my name and pull me near
                """,
            gradientColors: [Color(hex: "4C0519"), Color(hex: "BE123C")]
        ),
        SuggestionData(
            title: "Bollywood cover reimagined",
            prompt: "bollywood cover in Hindi, 102 BPM, harmonium texture, tabla groove, lush strings, emotional call-and-response chorus",
            notes: "Useful when you want a cinematic Hindi remake from an existing track",
            tags: ["Cover", "Bollywood", "Hindi"],
            kind: .lyrics,
            language: .hindi,
            supportedTaskTypes: [.cover],
            lyricsTemplate: """
                [verse]
                teri dhun pe chalti hai meri saari saansein
                purani si yaadon mein nayi si baatein

                [chorus]
                fir se gunguna, dil ka fasana
                is pal mein tu hi mera afsana
                """,
            gradientColors: [Color(hex: "5B2C6F"), Color(hex: "AF7AC5")]
        ),
        SuggestionData(
            title: "Spanish acoustic cover",
            prompt: "spanish acoustic cover, 92 BPM, nylon guitar arpeggios, cajon groove, intimate lead vocal, soft choir doubles",
            notes: "Clean option for unplugged spanish remakes with emotional clarity",
            tags: ["Cover", "Spanish", "Acoustic"],
            kind: .lyrics,
            language: .spanish,
            supportedTaskTypes: [.cover],
            lyricsTemplate: """
                [verse]
                en cada nota vuelvo a respirar
                tu melodia me ensena a regresar

                [chorus]
                cantame cerca, no mires atras
                todo este amor vuelve a empezar
                """,
            gradientColors: [Color(hex: "145A32"), Color(hex: "58D68D")]
        ),
        SuggestionData(
            title: "Seamless drop extension",
            prompt: "extend arrangement with tension riser, filtered drums, eight-bar build, then release into a heavier drop with wider stereo field",
            notes: "Great default when you want the extension to feel intentional and bigger",
            tags: ["Extend", "Drop", "Energy"],
            kind: .instrumental,
            language: .noLyrics,
            supportedTaskTypes: [.extend],
            lyricsTemplate: nil,
            gradientColors: [Color(hex: "0F172A"), Color(hex: "334155")]
        ),
        SuggestionData(
            title: "Ambient outro extension",
            prompt: "extend into ambient outro, long reverb tails, sparse piano motif, high-frequency roll-off, graceful gradual decay",
            notes: "Smooth way to close a track without an abrupt ending",
            tags: ["Extend", "Outro", "Ambient"],
            kind: .instrumental,
            language: .noLyrics,
            supportedTaskTypes: [.extend],
            lyricsTemplate: nil,
            gradientColors: [Color(hex: "042F2E"), Color(hex: "115E59")]
        ),
        SuggestionData(
            title: "Second verse extension",
            prompt: "extend with a second verse arrangement, lighter drums in first half, melodic counter-line, then strong chorus payoff",
            notes: "Adds narrative arc if your original track already includes vocals",
            tags: ["Extend", "Song Form", "Verse 2"],
            kind: .lyrics,
            language: .english,
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
            title: "Hindi hook extension",
            prompt: "extend with one extra Hindi hook section, crowd-style backing vocals, dhol accents, transition fill, final chorus impact",
            notes: "Adds replay value when you want a stronger Bollywood-style payoff",
            tags: ["Extend", "Hindi", "Hook"],
            kind: .lyrics,
            language: .hindi,
            supportedTaskTypes: [.extend],
            lyricsTemplate: """
                [hook]
                dil ki awaaz ko aur uncha kar
                saath gao sab, ye lamha amar
                """,
            gradientColors: [Color(hex: "7D3C98"), Color(hex: "C39BD3")]
        ),
        SuggestionData(
            title: "Salsa brass extension",
            prompt: "extend with salsa brass call-and-response, tighter conga pattern, piano montuno lift, celebratory ending turnaround",
            notes: "Strong choice for adding latin movement and dance-floor momentum",
            tags: ["Extend", "Salsa", "Latin"],
            kind: .instrumental,
            language: .noLyrics,
            supportedTaskTypes: [.extend],
            lyricsTemplate: nil,
            gradientColors: [Color(hex: "7E5109"), Color(hex: "F5B041")]
        )
    ]

    static func randomSet(for taskType: GenerationTaskType, count: Int = 8) -> [SuggestionData] {
        let pool = library.filter { $0.supportedTaskTypes.contains(taskType) }
        let fallback = pool.isEmpty ? library : pool

        var selected: [SuggestionData] = []
        for language in SuggestionLanguage.allCases {
            guard selected.count < count else { break }
            guard let candidate = fallback.filter({ $0.language == language }).randomElement() else { continue }
            selected.append(candidate)
        }

        if selected.count < count {
            let existingIDs = Set(selected.map(\.id))
            let remaining = fallback.shuffled().filter { !existingIDs.contains($0.id) }
            selected.append(contentsOf: remaining.prefix(count - selected.count))
        }

        return Array(selected.shuffled().prefix(count))
    }
}

// MARK: - Suggestion Card

struct SuggestionCard: View {
    let data: SuggestionData
    let onApply: (SuggestionApplyMode) -> Void

    @State private var isHovered = false

    var body: some View {
        VStack(alignment: .leading, spacing: Spacing.md) {
            HStack(spacing: Spacing.xs) {
                SuggestionBadge(
                    title: data.kind.rawValue,
                    icon: data.kind.icon,
                    tint: data.kind.tint
                )

                SuggestionBadge(
                    title: data.language.rawValue,
                    icon: data.language.icon,
                    tint: DesignSystem.Colors.info
                )

                Spacer()
            }

            VStack(alignment: .leading, spacing: Spacing.xs) {
                Text(data.title)
                    .font(Typography.title3)
                    .foregroundStyle(DesignSystem.Colors.textPrimary)
                    .lineLimit(2)
                    .multilineTextAlignment(.leading)

                Text(data.notes)
                    .font(Typography.caption)
                    .foregroundStyle(DesignSystem.Colors.textMuted)
                    .lineLimit(2)
                    .multilineTextAlignment(.leading)
            }

            VStack(alignment: .leading, spacing: 6) {
                Text("Starter Prompt")
                    .font(Typography.micro)
                    .foregroundStyle(DesignSystem.Colors.textMuted)

                Text(data.prompt)
                    .font(Typography.caption)
                    .foregroundStyle(DesignSystem.Colors.textSecondary)
                    .lineLimit(3)
                    .multilineTextAlignment(.leading)
            }
            .padding(.horizontal, Spacing.sm)
            .padding(.vertical, Spacing.xs + 2)
            .background(
                RoundedRectangle(cornerRadius: Spacing.radiusSm, style: .continuous)
                    .fill(Color.primary.opacity(0.06))
            )

            HStack(spacing: Spacing.xs) {
                ForEach(Array(data.tags.prefix(3)), id: \.self) { tag in
                    Text(tag)
                        .font(Typography.micro)
                        .foregroundStyle(DesignSystem.Colors.textSecondary)
                        .padding(.horizontal, Spacing.sm)
                        .padding(.vertical, Spacing.xxs)
                        .background(
                            Capsule()
                                .fill(DesignSystem.Colors.accentSubtle)
                        )
                }
                Spacer()
            }

            HStack(spacing: Spacing.xs) {
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
        .frame(maxWidth: .infinity, minHeight: 220, alignment: .topLeading)
        .padding(Spacing.md)
        .background(
            RoundedRectangle(cornerRadius: Spacing.radiusMd, style: .continuous)
                .fill(Color.primary.opacity(0.03))
        )
        .glassEffect(
            .regular.tint(data.gradientColors.last?.opacity(isHovered ? 0.2 : 0.14) ?? DesignSystem.Colors.accent.opacity(0.12)).interactive(),
            in: RoundedRectangle(cornerRadius: Spacing.radiusMd, style: .continuous)
        )
        .overlay(
            RoundedRectangle(cornerRadius: Spacing.radiusMd, style: .continuous)
                .strokeBorder(
                    isHovered ? DesignSystem.Colors.borderHover : DesignSystem.Colors.border,
                    lineWidth: 1
                )
        )
        .shadow(
            color: DesignSystem.Colors.accent.opacity(isHovered ? 0.16 : 0.08),
            radius: isHovered ? 12 : 6,
            y: isHovered ? 5 : 3
        )
        .contentShape(RoundedRectangle(cornerRadius: Spacing.radiusMd, style: .continuous))
        .gesture(
            TapGesture().onEnded {
                onApply(defaultApplyMode)
            },
            including: .gesture
        )
        .scaleEffect(isHovered ? 1.01 : 1)
        .onHover { hovering in
            withAnimation(DesignSystem.Animations.quick) {
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

    var icon: String {
        switch self {
        case .all: return "square.grid.2x2"
        case .instrumental: return "pianokeys"
        case .lyrics: return "music.mic"
        }
    }
}

private enum SuggestionLanguageFilter: Hashable, Identifiable {
    case all
    case language(SuggestionLanguage)

    var id: String {
        switch self {
        case .all:
            return "all_languages"
        case let .language(language):
            return language.rawValue
        }
    }

    var title: String {
        switch self {
        case .all:
            return "Any Language"
        case let .language(language):
            return language.rawValue
        }
    }

    var icon: String {
        switch self {
        case .all:
            return "globe"
        case let .language(language):
            return language.icon
        }
    }
}

struct SuggestionGrid: View {
    let suggestions: [SuggestionData]
    let onSelect: (SuggestionData, SuggestionApplyMode) -> Void
    let onRefresh: () -> Void

    @State private var selectedFilter: SuggestionFilter = .all
    @State private var selectedLanguageFilter: SuggestionLanguageFilter = .all
    @State private var isRefreshHovered = false

    var body: some View {
        VStack(alignment: .leading, spacing: Spacing.md) {
            HStack(alignment: .top) {
                VStack(alignment: .leading, spacing: 4) {
                    HStack(spacing: Spacing.xs) {
                        Image(systemName: "wand.and.stars")
                            .font(.system(size: 12, weight: .semibold))
                            .foregroundStyle(DesignSystem.Colors.accent)

                        Text("Suggestions")
                            .font(Typography.title3)
                            .foregroundStyle(DesignSystem.Colors.textPrimary)
                    }

                    Text("\(filteredSuggestions.count) curated starters ready")
                        .font(Typography.caption2)
                        .foregroundStyle(DesignSystem.Colors.textPrimary)
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
                    .padding(.horizontal, Spacing.sm)
                    .padding(.vertical, Spacing.xs)
                    .background(
                        Capsule()
                            .fill(Color.primary.opacity(isRefreshHovered ? 0.09 : 0.05))
                    )
                }
                .buttonStyle(.plain)
                .onHover { hovering in
                    isRefreshHovered = hovering
                }
                .help("Refresh suggestions")
            }

            VStack(alignment: .leading, spacing: Spacing.sm) {
                ScrollView(.horizontal, showsIndicators: false) {
                    HStack(spacing: Spacing.xs) {
                        ForEach(SuggestionFilter.allCases) { filter in
                            SuggestionFilterChip(
                                title: filter.rawValue,
                                icon: filter.icon,
                                isSelected: selectedFilter == filter,
                                action: { selectedFilter = filter }
                            )
                        }
                    }
                }

                ScrollView(.horizontal, showsIndicators: false) {
                    HStack(spacing: Spacing.xs) {
                        ForEach(languageFilters) { filter in
                            SuggestionFilterChip(
                                title: filter.title,
                                icon: filter.icon,
                                isSelected: selectedLanguageFilter == filter,
                                action: { selectedLanguageFilter = filter }
                            )
                        }
                    }
                }
            }

            let columns = [GridItem(.adaptive(minimum: 230, maximum: 360), spacing: Spacing.sm)]
            if filteredSuggestions.isEmpty {
                HStack(spacing: Spacing.xs) {
                    Image(systemName: "lightbulb")
                        .font(.system(size: 12))
                        .foregroundStyle(DesignSystem.Colors.textMuted)

                    Text("No matches in this set. Try Shuffle or switch filters.")
                        .font(Typography.caption)
                        .foregroundStyle(DesignSystem.Colors.textMuted)
                }
                .padding(.vertical, 6)
            } else {
                LoopMakerGlassContainer(spacing: Spacing.sm) {
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
        .padding(Spacing.md)
        .background(
            RoundedRectangle(cornerRadius: Spacing.radiusLg, style: .continuous)
                .fill(Color.primary.opacity(0.025))
        )
        .glassEffect(
            .regular.tint(DesignSystem.Colors.accent.opacity(0.06)),
            in: RoundedRectangle(cornerRadius: Spacing.radiusLg, style: .continuous)
        )
        .overlay(
            RoundedRectangle(cornerRadius: Spacing.radiusLg, style: .continuous)
                .strokeBorder(DesignSystem.Colors.border, lineWidth: 1)
        )
    }

    private var filteredSuggestions: [SuggestionData] {
        let typeFiltered: [SuggestionData]
        switch selectedFilter {
        case .all:
            typeFiltered = suggestions
        case .instrumental:
            typeFiltered = suggestions.filter { $0.kind == .instrumental }
        case .lyrics:
            typeFiltered = suggestions.filter { $0.kind == .lyrics }
        }

        switch selectedLanguageFilter {
        case .all:
            return typeFiltered
        case let .language(language):
            return typeFiltered.filter { $0.language == language }
        }
    }

    private var languageFilters: [SuggestionLanguageFilter] {
        let languages = Set(suggestions.map(\.language))
            .sorted { $0.order < $1.order }

        return [.all] + languages.map { .language($0) }
    }
}

private struct SuggestionBadge: View {
    let title: String
    let icon: String
    let tint: Color

    var body: some View {
        HStack(spacing: Spacing.xxs) {
            Image(systemName: icon)
                .font(.system(size: 9, weight: .semibold))
            Text(title)
                .font(Typography.micro)
        }
        .foregroundStyle(tint)
        .padding(.horizontal, Spacing.xs + 2)
        .padding(.vertical, Spacing.xxs + 1)
        .background(
            Capsule()
                .fill(tint.opacity(0.14))
        )
    }
}

private struct SuggestionActionButton: View {
    let title: String
    let emphasized: Bool
    let action: () -> Void

    @State private var isHovered = false

    var body: some View {
        Button(action: action) {
            Text(title)
                .font(Typography.captionSemibold)
                .foregroundStyle(emphasized ? Color.white : DesignSystem.Colors.textSecondary)
                .padding(.horizontal, Spacing.sm)
                .padding(.vertical, Spacing.xs + 1)
                .frame(maxWidth: .infinity)
                .background(
                    RoundedRectangle(cornerRadius: 7, style: .continuous)
                        .fill(background)
                )
                .overlay(
                    RoundedRectangle(cornerRadius: 7, style: .continuous)
                        .strokeBorder(border, lineWidth: 1)
                )
        }
        .buttonStyle(.plain)
        .onHover { hovering in
            withAnimation(DesignSystem.Animations.quick) {
                isHovered = hovering
            }
        }
    }

    private var background: Color {
        if emphasized {
            return isHovered ? DesignSystem.Colors.accentHover : DesignSystem.Colors.accent
        }
        return isHovered ? DesignSystem.Colors.surfaceHover : DesignSystem.Colors.surface
    }

    private var border: Color {
        emphasized ? DesignSystem.Colors.accent.opacity(0.45) : DesignSystem.Colors.border
    }
}

private struct SuggestionFilterChip: View {
    let title: String
    let icon: String
    let isSelected: Bool
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            HStack(spacing: Spacing.xxs) {
                Image(systemName: icon)
                    .font(.system(size: 10, weight: .semibold))
                    .foregroundStyle(isSelected ? DesignSystem.Colors.accent : DesignSystem.Colors.textMuted)

                Text(title)
                    .font(Typography.captionMedium)
                    .foregroundStyle(isSelected ? DesignSystem.Colors.accent : DesignSystem.Colors.textSecondary)
            }
            .padding(.horizontal, Spacing.sm + 1)
            .padding(.vertical, Spacing.xs)
            .background(
                Capsule()
                    .fill(isSelected ? DesignSystem.Colors.accentSubtle : DesignSystem.Colors.surface)
            )
            .overlay(
                Capsule()
                    .strokeBorder(
                        isSelected ? DesignSystem.Colors.accent.opacity(0.35) : DesignSystem.Colors.border,
                        lineWidth: 1
                    )
            )
        }
        .buttonStyle(.plain)
    }
}

// MARK: - Preview

#if PREVIEWS
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
#endif
