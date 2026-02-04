import SwiftUI

// MARK: - Spacing Constants

enum Spacing {
    // MARK: - Base Spacing

    static let xs: CGFloat = 4
    static let sm: CGFloat = 8
    static let md: CGFloat = 16
    static let lg: CGFloat = 24
    static let xl: CGFloat = 32
    static let xxl: CGFloat = 48

    // MARK: - Component Dimensions

    static let sidebarWidth: CGFloat = 260
    static let playerBarHeight: CGFloat = 80
    static let genreCardWidth: CGFloat = 180
    static let genreCardHeight: CGFloat = 100
    static let trackRowHeight: CGFloat = 64
    static let buttonHeight: CGFloat = 44
    static let iconButtonSize: CGFloat = 36
    static let searchBarHeight: CGFloat = 40

    // MARK: - Corner Radius

    static let radiusXs: CGFloat = 4
    static let radiusSm: CGFloat = 8
    static let radiusMd: CGFloat = 12
    static let radiusLg: CGFloat = 16
    static let radiusXl: CGFloat = 20
    static let radiusFull: CGFloat = 9999
}

// MARK: - Padding View Extension

extension View {
    func paddingSmall() -> some View {
        self.padding(Spacing.sm)
    }

    func paddingMedium() -> some View {
        self.padding(Spacing.md)
    }

    func paddingLarge() -> some View {
        self.padding(Spacing.lg)
    }
}
