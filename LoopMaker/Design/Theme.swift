import SwiftUI
import AppKit

/// LoopMaker Design System
/// Liquid Glass design with unified muted purple accent (glass on macOS 26+, material fallback on 14+)
enum DesignSystem {
    // MARK: - Colors
    enum Colors {
        // Backgrounds - transparent for Liquid Glass vibrancy
        static let background = Color.clear
        static let backgroundSecondary = Color.primary.opacity(0.04)
        static let backgroundTertiary = Color.primary.opacity(0.08)

        // Glass surfaces (appearance-adaptive)
        static let glassLight = Color.primary.opacity(0.08)
        static let glassMedium = Color.primary.opacity(0.06)
        static let glassDark = Color.primary.opacity(0.04)
        static let glassUltraLight = Color.primary.opacity(0.03)

        // Surfaces - for cards and containers (appearance-adaptive)
        static let surface = Color.primary.opacity(0.05)
        static let surfaceHover = Color.primary.opacity(0.08)
        static let surfaceActive = Color.primary.opacity(0.12)
        static let surfaceGlass = Color.clear

        // Text - system colors for automatic light/dark adaptation
        static let textPrimary = Color.primary
        static let textSecondary = Color.secondary
        static let textTertiary = Color.secondary.opacity(0.7)
        static let textMuted = Color.secondary.opacity(0.5)

        // Accent - Muted Purple (unified brand color)
        static let accent = Color(hex: "7B7FFF")
        static let accentHover = Color(hex: "6B6FEF")
        static let accentSubtle = Color(hex: "7B7FFF").opacity(0.1)
        static let accentMuted = Color(hex: "7B7FFF").opacity(0.06)
        static let accentGlass = Color(hex: "7B7FFF").opacity(0.15)

        // Secondary accent - maps to primary accent (unified)
        static let accentSecondary = Color(hex: "7B7FFF")
        static let accentSecondaryHover = Color(hex: "6B6FEF")

        // Music/Audio accent colors (unified)
        static let audioPrimary = Color(hex: "7B7FFF")
        static let audioSecondary = Color(hex: "7B7FFF")
        static let audioGlow = Color(hex: "7B7FFF").opacity(0.4)

        // Semantic colors
        static let success = Color(hex: "22C55E")
        static let successGlow = Color(hex: "22C55E").opacity(0.4)
        static let successGlass = Color(hex: "22C55E").opacity(0.12)

        static let warning = Color(hex: "EAB308")
        static let warningGlow = Color(hex: "EAB308").opacity(0.4)
        static let warningGlass = Color(hex: "EAB308").opacity(0.12)

        static let error = Color(hex: "EF4444")
        static let errorGlow = Color(hex: "EF4444").opacity(0.4)
        static let errorGlass = Color(hex: "EF4444").opacity(0.12)

        static let info = Color(hex: "7B7FFF")

        // Generation state colors (unified accent)
        static let generatingActive = Color(hex: "7B7FFF")
        static let generatingPulse = Color(hex: "7B7FFF").opacity(0.2)
        static let generatingGlass = Color(hex: "7B7FFF").opacity(0.1)
        static let generatingGlow = Color(hex: "7B7FFF").opacity(0.5)
        static let processingActive = Color(hex: "7B7FFF")
        static let processingGlow = Color(hex: "7B7FFF").opacity(0.4)

        // Borders - subtle glass edges (appearance-adaptive)
        static let border = Color.primary.opacity(0.08)
        static let borderHover = Color.primary.opacity(0.12)
        static let borderFocus = Color(hex: "7B7FFF").opacity(0.4)
        static let borderGlass = Color.primary.opacity(0.15)

        // Gradients - unified accent palette
        static let accentGradient = LinearGradient(
            colors: [Color(hex: "7B7FFF"), Color(hex: "6B6FEF")],
            startPoint: .leading,
            endPoint: .trailing
        )

        static let softAccent = LinearGradient(
            colors: [Color(hex: "7B7FFF").opacity(0.1), Color(hex: "6B6FEF").opacity(0.08)],
            startPoint: .topLeading,
            endPoint: .bottomTrailing
        )

        static let purpleGradient = LinearGradient(
            colors: [Color(hex: "7B7FFF"), Color(hex: "6B6FEF")],
            startPoint: .leading,
            endPoint: .trailing
        )

        static let spectralGradient = LinearGradient(
            colors: [
                Color(hex: "7B7FFF").opacity(0.5),
                Color(hex: "6B6FEF").opacity(0.3),
                Color(hex: "5B5FDF").opacity(0.2)
            ],
            startPoint: .topLeading,
            endPoint: .bottomTrailing
        )

        static let glassGradient = LinearGradient(
            colors: [
                Color.primary.opacity(0.08),
                Color.primary.opacity(0.04)
            ],
            startPoint: .top,
            endPoint: .bottom
        )

        static let generatingGradient = LinearGradient(
            colors: [Color(hex: "7B7FFF"), Color(hex: "9B9FFF")],
            startPoint: .bottom,
            endPoint: .top
        )
    }

    // MARK: - Spacing
    enum Spacing {
        static let xxs: CGFloat = 2
        static let xs: CGFloat = 4
        static let sm: CGFloat = 8
        static let md: CGFloat = 12
        static let lg: CGFloat = 16
        static let xl: CGFloat = 24
        static let xxl: CGFloat = 32
        static let xxxl: CGFloat = 48
    }

    // MARK: - Corner Radius (larger for Liquid Glass)
    enum CornerRadius {
        static let small: CGFloat = 8
        static let medium: CGFloat = 12
        static let large: CGFloat = 16
        static let extraLarge: CGFloat = 20
        static let pill: CGFloat = 999
    }

    // MARK: - Shadows (softer for glass effect)
    enum Shadows {
        static let subtle = Color.black.opacity(0.05)
        static let medium = Color.black.opacity(0.1)
        static let strong = Color.black.opacity(0.15)
        static let glow = Colors.accent.opacity(0.2)
        static let glass = Color.black.opacity(0.04)
    }

    // MARK: - Animations
    enum Animations {
        static let quick = Animation.spring(duration: 0.2, bounce: 0.2)
        static let standard = Animation.easeInOut(duration: 0.25)
        static let smooth = Animation.easeInOut(duration: 0.3)
        static let slow = Animation.easeInOut(duration: 0.4)

        static let buttonPress = Animation.spring(duration: 0.15, bounce: 0.3)
        static let buttonRelease = Animation.spring(duration: 0.3, bounce: 0.4)

        static let panelSlide = Animation.spring(duration: 0.4, bounce: 0.2)
        static let panelFade = Animation.easeOut(duration: 0.25)

        static let spring = Animation.spring(response: 0.35, dampingFraction: 0.7)
        static let springBouncy = Animation.spring(response: 0.4, dampingFraction: 0.6)
        static let glass = Animation.spring(response: 0.3, dampingFraction: 0.8)

        static let breathing = Animation.easeInOut(duration: 2.0).repeatForever(autoreverses: true)
        static let pulse = Animation.easeInOut(duration: 1.5).repeatForever(autoreverses: true)
        static let gentlePulse = Animation.easeInOut(duration: 0.7).repeatForever(autoreverses: true)

        static let toastIn = Animation.spring(duration: 0.5, bounce: 0.3)
        static let toastOut = Animation.easeIn(duration: 0.25)
    }

    // MARK: - Typography
    enum Typography {
        static let displayLarge = Font.system(size: 32, weight: .semibold, design: .rounded)
        static let displayMedium = Font.system(size: 26, weight: .semibold, design: .rounded)

        static let hero = Font.system(size: 48, weight: .bold, design: .rounded)

        static let title = Font.system(size: 20, weight: .semibold, design: .rounded)
        static let title2 = Font.system(size: 17, weight: .semibold, design: .rounded)
        static let title3 = Font.system(size: 15, weight: .semibold, design: .rounded)

        static let headline = Font.system(size: 14, weight: .semibold, design: .rounded)
        static let headlineMedium = Font.system(size: 14, weight: .medium, design: .rounded)

        static let sectionHeader = Font.system(size: 11, weight: .semibold, design: .rounded)

        static let body = Font.system(size: 14, weight: .regular)
        static let bodyMedium = Font.system(size: 14, weight: .medium)
        static let bodySemibold = Font.system(size: 14, weight: .semibold)

        static let callout = Font.system(size: 13, weight: .regular)
        static let calloutMedium = Font.system(size: 13, weight: .medium)

        static let caption = Font.system(size: 12, weight: .regular)
        static let captionMedium = Font.system(size: 12, weight: .medium)
        static let captionSemibold = Font.system(size: 12, weight: .semibold)

        static let caption2 = Font.system(size: 11, weight: .regular)

        static let micro = Font.system(size: 10, weight: .medium)

        static let mono = Font.system(size: 13, weight: .medium, design: .monospaced)
        static let monoLarge = Font.system(size: 16, weight: .semibold, design: .monospaced)
        static let monoSmall = Font.system(size: 11, weight: .medium, design: .monospaced)
    }

    // MARK: - Line Spacing
    enum LineSpacing {
        static let tight: CGFloat = 2
        static let normal: CGFloat = 4
        static let relaxed: CGFloat = 6
        static let loose: CGFloat = 8
    }

    // MARK: - Glass Materials
    enum Materials {
        static let ultraThin = Material.ultraThinMaterial
        static let thin = Material.thinMaterial
        static let regular = Material.regularMaterial
        static let thick = Material.thickMaterial
        static let ultraThick = Material.ultraThickMaterial
    }

    // MARK: - Component Dimensions
    enum Dimensions {
        static let sidebarWidth: CGFloat = 260
        static let playerBarHeight: CGFloat = 80
        static let genreCardWidth: CGFloat = 180
        static let genreCardHeight: CGFloat = 100
        static let trackRowHeight: CGFloat = 64
        static let buttonHeight: CGFloat = 44
        static let iconButtonSize: CGFloat = 36
        static let searchBarHeight: CGFloat = 40
    }
}

// MARK: - Color Hex Extension

extension Color {
    init(hex: String) {
        let hex = hex.trimmingCharacters(in: CharacterSet.alphanumerics.inverted)
        var int: UInt64 = 0
        Scanner(string: hex).scanHexInt64(&int)
        let a, r, g, b: UInt64
        switch hex.count {
        case 3:
            (a, r, g, b) = (255, (int >> 8) * 17, (int >> 4 & 0xF) * 17, (int & 0xF) * 17)
        case 6:
            (a, r, g, b) = (255, int >> 16, int >> 8 & 0xFF, int & 0xFF)
        case 8:
            (a, r, g, b) = (int >> 24, int >> 16 & 0xFF, int >> 8 & 0xFF, int & 0xFF)
        default:
            (a, r, g, b) = (255, 0, 0, 0)
        }
        self.init(
            .sRGB,
            red: Double(r) / 255,
            green: Double(g) / 255,
            blue: Double(b) / 255,
            opacity: Double(a) / 255
        )
    }
}

// MARK: - Visual Effects for Liquid Glass

class PassthroughVisualEffectView: NSVisualEffectView {
    override func hitTest(_ point: NSPoint) -> NSView? {
        return nil
    }
}

struct GlassBackgroundView: NSViewRepresentable {
    var material: NSVisualEffectView.Material
    var blendingMode: NSVisualEffectView.BlendingMode

    init(
        material: NSVisualEffectView.Material = .hudWindow,
        blendingMode: NSVisualEffectView.BlendingMode = .behindWindow
    ) {
        self.material = material
        self.blendingMode = blendingMode
    }

    func makeNSView(context: Context) -> NSVisualEffectView {
        let view = PassthroughVisualEffectView()
        view.material = material
        view.blendingMode = blendingMode
        view.state = .active
        return view
    }

    func updateNSView(_ nsView: NSVisualEffectView, context: Context) {
        nsView.material = material
        nsView.blendingMode = blendingMode
    }
}

struct VisualEffectView: NSViewRepresentable {
    var material: NSVisualEffectView.Material
    var blendingMode: NSVisualEffectView.BlendingMode

    func makeNSView(context: Context) -> NSVisualEffectView {
        let view = NSVisualEffectView()
        view.material = material
        view.blendingMode = blendingMode
        view.state = .active
        return view
    }

    func updateNSView(_ nsView: NSVisualEffectView, context: Context) {
        nsView.material = material
        nsView.blendingMode = blendingMode
    }
}

// MARK: - Native Liquid Glass Button Styles (macOS 26+)

struct LiquidGlassButtonStyle: ButtonStyle {
    var style: ButtonVariant = .primary

    enum ButtonVariant {
        case primary, secondary, ghost, danger
    }

    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .font(DesignSystem.Typography.bodyMedium)
            .padding(.horizontal, 16)
            .padding(.vertical, 10)
            .foregroundColor(foregroundColor)
            .modifier(GlassButtonBackground(style: style, isPressed: configuration.isPressed))
            .scaleEffect(configuration.isPressed ? 0.97 : 1.0)
            .animation(DesignSystem.Animations.glass, value: configuration.isPressed)
    }

    private var foregroundColor: Color {
        switch style {
        case .primary:
            return .white
        case .secondary, .ghost:
            return DesignSystem.Colors.textPrimary
        case .danger:
            return .white
        }
    }
}

struct GlassButtonBackground: ViewModifier {
    let style: LiquidGlassButtonStyle.ButtonVariant
    let isPressed: Bool

    func body(content: Content) -> some View {
        switch style {
        case .primary:
            content
                .background(isPressed ? DesignSystem.Colors.accentHover : DesignSystem.Colors.accent)
                .clipShape(RoundedRectangle(cornerRadius: DesignSystem.CornerRadius.medium))
        case .secondary:
            content
                .compatGlassEffect(
                    cornerRadius: DesignSystem.CornerRadius.medium,
                    tint: DesignSystem.Colors.accent,
                    interactive: true
                )
        case .ghost:
            content
                .background(isPressed ? DesignSystem.Colors.surfaceActive : Color.clear)
                .clipShape(RoundedRectangle(cornerRadius: DesignSystem.CornerRadius.medium))
        case .danger:
            content
                .compatGlassEffect(
                    cornerRadius: DesignSystem.CornerRadius.medium,
                    tint: DesignSystem.Colors.error,
                    interactive: true
                )
        }
    }
}

struct WisprButtonStyle: ButtonStyle {
    var style: ButtonVariant = .secondary

    enum ButtonVariant {
        case primary, secondary, ghost, danger
    }

    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .font(DesignSystem.Typography.bodyMedium)
            .padding(.horizontal, 14)
            .padding(.vertical, 8)
            .background(backgroundColor(isPressed: configuration.isPressed))
            .foregroundColor(foregroundColor)
            .cornerRadius(DesignSystem.CornerRadius.medium)
            .scaleEffect(configuration.isPressed ? 0.98 : 1.0)
            .animation(DesignSystem.Animations.quick, value: configuration.isPressed)
    }

    private func backgroundColor(isPressed: Bool) -> Color {
        switch style {
        case .primary:
            return isPressed ? DesignSystem.Colors.accentHover : DesignSystem.Colors.accent
        case .secondary:
            return isPressed ? DesignSystem.Colors.surfaceActive : DesignSystem.Colors.surfaceHover
        case .ghost:
            return isPressed ? DesignSystem.Colors.surfaceActive : Color.clear
        case .danger:
            return isPressed ? DesignSystem.Colors.error.opacity(0.8) : DesignSystem.Colors.error
        }
    }

    private var foregroundColor: Color {
        switch style {
        case .primary, .danger:
            return .white
        case .secondary, .ghost:
            return DesignSystem.Colors.textPrimary
        }
    }
}

struct WisprIconButtonStyle: ButtonStyle {
    var size: CGFloat = 32
    var isActive: Bool = false

    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .font(.system(size: size * 0.38, weight: .medium))
            .frame(width: size, height: size)
            .foregroundColor(isActive ? .white : DesignSystem.Colors.textSecondary)
            .modifier(IconButtonBackground(isActive: isActive, isPressed: configuration.isPressed))
            .scaleEffect(configuration.isPressed ? 0.94 : 1.0)
            .animation(DesignSystem.Animations.quick, value: configuration.isPressed)
    }
}

struct IconButtonBackground: ViewModifier {
    let isActive: Bool
    let isPressed: Bool

    func body(content: Content) -> some View {
        if isActive {
            content
                .compatGlassCircle(tint: DesignSystem.Colors.accent, interactive: true)
        } else {
            content
                .compatGlassCircle(tint: DesignSystem.Colors.accent, interactive: true)
        }
    }
}

struct GlassButtonStyle: ButtonStyle {
    var cornerRadius: CGFloat = 12

    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .font(DesignSystem.Typography.bodyMedium)
            .padding(.horizontal, 16)
            .padding(.vertical, 10)
            .foregroundColor(DesignSystem.Colors.textPrimary)
            .background(
                RoundedRectangle(cornerRadius: cornerRadius)
                    .fill(Color.primary.opacity(configuration.isPressed ? 0.15 : 0.08))
            )
            .contentShape(RoundedRectangle(cornerRadius: cornerRadius))
            .scaleEffect(configuration.isPressed ? 0.97 : 1.0)
            .animation(DesignSystem.Animations.glass, value: configuration.isPressed)
    }
}

struct PrimaryGradientButtonStyle: ButtonStyle {
    var cornerRadius: CGFloat = 12

    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .font(DesignSystem.Typography.bodyMedium)
            .padding(.horizontal, 18)
            .padding(.vertical, 11)
            .background(
                RoundedRectangle(cornerRadius: cornerRadius)
                    .fill(DesignSystem.Colors.accentGradient)
            )
            .foregroundColor(.white)
            .scaleEffect(configuration.isPressed ? 0.98 : 1.0)
            .animation(DesignSystem.Animations.glass, value: configuration.isPressed)
    }
}

struct LoopMakerButtonStyle: ButtonStyle {
    let variant: Variant

    enum Variant {
        case primary
        case secondary
        case ghost
    }

    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .padding(.horizontal, 16)
            .padding(.vertical, 10)
            .background {
                switch variant {
                case .primary:
                    RoundedRectangle(cornerRadius: DesignSystem.CornerRadius.medium)
                        .fill(DesignSystem.Colors.accentGradient)
                case .secondary:
                    RoundedRectangle(cornerRadius: DesignSystem.CornerRadius.medium)
                        .fill(.regularMaterial)
                case .ghost:
                    Color.clear
                }
            }
            .foregroundStyle(variant == .primary ? .white : .primary)
            .scaleEffect(configuration.isPressed ? 0.96 : 1.0)
            .animation(DesignSystem.Animations.buttonPress, value: configuration.isPressed)
    }
}

extension ButtonStyle where Self == LoopMakerButtonStyle {
    static var loopPrimary: LoopMakerButtonStyle { LoopMakerButtonStyle(variant: .primary) }
    static var loopSecondary: LoopMakerButtonStyle { LoopMakerButtonStyle(variant: .secondary) }
    static var loopGhost: LoopMakerButtonStyle { LoopMakerButtonStyle(variant: .ghost) }
}

// MARK: - Sidebar Item Style

struct SidebarItemModifier: ViewModifier {
    var isSelected: Bool
    @State private var isHovered: Bool = false

    func body(content: Content) -> some View {
        content
            .padding(.horizontal, 12)
            .padding(.vertical, 10)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(
                RoundedRectangle(cornerRadius: DesignSystem.CornerRadius.medium)
                    .fill(backgroundColor)
            )
            .foregroundColor(isSelected ? DesignSystem.Colors.textPrimary : DesignSystem.Colors.textSecondary)
            .contentShape(RoundedRectangle(cornerRadius: DesignSystem.CornerRadius.medium))
            .onHover { hovering in
                withAnimation(DesignSystem.Animations.quick) {
                    isHovered = hovering
                }
            }
    }

    private var backgroundColor: Color {
        if isSelected {
            return DesignSystem.Colors.accentSubtle
        } else if isHovered {
            return DesignSystem.Colors.surfaceHover
        }
        return Color.clear
    }
}

// MARK: - Glass Compatibility Helpers (macOS 26+ glass, 14+ material fallback)

extension View {
    @ViewBuilder
    func compatGlassEffect(
        cornerRadius: CGFloat = DesignSystem.CornerRadius.large,
        tint: Color? = nil,
        interactive: Bool = false,
        clear: Bool = false
    ) -> some View {
        if #available(macOS 26, *) {
            if clear {
                self.glassEffect(.clear, in: RoundedRectangle(cornerRadius: cornerRadius))
            } else if let tint {
                if interactive {
                    self.glassEffect(.regular.tint(tint).interactive(), in: RoundedRectangle(cornerRadius: cornerRadius))
                } else {
                    self.glassEffect(.regular.tint(tint), in: RoundedRectangle(cornerRadius: cornerRadius))
                }
            } else {
                self.glassEffect(.regular, in: RoundedRectangle(cornerRadius: cornerRadius))
            }
        } else {
            self.background(.ultraThinMaterial, in: RoundedRectangle(cornerRadius: cornerRadius))
        }
    }

    @ViewBuilder
    func compatGlassCircle(tint: Color? = nil, interactive: Bool = false) -> some View {
        if #available(macOS 26, *) {
            if let tint {
                if interactive {
                    self.glassEffect(.regular.tint(tint).interactive(), in: .circle)
                } else {
                    self.glassEffect(.regular.tint(tint), in: .circle)
                }
            } else {
                self.glassEffect(.regular, in: .circle)
            }
        } else {
            self.background(.ultraThinMaterial, in: Circle())
        }
    }

    @ViewBuilder
    func compatGlassCapsule(tint: Color? = nil, interactive: Bool = false, clear: Bool = false) -> some View {
        if #available(macOS 26, *) {
            if clear {
                self.glassEffect(.clear, in: .capsule)
            } else if let tint {
                if interactive {
                    self.glassEffect(.regular.tint(tint).interactive(), in: .capsule)
                } else {
                    self.glassEffect(.regular.tint(tint), in: .capsule)
                }
            } else {
                self.glassEffect(.regular, in: .capsule)
            }
        } else {
            self.background(.ultraThinMaterial, in: Capsule())
        }
    }

    @ViewBuilder
    func compatGlassRect(
        cornerRadius: CGFloat = DesignSystem.CornerRadius.medium,
        tint: Color? = nil,
        interactive: Bool = false
    ) -> some View {
        if #available(macOS 26, *) {
            if let tint {
                if interactive {
                    self.glassEffect(.regular.tint(tint).interactive(), in: .rect(cornerRadius: cornerRadius))
                } else {
                    self.glassEffect(.regular.tint(tint), in: .rect(cornerRadius: cornerRadius))
                }
            } else {
                self.glassEffect(.regular, in: .rect(cornerRadius: cornerRadius))
            }
        } else {
            self.background(.ultraThinMaterial, in: RoundedRectangle(cornerRadius: cornerRadius))
        }
    }

    @ViewBuilder
    func compatGlassEffectPlain() -> some View {
        if #available(macOS 26, *) {
            self.glassEffect()
        } else {
            self.background(.ultraThinMaterial)
        }
    }

    @ViewBuilder
    func compatGlassEffectID(_ id: String, in namespace: Namespace.ID) -> some View {
        if #available(macOS 26, *) {
            self.glassEffectID(id, in: namespace)
        } else {
            self
        }
    }
}

// MARK: - Native Liquid Glass View Extensions

extension View {
    func liquidGlassCard(cornerRadius: CGFloat = DesignSystem.CornerRadius.large) -> some View {
        self
            .padding(DesignSystem.Spacing.lg)
            .compatGlassEffect(cornerRadius: cornerRadius)
    }

    func liquidGlassCardInteractive(cornerRadius: CGFloat = DesignSystem.CornerRadius.large) -> some View {
        self
            .padding(DesignSystem.Spacing.lg)
            .compatGlassEffect(cornerRadius: cornerRadius, tint: DesignSystem.Colors.accent, interactive: true)
    }

    func liquidGlassTinted(_ color: Color, cornerRadius: CGFloat = DesignSystem.CornerRadius.large) -> some View {
        self
            .padding(DesignSystem.Spacing.lg)
            .compatGlassEffect(cornerRadius: cornerRadius, tint: color)
    }

    func liquidGlassClear(cornerRadius: CGFloat = DesignSystem.CornerRadius.large) -> some View {
        self
            .compatGlassEffect(cornerRadius: cornerRadius, clear: true)
    }

    func liquidGlassPill() -> some View {
        self
            .compatGlassCapsule()
    }

    func liquidGlassPillInteractive() -> some View {
        self
            .compatGlassCapsule(tint: DesignSystem.Colors.accent, interactive: true)
    }

    func liquidGlassCircle() -> some View {
        self
            .compatGlassCircle()
    }

    func liquidGlassCircleInteractive() -> some View {
        self
            .compatGlassCircle(tint: DesignSystem.Colors.accent, interactive: true)
    }

    func glassCard(cornerRadius: CGFloat = DesignSystem.CornerRadius.large) -> some View {
        self
            .compatGlassEffect(cornerRadius: cornerRadius)
    }

    func solidCard(cornerRadius: CGFloat = DesignSystem.CornerRadius.large) -> some View {
        self
            .compatGlassEffect(cornerRadius: cornerRadius)
            .shadow(color: DesignSystem.Shadows.subtle, radius: 8, y: 2)
    }

    func sidebarItemStyle(isSelected: Bool) -> some View {
        self.modifier(SidebarItemModifier(isSelected: isSelected))
    }

    func glassBorder(cornerRadius: CGFloat = DesignSystem.CornerRadius.large) -> some View {
        self.overlay(
            RoundedRectangle(cornerRadius: cornerRadius)
                .stroke(
                    LinearGradient(
                        colors: [
                            Color.primary.opacity(0.15),
                            Color.primary.opacity(0.08),
                            Color.primary.opacity(0.04)
                        ],
                        startPoint: .topLeading,
                        endPoint: .bottomTrailing
                    ),
                    lineWidth: 1
                )
        )
    }

    func descriptionStyle() -> some View {
        self
            .font(.system(size: 13))
            .foregroundColor(DesignSystem.Colors.textSecondary)
            .lineSpacing(DesignSystem.LineSpacing.normal)
            .fixedSize(horizontal: false, vertical: true)
    }

    func secondaryDescriptionStyle() -> some View {
        self
            .font(.system(size: 12))
            .foregroundColor(DesignSystem.Colors.textTertiary)
            .lineSpacing(DesignSystem.LineSpacing.tight)
    }

    func sectionHeaderStyle() -> some View {
        self
            .font(DesignSystem.Typography.sectionHeader)
            .foregroundColor(DesignSystem.Colors.textTertiary)
            .tracking(0.5)
            .textCase(.uppercase)
    }

    func floatingWindowStyle() -> some View {
        self
            .compatGlassEffect(cornerRadius: DesignSystem.CornerRadius.extraLarge)
            .shadow(color: DesignSystem.Shadows.medium, radius: 24, y: 8)
    }

    func standardPadding() -> some View {
        self.padding(DesignSystem.Spacing.lg)
    }

    func subtleGradientBackground() -> some View {
        self.background(.regularMaterial)
    }
}

// MARK: - Hover Card Modifier

struct HoverCardModifier: ViewModifier {
    @State private var isHovered = false
    var cornerRadius: CGFloat = DesignSystem.CornerRadius.large

    func body(content: Content) -> some View {
        content
            .compatGlassEffect(cornerRadius: cornerRadius)
            .overlay(
                RoundedRectangle(cornerRadius: cornerRadius)
                    .stroke(isHovered ? DesignSystem.Colors.accent.opacity(0.2) : Color.clear, lineWidth: 1)
            )
            .shadow(
                color: isHovered ? DesignSystem.Shadows.medium : DesignSystem.Shadows.subtle,
                radius: isHovered ? 16 : 10,
                y: isHovered ? 6 : 4
            )
            .scaleEffect(isHovered ? 1.005 : 1.0)
            .animation(DesignSystem.Animations.quick, value: isHovered)
            .onHover { hovering in
                isHovered = hovering
            }
    }
}

struct HoverRowModifier: ViewModifier {
    @State private var isHovered = false
    var cornerRadius: CGFloat = DesignSystem.CornerRadius.medium

    func body(content: Content) -> some View {
        content
            .background(
                RoundedRectangle(cornerRadius: cornerRadius)
                    .fill(isHovered ? Color.primary.opacity(0.05) : Color.clear)
            )
            .animation(DesignSystem.Animations.quick, value: isHovered)
            .onHover { hovering in
                isHovered = hovering
            }
    }
}

struct InteractiveModifier: ViewModifier {
    @State private var isHovered = false

    func body(content: Content) -> some View {
        content
            .brightness(isHovered ? 0.03 : 0)
            .scaleEffect(isHovered ? 1.005 : 1.0)
            .animation(DesignSystem.Animations.quick, value: isHovered)
            .onHover { hovering in
                isHovered = hovering
            }
    }
}

extension View {
    func hoverCard(cornerRadius: CGFloat = DesignSystem.CornerRadius.large) -> some View {
        self.modifier(HoverCardModifier(cornerRadius: cornerRadius))
    }

    func hoverRow(cornerRadius: CGFloat = DesignSystem.CornerRadius.medium) -> some View {
        self.modifier(HoverRowModifier(cornerRadius: cornerRadius))
    }

    func interactive() -> some View {
        self.modifier(InteractiveModifier())
    }

    func innerShadow(cornerRadius: CGFloat = DesignSystem.CornerRadius.large) -> some View {
        self.overlay(
            RoundedRectangle(cornerRadius: cornerRadius)
                .stroke(Color.black.opacity(0.06), lineWidth: 1)
                .blur(radius: 1)
                .offset(y: 1)
                .mask(RoundedRectangle(cornerRadius: cornerRadius))
        )
    }

    func pressable(isPressed: Bool) -> some View {
        self.scaleEffect(isPressed ? 0.96 : 1.0)
            .animation(
                isPressed ? DesignSystem.Animations.buttonPress : DesignSystem.Animations.buttonRelease,
                value: isPressed
            )
    }

    func softGlow(_ color: Color, radius: CGFloat = 8, isActive: Bool = true) -> some View {
        self.shadow(color: isActive ? color.opacity(0.4) : .clear, radius: radius, y: 0)
    }

    func breathing(isActive: Bool = true) -> some View {
        self.modifier(BreathingModifier(isActive: isActive))
    }

    func shimmer(isActive: Bool = true) -> some View {
        self.modifier(ShimmerModifier(isActive: isActive))
    }
}

// MARK: - Breathing Modifier

struct BreathingModifier: ViewModifier {
    let isActive: Bool
    @State private var scale: CGFloat = 1.0

    func body(content: Content) -> some View {
        content
            .scaleEffect(scale)
            .onAppear {
                if isActive {
                    withAnimation(DesignSystem.Animations.breathing) {
                        scale = 1.02
                    }
                }
            }
            .onChange(of: isActive) { _, active in
                if active {
                    withAnimation(DesignSystem.Animations.breathing) {
                        scale = 1.02
                    }
                } else {
                    withAnimation(DesignSystem.Animations.quick) {
                        scale = 1.0
                    }
                }
            }
    }
}

// MARK: - Shimmer Modifier

struct ShimmerModifier: ViewModifier {
    let isActive: Bool
    @State private var phase: CGFloat = 0

    func body(content: Content) -> some View {
        content
            .overlay {
                if isActive {
                    GeometryReader { geometry in
                        LinearGradient(
                            colors: [.clear, .white.opacity(0.2), .clear],
                            startPoint: .leading,
                            endPoint: .trailing
                        )
                        .frame(width: geometry.size.width * 0.5)
                        .offset(x: phase * geometry.size.width * 1.5 - geometry.size.width * 0.25)
                        .blendMode(.overlay)
                    }
                    .mask(content)
                    .onAppear {
                        withAnimation(.linear(duration: 1.5).repeatForever(autoreverses: false)) {
                            phase = 1
                        }
                    }
                }
            }
    }
}

// MARK: - Keyboard Shortcut Hint

struct KeyboardHint: View {
    let keys: String

    var body: some View {
        Text(keys)
            .font(.caption2)
            .fontWeight(.medium)
            .fontDesign(.monospaced)
            .foregroundStyle(.tertiary)
            .padding(.horizontal, 6)
            .padding(.vertical, 3)
            .background(.quaternary, in: RoundedRectangle(cornerRadius: 4))
    }
}

// MARK: - Glass Effect Container (macOS 26+ glass, material fallback)

struct LoopMakerGlassEffectContainer<Content: View>: View {
    let spacing: CGFloat
    let content: Content

    init(spacing: CGFloat = 8, @ViewBuilder content: () -> Content) {
        self.spacing = spacing
        self.content = content()
    }

    var body: some View {
        VStack(spacing: spacing) {
            content
        }
        .compatGlassEffectPlain()
    }
}

struct LoopMakerGlassContainer<Content: View>: View {
    let spacing: CGFloat
    let content: () -> Content

    init(spacing: CGFloat = 8, @ViewBuilder content: @escaping () -> Content) {
        self.spacing = spacing
        self.content = content
    }

    var body: some View {
        if #available(macOS 26, *) {
            SwiftUI.GlassEffectContainer(spacing: spacing) {
                content()
            }
        } else {
            VStack(spacing: spacing) {
                content()
            }
        }
    }
}

// MARK: - Legacy Typography Aliases (for gradual migration)

typealias Typography = DesignSystem.Typography
typealias Spacing = DesignSystem.Spacing

// Legacy Theme typealias for backward compatibility during migration
enum Theme {
    static let background = DesignSystem.Colors.background
    static let backgroundSecondary = DesignSystem.Colors.backgroundSecondary
    static let backgroundTertiary = DesignSystem.Colors.backgroundTertiary
    static let textPrimary = DesignSystem.Colors.textPrimary
    static let textSecondary = DesignSystem.Colors.textSecondary
    static let textTertiary = DesignSystem.Colors.textMuted
    static let accentPrimary = DesignSystem.Colors.accent
    static let accentSecondary = DesignSystem.Colors.accentSecondary
    static let success = DesignSystem.Colors.success
    static let warning = DesignSystem.Colors.warning
    static let error = DesignSystem.Colors.error
    static let glassBorder = DesignSystem.Colors.border
    static let glassHighlight = DesignSystem.Colors.glassLight
    static let glassShadow = DesignSystem.Shadows.medium
    static let accentGradient = DesignSystem.Colors.accentGradient
    static let glassGradient = DesignSystem.Colors.glassGradient
    static let purpleGradient = DesignSystem.Colors.purpleGradient
    static let backgroundGradient = DesignSystem.Colors.glassGradient
}

// MARK: - Legacy Spacing Aliases

extension DesignSystem.Spacing {
    static let sidebarWidth = DesignSystem.Dimensions.sidebarWidth
    static let playerBarHeight = DesignSystem.Dimensions.playerBarHeight
    static let genreCardWidth = DesignSystem.Dimensions.genreCardWidth
    static let genreCardHeight = DesignSystem.Dimensions.genreCardHeight
    static let trackRowHeight = DesignSystem.Dimensions.trackRowHeight
    static let buttonHeight = DesignSystem.Dimensions.buttonHeight
    static let iconButtonSize = DesignSystem.Dimensions.iconButtonSize
    static let searchBarHeight = DesignSystem.Dimensions.searchBarHeight

    static let radiusXs: CGFloat = DesignSystem.CornerRadius.small
    static let radiusSm: CGFloat = DesignSystem.CornerRadius.small
    static let radiusMd: CGFloat = DesignSystem.CornerRadius.medium
    static let radiusLg: CGFloat = DesignSystem.CornerRadius.large
    static let radiusXl: CGFloat = DesignSystem.CornerRadius.extraLarge
    static let radiusFull: CGFloat = DesignSystem.CornerRadius.pill
}

// MARK: - Legacy View Modifiers

extension View {
    func heroText() -> some View {
        self
            .font(DesignSystem.Typography.hero)
            .foregroundStyle(DesignSystem.Colors.textPrimary)
    }

    func title1Text() -> some View {
        self
            .font(DesignSystem.Typography.displayLarge)
            .foregroundStyle(DesignSystem.Colors.textPrimary)
    }

    func title2Text() -> some View {
        self
            .font(DesignSystem.Typography.displayMedium)
            .foregroundStyle(DesignSystem.Colors.textPrimary)
    }

    func title3Text() -> some View {
        self
            .font(DesignSystem.Typography.title)
            .foregroundStyle(DesignSystem.Colors.textPrimary)
    }

    func headlineText() -> some View {
        self
            .font(DesignSystem.Typography.headline)
            .foregroundStyle(DesignSystem.Colors.textPrimary)
    }

    func bodyText() -> some View {
        self
            .font(DesignSystem.Typography.body)
            .foregroundStyle(DesignSystem.Colors.textSecondary)
    }

    func captionText() -> some View {
        self
            .font(DesignSystem.Typography.caption)
            .foregroundStyle(DesignSystem.Colors.textTertiary)
    }

    func paddingSmall() -> some View {
        self.padding(DesignSystem.Spacing.sm)
    }

    func paddingMedium() -> some View {
        self.padding(DesignSystem.Spacing.md)
    }

    func paddingLarge() -> some View {
        self.padding(DesignSystem.Spacing.lg)
    }
}
