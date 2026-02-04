import SwiftUI

// MARK: - Typography Scale

enum Typography {
    // MARK: - Font Sizes

    static let heroSize: CGFloat = 48
    static let title1Size: CGFloat = 32
    static let title2Size: CGFloat = 24
    static let title3Size: CGFloat = 20
    static let headlineSize: CGFloat = 17
    static let bodySize: CGFloat = 15
    static let captionSize: CGFloat = 13
    static let caption2Size: CGFloat = 11

    // MARK: - Fonts

    static let hero = Font.system(size: heroSize, weight: .bold, design: .rounded)
    static let title1 = Font.system(size: title1Size, weight: .bold, design: .rounded)
    static let title2 = Font.system(size: title2Size, weight: .semibold, design: .rounded)
    static let title3 = Font.system(size: title3Size, weight: .semibold, design: .rounded)
    static let headline = Font.system(size: headlineSize, weight: .semibold, design: .default)
    static let body = Font.system(size: bodySize, weight: .regular, design: .default)
    static let bodyMedium = Font.system(size: bodySize, weight: .medium, design: .default)
    static let caption = Font.system(size: captionSize, weight: .regular, design: .default)
    static let captionMedium = Font.system(size: captionSize, weight: .medium, design: .default)
    static let caption2 = Font.system(size: caption2Size, weight: .regular, design: .default)
}

// MARK: - View Modifiers

extension View {
    func heroText() -> some View {
        self
            .font(Typography.hero)
            .foregroundStyle(Theme.textPrimary)
    }

    func title1Text() -> some View {
        self
            .font(Typography.title1)
            .foregroundStyle(Theme.textPrimary)
    }

    func title2Text() -> some View {
        self
            .font(Typography.title2)
            .foregroundStyle(Theme.textPrimary)
    }

    func title3Text() -> some View {
        self
            .font(Typography.title3)
            .foregroundStyle(Theme.textPrimary)
    }

    func headlineText() -> some View {
        self
            .font(Typography.headline)
            .foregroundStyle(Theme.textPrimary)
    }

    func bodyText() -> some View {
        self
            .font(Typography.body)
            .foregroundStyle(Theme.textSecondary)
    }

    func captionText() -> some View {
        self
            .font(Typography.caption)
            .foregroundStyle(Theme.textTertiary)
    }
}
