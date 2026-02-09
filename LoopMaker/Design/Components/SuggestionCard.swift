import SwiftUI

// MARK: - Suggestion Card Data

struct SuggestionData: Identifiable {
    let id = UUID()
    let title: String
    let subtitle: String
    let gradientColors: [Color]

    static let defaults: [SuggestionData] = [
        SuggestionData(
            title: "A dreamy lo-fi study session",
            subtitle: "vinyl crackle, soft piano, mellow beats",
            gradientColors: [Color(hex: "1E1B4B"), Color(hex: "3730A3")]
        ),
        SuggestionData(
            title: "An epic cinematic trailer moment",
            subtitle: "rising strings, brass hits, dramatic tension",
            gradientColors: [Color(hex: "451A03"), Color(hex: "92400E")]
        ),
        SuggestionData(
            title: "A haunting ambient soundscape",
            subtitle: "ethereal pads, distant reverb, slow drones",
            gradientColors: [Color(hex: "042F2E"), Color(hex: "115E59")]
        ),
        SuggestionData(
            title: "An energetic dance floor anthem",
            subtitle: "driving bass, synth leads, four-on-the-floor",
            gradientColors: [Color(hex: "4A0D29"), Color(hex: "831843")]
        ),
        SuggestionData(
            title: "A smooth jazz evening at a club",
            subtitle: "saxophone solo, brushed drums, upright bass",
            gradientColors: [Color(hex: "052E16"), Color(hex: "166534")]
        ),
        SuggestionData(
            title: "A chill hip-hop beat to relax to",
            subtitle: "808 bass, trap hi-hats, mellow melody",
            gradientColors: [Color(hex: "450A0A"), Color(hex: "7F1D1D")]
        ),
        SuggestionData(
            title: "A nostalgic synthwave night drive",
            subtitle: "retro synths, arpeggios, neon atmosphere",
            gradientColors: [Color(hex: "2E1065"), Color(hex: "7C3AED")]
        ),
        SuggestionData(
            title: "A gentle acoustic morning",
            subtitle: "fingerpicked guitar, soft vocals, warm feel",
            gradientColors: [Color(hex: "422006"), Color(hex: "A16207")]
        )
    ]

    /// Returns 4 random suggestions
    static func randomSet() -> [SuggestionData] {
        Array(defaults.shuffled().prefix(4))
    }
}

// MARK: - Suggestion Card

struct SuggestionCard: View {
    let data: SuggestionData
    let onTap: () -> Void

    @State private var isHovered = false

    var body: some View {
        Button(action: onTap) {
            VStack(alignment: .leading, spacing: 8) {
                Text(data.title)
                    .font(.system(size: 13, weight: .semibold))
                    .foregroundStyle(.white)
                    .lineLimit(2)
                    .multilineTextAlignment(.leading)

                Text(data.subtitle)
                    .font(.system(size: 11, weight: .regular))
                    .foregroundStyle(.white.opacity(0.7))
                    .lineLimit(2)
                    .multilineTextAlignment(.leading)
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
                    .fill(Color.white.opacity(isHovered ? 0.08 : 0))
            )
            .scaleEffect(isHovered ? 1.02 : 1)
        }
        .buttonStyle(.plain)
        .onHover { hovering in
            withAnimation(.easeInOut(duration: 0.15)) {
                isHovered = hovering
            }
        }
    }
}

// MARK: - Suggestion Grid

struct SuggestionGrid: View {
    let suggestions: [SuggestionData]
    let onSelect: (SuggestionData) -> Void
    let onRefresh: () -> Void

    @State private var isRefreshHovered = false

    var body: some View {
        VStack(alignment: .leading, spacing: Spacing.sm) {
            HStack {
                Text("Suggestions")
                    .font(Typography.title3)
                    .foregroundStyle(DesignSystem.Colors.textPrimary)

                Spacer()

                Button(action: onRefresh) {
                    Image(systemName: "arrow.triangle.2.circlepath")
                        .font(.system(size: 12, weight: .medium))
                        .foregroundStyle(isRefreshHovered ? DesignSystem.Colors.textPrimary : DesignSystem.Colors.textSecondary)
                }
                .buttonStyle(.plain)
                .onHover { hovering in
                    isRefreshHovered = hovering
                }
                .help("Refresh suggestions")
            }

            // 2x2 grid
            let columns = [
                GridItem(.flexible(), spacing: Spacing.sm),
                GridItem(.flexible(), spacing: Spacing.sm)
            ]

            LazyVGrid(columns: columns, spacing: Spacing.sm) {
                ForEach(suggestions) { suggestion in
                    SuggestionCard(data: suggestion) {
                        onSelect(suggestion)
                    }
                }
            }
        }
    }
}

// MARK: - Preview

#Preview {
    ZStack {
        Color(nsColor: .windowBackgroundColor).ignoresSafeArea()

        SuggestionGrid(
            suggestions: Array(SuggestionData.defaults.prefix(4)),
            onSelect: { _ in },
            onRefresh: {}
        )
        .padding(24)
        .frame(maxWidth: 500)
    }
}
