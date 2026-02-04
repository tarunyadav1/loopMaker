import SwiftUI

// MARK: - Color Palette

enum Theme {
    // MARK: - Background Colors

    static let background = Color(hex: "0D0D0D")
    static let backgroundSecondary = Color(hex: "1A1A1A")
    static let backgroundTertiary = Color(hex: "252525")

    // MARK: - Text Colors

    static let textPrimary = Color.white
    static let textSecondary = Color.white.opacity(0.7)
    static let textTertiary = Color.white.opacity(0.5)

    // MARK: - Accent Colors

    static let accentPrimary = Color(hex: "8B5CF6")   // Purple
    static let accentSecondary = Color(hex: "06B6D4") // Cyan

    // MARK: - Semantic Colors

    static let success = Color(hex: "22C55E")
    static let warning = Color(hex: "EAB308")
    static let error = Color(hex: "EF4444")

    // MARK: - Glass Effect Colors

    static let glassBorder = Color.white.opacity(0.08)
    static let glassHighlight = Color.white.opacity(0.1)
    static let glassShadow = Color.black.opacity(0.3)

    // MARK: - Gradients

    static let backgroundGradient = LinearGradient(
        colors: [background, backgroundSecondary],
        startPoint: .top,
        endPoint: .bottom
    )

    static let accentGradient = LinearGradient(
        colors: [accentPrimary, accentSecondary],
        startPoint: .leading,
        endPoint: .trailing
    )

    static let glassGradient = LinearGradient(
        colors: [Color.white.opacity(0.1), Color.white.opacity(0.05)],
        startPoint: .topLeading,
        endPoint: .bottomTrailing
    )

    static let purpleGradient = LinearGradient(
        colors: [Color(hex: "8B5CF6"), Color(hex: "6D28D9")],
        startPoint: .leading,
        endPoint: .trailing
    )
}

// MARK: - Color Hex Extension

extension Color {
    init(hex: String) {
        let hex = hex.trimmingCharacters(in: CharacterSet.alphanumerics.inverted)
        var int: UInt64 = 0
        Scanner(string: hex).scanHexInt64(&int)
        let alpha, red, green, blue: UInt64
        switch hex.count {
        case 3: // RGB (12-bit)
            (alpha, red, green, blue) = (255, (int >> 8) * 17, (int >> 4 & 0xF) * 17, (int & 0xF) * 17)
        case 6: // RGB (24-bit)
            (alpha, red, green, blue) = (255, int >> 16, int >> 8 & 0xFF, int & 0xFF)
        case 8: // ARGB (32-bit)
            (alpha, red, green, blue) = (int >> 24, int >> 16 & 0xFF, int >> 8 & 0xFF, int & 0xFF)
        default:
            (alpha, red, green, blue) = (255, 0, 0, 0)
        }
        self.init(
            .sRGB,
            red: Double(red) / 255,
            green: Double(green) / 255,
            blue: Double(blue) / 255,
            opacity: Double(alpha) / 255
        )
    }
}
