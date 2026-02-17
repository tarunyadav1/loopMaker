import SwiftUI

// MARK: - Genre Card Data

struct GenreCardData: Identifiable {
    let id = UUID()
    let name: String
    let icon: String
    let gradientColors: [Color]

    static let presets: [GenreCardData] = [
        GenreCardData(
            name: "Lo-Fi",
            icon: "headphones",
            gradientColors: [Color(hex: "1E1B4B"), Color(hex: "3730A3"), Color(hex: "4F46B5")]
        ),
        GenreCardData(
            name: "Cinematic",
            icon: "film",
            gradientColors: [Color(hex: "451A03"), Color(hex: "92400E"), Color(hex: "B45309")]
        ),
        GenreCardData(
            name: "Ambient",
            icon: "cloud",
            gradientColors: [Color(hex: "042F2E"), Color(hex: "115E59"), Color(hex: "0F766E")]
        ),
        GenreCardData(
            name: "Electronic",
            icon: "waveform",
            gradientColors: [Color(hex: "4A0D29"), Color(hex: "831843"), Color(hex: "9D174D")]
        ),
        GenreCardData(
            name: "Hip-Hop",
            icon: "beats.headphones",
            gradientColors: [Color(hex: "450A0A"), Color(hex: "7F1D1D"), Color(hex: "991B1B")]
        ),
        GenreCardData(
            name: "Jazz",
            icon: "music.quarternote.3",
            gradientColors: [Color(hex: "052E16"), Color(hex: "14532D"), Color(hex: "166534")]
        )
    ]
}

// MARK: - Genre Card

struct GenreCard: View {
    let data: GenreCardData
    var isSelected: Bool = false
    var onTap: () -> Void = {}

    @State private var isHovered = false

    var body: some View {
        Button(action: onTap) {
            ZStack(alignment: .bottomLeading) {
                // Gradient background
                RoundedRectangle(cornerRadius: 12)
                    .fill(
                        LinearGradient(
                            colors: data.gradientColors,
                            startPoint: .topLeading,
                            endPoint: .bottomTrailing
                        )
                    )

                // Subtle noise overlay
                RoundedRectangle(cornerRadius: 12)
                    .fill(Color.white.opacity(0.04))

                // Hover brightness overlay
                if isHovered {
                    RoundedRectangle(cornerRadius: 12)
                        .fill(Color.white.opacity(0.08))
                }

                // Icon top-right
                VStack {
                    HStack {
                        Spacer()
                        Image(systemName: data.icon)
                            .font(.system(size: 18, weight: .medium))
                            .foregroundStyle(.white.opacity(0.4))
                            .padding(Spacing.md)
                    }
                    Spacer()
                }

                // Name bottom-left
                Text(data.name)
                    .font(.system(size: 15, weight: .bold, design: .rounded))
                    .foregroundStyle(.white)
                    .padding(Spacing.md)
            }
            .frame(width: Spacing.genreCardWidth, height: Spacing.genreCardHeight)
            .overlay(
                RoundedRectangle(cornerRadius: 12)
                    .strokeBorder(
                        isSelected ? DesignSystem.Colors.accent : Color.clear,
                        lineWidth: 1.5
                    )
            )
            .scaleEffect(isHovered ? 1.03 : 1)
            .brightness(isHovered ? 0.05 : 0)
            .shadow(
                color: data.gradientColors[1].opacity(isHovered ? 0.3 : 0.15),
                radius: isHovered ? 12 : 6,
                y: isHovered ? 4 : 2
            )
        }
        .buttonStyle(.plain)
        .onHover { hovering in
            withAnimation(.easeInOut(duration: 0.2)) {
                isHovered = hovering
            }
        }
    }
}

// MARK: - Preview

#if PREVIEWS
#Preview {
    ZStack {
        Theme.background.ignoresSafeArea()

        HStack(spacing: Spacing.md) {
            ForEach(GenreCardData.presets.prefix(3)) { genre in
                GenreCard(data: genre)
            }
        }
        .padding()
    }
}
#endif
