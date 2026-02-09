import SwiftUI

// MARK: - Glass Card

struct GlassCard<Content: View>: View {
    let content: Content
    var padding: CGFloat = Spacing.md
    var cornerRadius: CGFloat = Spacing.radiusMd

    init(
        padding: CGFloat = Spacing.md,
        cornerRadius: CGFloat = Spacing.radiusMd,
        @ViewBuilder content: () -> Content
    ) {
        self.content = content()
        self.padding = padding
        self.cornerRadius = cornerRadius
    }

    var body: some View {
        content
            .padding(padding)
            .glassEffect(
                .regular,
                in: .rect(cornerRadius: cornerRadius)
            )
    }
}

// MARK: - Glass Background Modifier

struct GlassBackgroundModifier: ViewModifier {
    var cornerRadius: CGFloat = Spacing.radiusMd

    func body(content: Content) -> some View {
        content
            .glassEffect(.regular, in: .rect(cornerRadius: cornerRadius))
    }
}

extension View {
    func glassBackground(cornerRadius: CGFloat = Spacing.radiusMd) -> some View {
        modifier(GlassBackgroundModifier(cornerRadius: cornerRadius))
    }
}

// MARK: - Preview

#Preview {
    ZStack {
        Theme.background.ignoresSafeArea()

        VStack(spacing: Spacing.lg) {
            GlassCard {
                Text("Glass Card Content")
                    .foregroundStyle(Theme.textPrimary)
            }

            Text("With glass background modifier")
                .foregroundStyle(Theme.textPrimary)
                .padding()
                .glassBackground()
        }
        .padding()
    }
}
