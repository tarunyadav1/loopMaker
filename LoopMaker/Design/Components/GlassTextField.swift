import SwiftUI

// MARK: - Glass Text Field

struct GlassTextField: View {
    @Binding var text: String
    let placeholder: String
    var icon: String = "wand.and.stars"
    var submitLabel: String = "Generate"
    var isEnabled: Bool = true
    var onSubmit: () -> Void = {}

    @FocusState private var isFocused: Bool
    @State private var isHovered = false

    var body: some View {
        HStack(spacing: Spacing.sm) {
            // Icon
            Image(systemName: icon)
                .font(.system(size: 18))
                .foregroundStyle(Theme.accentPrimary)
                .frame(width: 24)

            // Text field
            TextField(placeholder, text: $text)
                .textFieldStyle(.plain)
                .font(Typography.body)
                .foregroundStyle(Theme.textPrimary)
                .focused($isFocused)
                .onSubmit {
                    if isEnabled && !text.isEmpty {
                        onSubmit()
                    }
                }

            // Submit button
            Button(action: onSubmit) {
                Text(submitLabel)
                    .font(Typography.bodyMedium)
                    .foregroundStyle(Theme.textPrimary)
                    .padding(.horizontal, Spacing.md)
                    .padding(.vertical, Spacing.sm)
                    .background(
                        RoundedRectangle(cornerRadius: Spacing.radiusSm)
                            .fill(isEnabled && !text.isEmpty ? Theme.accentPrimary : Theme.backgroundTertiary)
                    )
            }
            .buttonStyle(.plain)
            .disabled(!isEnabled || text.isEmpty)
        }
        .padding(.horizontal, Spacing.md)
        .padding(.vertical, Spacing.sm)
        .background(
            ZStack {
                RoundedRectangle(cornerRadius: Spacing.radiusMd)
                    .fill(.ultraThinMaterial)
                    .environment(\.colorScheme, .dark)

                RoundedRectangle(cornerRadius: Spacing.radiusMd)
                    .fill(Theme.glassGradient)

                RoundedRectangle(cornerRadius: Spacing.radiusMd)
                    .strokeBorder(
                        isFocused ? Theme.accentPrimary.opacity(0.5) : Theme.glassBorder,
                        lineWidth: isFocused ? 2 : 1
                    )
            }
        )
        .onHover { hovering in
            isHovered = hovering
        }
        .animation(.easeInOut(duration: 0.15), value: isFocused)
    }
}

// MARK: - Preview

#Preview {
    ZStack {
        Theme.background.ignoresSafeArea()

        VStack(spacing: Spacing.lg) {
            GlassTextField(
                text: .constant(""),
                placeholder: "Describe the music you want to create...",
                onSubmit: {}
            )

            GlassTextField(
                text: .constant("Upbeat lo-fi beats with piano"),
                placeholder: "Describe the music you want to create...",
                onSubmit: {}
            )
        }
        .padding(Spacing.xl)
    }
}
