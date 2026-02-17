import SwiftUI

// MARK: - Genre Card Grid

struct GenreCardGrid: View {
    let genres: [GenreCardData]
    @Binding var selectedGenre: GenreCardData?
    var onSelect: (GenreCardData) -> Void = { _ in }

    var body: some View {
        VStack(alignment: .leading, spacing: Spacing.md) {
            // Section header
            Text("Quick Start")
                .font(Typography.title3)
                .foregroundStyle(Theme.textPrimary)

            // Horizontal scroll
            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: Spacing.md) {
                    ForEach(genres) { genre in
                        GenreCard(
                            data: genre,
                            isSelected: selectedGenre?.id == genre.id,
                            onTap: {
                                withAnimation(.easeInOut(duration: 0.2)) {
                                    selectedGenre = genre
                                }
                                onSelect(genre)
                            }
                        )
                    }
                }
                .padding(.horizontal, Spacing.xs)
                .padding(.vertical, Spacing.sm)
            }
        }
    }
}

// MARK: - Preview

#if PREVIEWS
#Preview {
    ZStack {
        Theme.background.ignoresSafeArea()

        GenreCardGrid(
            genres: GenreCardData.presets,
            selectedGenre: .constant(nil)
        )
        .padding()
    }
}
#endif
