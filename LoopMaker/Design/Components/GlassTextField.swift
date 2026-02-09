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
                    .foregroundStyle(isEnabled && !text.isEmpty ? .white : Theme.textSecondary)
                    .padding(.horizontal, Spacing.md)
                    .padding(.vertical, Spacing.sm)
                    .background(
                        RoundedRectangle(cornerRadius: Spacing.radiusSm)
                            .fill(isEnabled && !text.isEmpty ? Theme.accentPrimary : Color.primary.opacity(0.1))
                    )
            }
            .buttonStyle(.plain)
            .disabled(!isEnabled || text.isEmpty)
        }
        .padding(.horizontal, Spacing.md)
        .padding(.vertical, Spacing.sm)
        .background(
            RoundedRectangle(cornerRadius: Spacing.radiusMd)
                .fill(Color.primary.opacity(isFocused ? 0.08 : 0.05))
        )
        .overlay(
            RoundedRectangle(cornerRadius: Spacing.radiusMd)
                .strokeBorder(
                    isFocused ? Theme.accentPrimary.opacity(0.4) : Color.primary.opacity(0.1),
                    lineWidth: 1
                )
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
