import SwiftUI

// MARK: - Search Bar

struct SearchBar: View {
    @Binding var text: String
    var placeholder: String = "Search..."
    var showShortcut: Bool = false
    var onCommit: () -> Void = {}

    @FocusState private var isFocused: Bool
    @State private var isHovered = false

    var body: some View {
        HStack(spacing: Spacing.sm) {
            Image(systemName: "magnifyingglass")
                .font(.system(size: 14))
                .foregroundStyle(Theme.textTertiary)

            TextField(placeholder, text: $text)
                .textFieldStyle(.plain)
                .font(Typography.body)
                .foregroundStyle(Theme.textPrimary)
                .focused($isFocused)
                .onSubmit(onCommit)

            if showShortcut && text.isEmpty {
                Text("\u{2318}K")
                    .font(Typography.caption)
                    .foregroundStyle(Theme.textTertiary)
                    .padding(.horizontal, Spacing.xs)
                    .padding(.vertical, 2)
                    .background(
                        RoundedRectangle(cornerRadius: Spacing.radiusXs)
                            .fill(Theme.backgroundTertiary)
                    )
            }

            if !text.isEmpty {
                Button(action: { text = "" }) {
                    Image(systemName: "xmark.circle.fill")
                        .font(.system(size: 14))
                        .foregroundStyle(Theme.textTertiary)
                }
                .buttonStyle(.plain)
            }
        }
        .padding(.horizontal, Spacing.sm)
        .frame(height: Spacing.searchBarHeight)
        .background(
            RoundedRectangle(cornerRadius: Spacing.radiusSm)
                .fill(Theme.backgroundTertiary.opacity(isHovered ? 1 : 0.8))
        )
        .overlay(
            RoundedRectangle(cornerRadius: Spacing.radiusSm)
                .strokeBorder(
                    isFocused ? Theme.accentPrimary.opacity(0.5) : Color.clear,
                    lineWidth: 1
                )
        )
        .onHover { hovering in
            isHovered = hovering
        }
        .animation(.easeInOut(duration: 0.15), value: isFocused)
        .animation(.easeInOut(duration: 0.15), value: isHovered)
    }
}

// MARK: - Preview

#Preview {
    ZStack {
        Theme.background.ignoresSafeArea()

        VStack(spacing: Spacing.lg) {
            SearchBar(text: .constant(""))

            SearchBar(text: .constant("Lo-fi beats"))
        }
        .padding()
        .frame(width: 280)
    }
}
