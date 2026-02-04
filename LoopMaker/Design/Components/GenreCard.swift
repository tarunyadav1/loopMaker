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
            gradientColors: [Color(hex: "8B5CF6"), Color(hex: "6D28D9")]
        ),
        GenreCardData(
            name: "Cinematic",
            icon: "film",
            gradientColors: [Color(hex: "F59E0B"), Color(hex: "D97706")]
        ),
        GenreCardData(
            name: "Ambient",
            icon: "cloud",
            gradientColors: [Color(hex: "06B6D4"), Color(hex: "0891B2")]
        ),
        GenreCardData(
            name: "Electronic",
            icon: "waveform",
            gradientColors: [Color(hex: "EC4899"), Color(hex: "DB2777")]
        ),
        GenreCardData(
            name: "Hip-Hop",
            icon: "beats.headphones",
            gradientColors: [Color(hex: "EF4444"), Color(hex: "DC2626")]
        ),
        GenreCardData(
            name: "Jazz",
            icon: "music.quarternote.3",
            gradientColors: [Color(hex: "10B981"), Color(hex: "059669")]
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
            VStack(alignment: .leading, spacing: Spacing.sm) {
                // Icon
                Image(systemName: data.icon)
                    .font(.system(size: 24))
                    .foregroundStyle(.white)

                Spacer()

                // Name
                Text(data.name)
                    .font(Typography.headline)
                    .foregroundStyle(.white)
            }
            .padding(Spacing.md)
            .frame(width: Spacing.genreCardWidth, height: Spacing.genreCardHeight)
            .background(
                ZStack {
                    // Gradient background
                    RoundedRectangle(cornerRadius: Spacing.radiusMd)
                        .fill(
                            LinearGradient(
                                colors: data.gradientColors,
                                startPoint: .topLeading,
                                endPoint: .bottomTrailing
                            )
                        )

                    // Hover overlay
                    if isHovered {
                        RoundedRectangle(cornerRadius: Spacing.radiusMd)
                            .fill(Color.white.opacity(0.1))
                    }

                    // Selection ring
                    if isSelected {
                        RoundedRectangle(cornerRadius: Spacing.radiusMd)
                            .strokeBorder(Color.white, lineWidth: 2)
                    }
                }
            )
            .scaleEffect(isHovered ? 1.02 : 1)
            .shadow(
                color: data.gradientColors[0].opacity(isHovered ? 0.4 : 0.2),
                radius: isHovered ? 12 : 8,
                y: isHovered ? 6 : 4
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
