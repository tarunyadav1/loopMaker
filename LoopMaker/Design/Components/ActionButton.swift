import SwiftUI

// MARK: - Button Variant

enum ActionButtonVariant {
    case primary
    case secondary
    case outline
    case ghost
    case gradient
}

// MARK: - Button Size

enum ActionButtonSize {
    case small
    case medium
    case large

    var horizontalPadding: CGFloat {
        switch self {
        case .small: return Spacing.sm
        case .medium: return Spacing.md
        case .large: return Spacing.lg
        }
    }

    var verticalPadding: CGFloat {
        switch self {
        case .small: return Spacing.xs
        case .medium: return Spacing.sm
        case .large: return Spacing.md
        }
    }

    var font: Font {
        switch self {
        case .small: return Typography.caption
        case .medium: return Typography.bodyMedium
        case .large: return Typography.headline
        }
    }
}

// MARK: - Action Button

struct ActionButton: View {
    let title: String
    var icon: String?
    var variant: ActionButtonVariant = .primary
    var size: ActionButtonSize = .medium
    var isEnabled: Bool = true
    var isLoading: Bool = false
    var action: () -> Void

    @State private var isHovered = false
    @State private var isPressed = false

    var body: some View {
        Button(action: action) {
            HStack(spacing: Spacing.sm) {
                if isLoading {
                    ProgressView()
                        .progressViewStyle(.circular)
                        .scaleEffect(0.8)
                        .tint(textColor)
                } else if let icon = icon {
                    Image(systemName: icon)
                        .font(size.font)
                }

                Text(title)
                    .font(size.font)
            }
            .foregroundStyle(textColor)
            .padding(.horizontal, size.horizontalPadding)
            .padding(.vertical, size.verticalPadding)
            .frame(minHeight: size == .small ? 28 : (size == .medium ? 36 : 44))
            .background(background)
            .overlay(border)
            .opacity(isEnabled ? 1 : 0.5)
            .scaleEffect(isPressed ? 0.98 : 1)
        }
        .buttonStyle(.plain)
        .disabled(!isEnabled || isLoading)
        .onHover { hovering in
            isHovered = hovering
        }
        .simultaneousGesture(
            DragGesture(minimumDistance: 0)
                .onChanged { _ in isPressed = true }
                .onEnded { _ in isPressed = false }
        )
        .animation(.easeInOut(duration: 0.1), value: isHovered)
        .animation(.easeInOut(duration: 0.1), value: isPressed)
    }

    private var textColor: Color {
        switch variant {
        case .primary, .gradient:
            return .white
        case .secondary:
            return Theme.textPrimary
        case .outline, .ghost:
            return isHovered ? Theme.textPrimary : Theme.textSecondary
        }
    }

    @ViewBuilder
    private var background: some View {
        switch variant {
        case .primary:
            RoundedRectangle(cornerRadius: Spacing.radiusSm)
                .fill(isHovered ? Theme.accentPrimary.opacity(0.8) : Theme.accentPrimary)

        case .secondary:
            RoundedRectangle(cornerRadius: Spacing.radiusSm)
                .fill(isHovered ? Theme.backgroundTertiary : Theme.backgroundSecondary)

        case .outline:
            RoundedRectangle(cornerRadius: Spacing.radiusSm)
                .fill(isHovered ? Theme.backgroundTertiary.opacity(0.5) : Color.clear)

        case .ghost:
            RoundedRectangle(cornerRadius: Spacing.radiusSm)
                .fill(isHovered ? Theme.backgroundTertiary.opacity(0.5) : Color.clear)

        case .gradient:
            RoundedRectangle(cornerRadius: Spacing.radiusSm)
                .fill(Theme.accentGradient)
                .opacity(isHovered ? 0.9 : 1)
        }
    }

    @ViewBuilder
    private var border: some View {
        switch variant {
        case .outline:
            RoundedRectangle(cornerRadius: Spacing.radiusSm)
                .strokeBorder(Theme.glassBorder, lineWidth: 1)
        default:
            EmptyView()
        }
    }
}

// MARK: - Preview

#Preview {
    ZStack {
        Theme.background.ignoresSafeArea()

        VStack(spacing: Spacing.md) {
            ActionButton(title: "Primary", icon: "play.fill", variant: .primary) {}

            ActionButton(title: "Secondary", icon: "square.grid.2x2", variant: .secondary) {}

            ActionButton(title: "Outline", icon: "arrow.down.circle", variant: .outline) {}

            ActionButton(title: "Ghost", variant: .ghost) {}

            ActionButton(title: "Gradient", icon: "sparkles", variant: .gradient) {}

            ActionButton(title: "Loading...", variant: .primary, isLoading: true) {}

            ActionButton(title: "Disabled", variant: .primary, isEnabled: false) {}
        }
        .padding()
    }
}
