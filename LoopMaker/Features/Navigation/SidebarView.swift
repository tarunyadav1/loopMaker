import SwiftUI

// MARK: - Sidebar Section

enum SidebarSection: String, CaseIterable {
    case main = "Main"
    case library = "Library"
    case settings = ""
}

extension SidebarItem {
    var section: SidebarSection {
        switch self {
        case .generate: return .main
        case .library, .favorites: return .library
        case .settings: return .settings
        }
    }
}

// MARK: - Sidebar View

struct NewSidebarView: View {
    @Binding var selection: SidebarItem
    @State private var searchText = ""

    var body: some View {
        VStack(spacing: 0) {
            // Logo section
            logoSection

            Divider()
                .background(Theme.glassBorder)
                .padding(.horizontal, Spacing.md)

            // Search bar
            SearchBar(text: $searchText, placeholder: "Search tracks...")
                .padding(.horizontal, Spacing.md)
                .padding(.vertical, Spacing.md)

            // Navigation sections
            ScrollView {
                VStack(alignment: .leading, spacing: Spacing.lg) {
                    // Main section
                    sectionView(for: .main)

                    // Library section
                    sectionView(for: .library)
                }
                .padding(.horizontal, Spacing.md)
                .padding(.vertical, Spacing.sm)
            }

            Spacer()

            // Settings at bottom
            settingsButton

            Divider()
                .background(Theme.glassBorder)
                .padding(.horizontal, Spacing.md)

            // User/version info
            versionInfo
        }
        .frame(width: Spacing.sidebarWidth)
        .background(Theme.backgroundSecondary)
    }

    // MARK: - Logo Section

    private var logoSection: some View {
        HStack(spacing: Spacing.sm) {
            // App icon
            ZStack {
                RoundedRectangle(cornerRadius: Spacing.radiusSm)
                    .fill(Theme.accentGradient)
                    .frame(width: 32, height: 32)

                Image(systemName: "waveform.circle.fill")
                    .font(.system(size: 18))
                    .foregroundStyle(.white)
            }

            VStack(alignment: .leading, spacing: 0) {
                Text("LoopMaker")
                    .font(Typography.headline)
                    .foregroundStyle(Theme.textPrimary)

                Text("AI Music Generator")
                    .font(Typography.caption2)
                    .foregroundStyle(Theme.textTertiary)
            }

            Spacer()
        }
        .padding(.horizontal, Spacing.md)
        .padding(.vertical, Spacing.md)
    }

    // MARK: - Section View

    private func sectionView(for section: SidebarSection) -> some View {
        VStack(alignment: .leading, spacing: Spacing.xs) {
            if !section.rawValue.isEmpty {
                Text(section.rawValue)
                    .font(Typography.caption)
                    .foregroundStyle(Theme.textTertiary)
                    .padding(.horizontal, Spacing.sm)
                    .padding(.bottom, Spacing.xs)
            }

            ForEach(SidebarItem.allCases.filter { $0.section == section }) { item in
                SidebarNavButton(
                    item: item,
                    isSelected: selection == item,
                    action: { selection = item }
                )
            }
        }
    }

    // MARK: - Settings Button

    private var settingsButton: some View {
        SidebarNavButton(
            item: .settings,
            isSelected: selection == .settings,
            action: { selection = .settings }
        )
        .padding(.horizontal, Spacing.md)
        .padding(.bottom, Spacing.sm)
    }

    // MARK: - Version Info

    private var versionInfo: some View {
        HStack {
            Text("v1.0.0")
                .font(Typography.caption2)
                .foregroundStyle(Theme.textTertiary)

            Spacer()

            Button(action: {}) {
                Image(systemName: "questionmark.circle")
                    .font(.system(size: 14))
                    .foregroundStyle(Theme.textTertiary)
            }
            .buttonStyle(.plain)
        }
        .padding(.horizontal, Spacing.md)
        .padding(.vertical, Spacing.sm)
    }
}

// MARK: - Sidebar Nav Button

struct SidebarNavButton: View {
    let item: SidebarItem
    let isSelected: Bool
    var action: () -> Void

    @State private var isHovered = false

    var body: some View {
        Button(action: action) {
            HStack(spacing: Spacing.sm) {
                Image(systemName: item.icon)
                    .font(.system(size: 16))
                    .foregroundStyle(isSelected ? Theme.accentPrimary : Theme.textSecondary)
                    .frame(width: 24)

                Text(item.rawValue)
                    .font(Typography.body)
                    .foregroundStyle(isSelected ? Theme.textPrimary : Theme.textSecondary)

                Spacer()
            }
            .padding(.horizontal, Spacing.sm)
            .padding(.vertical, Spacing.sm)
            .background(
                RoundedRectangle(cornerRadius: Spacing.radiusSm)
                    .fill(backgroundColor)
            )
        }
        .buttonStyle(.plain)
        .onHover { hovering in
            isHovered = hovering
        }
    }

    private var backgroundColor: Color {
        if isSelected {
            return Theme.accentPrimary.opacity(0.15)
        } else if isHovered {
            return Theme.backgroundTertiary.opacity(0.5)
        }
        return Color.clear
    }
}

// MARK: - Preview

#Preview {
    NewSidebarView(selection: .constant(.generate))
        .frame(height: 600)
}
