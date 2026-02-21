import SwiftUI

/// Settings view with horizontal tab bar navigation (Echo-text style)
struct SettingsView: View {
    @EnvironmentObject var appState: AppState
    @StateObject private var updateService = UpdateService.shared
    @State private var selectedTab: SettingsTab = .general
    @State private var showCleanInstallConfirmation = false
    @State private var showClearTracksConfirmation = false
    @State private var isRestartingBackend = false
    @State private var isCleanInstalling = false
    @State private var automaticChecks = true
    @State private var automaticDownloads = false

    enum SettingsTab: String, CaseIterable {
        case general = "General"
        case updates = "Updates"
        case license = "License"

        var icon: String {
            switch self {
            case .general: return "gearshape"
            case .updates: return "arrow.triangle.2.circlepath"
            case .license: return "star.circle"
            }
        }
    }

    var body: some View {
        VStack(spacing: 0) {
            // Top tab bar
            tabBar
                .padding(.horizontal, 24)
                .padding(.top, 12)
                .padding(.bottom, 12)

            // Content area
            ScrollView(showsIndicators: false) {
                selectedTabContent
                    .padding(32)
                    .frame(maxWidth: 700, alignment: .leading)
            }
            .frame(maxWidth: .infinity)
        }
        .background(Color(nsColor: .windowBackgroundColor))
        .animation(.easeInOut(duration: 0.2), value: selectedTab)
    }

    // MARK: - Tab Bar

    private var tabBar: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: 2) {
                ForEach(SettingsTab.allCases, id: \.self) { tab in
                    tabButton(tab)
                }
            }
            .padding(4)
            .compatGlassCapsule()
        }
    }

    private func tabButton(_ tab: SettingsTab) -> some View {
        Button {
            withAnimation(.spring(duration: 0.25, bounce: 0.15)) {
                selectedTab = tab
            }
        } label: {
            HStack(spacing: 6) {
                Image(systemName: tab.icon)
                    .font(.system(size: 11))
                Text(tab.rawValue)
                    .font(.system(size: 12, weight: selectedTab == tab ? .semibold : .medium))
            }
            .foregroundColor(selectedTab == tab ? .white : .primary)
            .padding(.horizontal, 12)
            .padding(.vertical, 8)
            .background(
                selectedTab == tab
                    ? DesignSystem.Colors.accent
                    : Color.clear,
                in: .capsule
            )
            .contentShape(Capsule())
        }
        .buttonStyle(.plain)
    }

    // MARK: - Content

    @ViewBuilder
    private var selectedTabContent: some View {
        VStack(alignment: .leading, spacing: 24) {
            // Header
            VStack(alignment: .leading, spacing: 4) {
                Text(selectedTab.rawValue)
                    .font(.system(size: 24, weight: .semibold, design: .rounded))

                Text(tabDescription)
                    .font(.subheadline)
                    .foregroundColor(.secondary)
            }

            // Content
            Group {
                switch selectedTab {
                case .general:
                    generalSection
                case .updates:
                    updatesSection
                case .license:
                    LicenseSettingsSection()
                }
            }
        }
    }

    private var tabDescription: String {
        switch selectedTab {
        case .general: return "Storage and playback preferences"
        case .updates: return "Check for app updates"
        case .license: return "Manage your LoopMaker Pro license"
        }
    }

    // MARK: - General Section

    private var generalSection: some View {
        VStack(alignment: .leading, spacing: 16) {
            // Backend
            settingsCard {
                VStack(alignment: .leading, spacing: 12) {
                    Label("Music Engine", systemImage: "server.rack")
                        .font(.system(size: 14, weight: .semibold))

                    HStack {
                        Text("Status")
                            .font(.system(size: 13))
                            .foregroundColor(.secondary)
                        Spacer()
                        HStack(spacing: 6) {
                            Circle()
                                .fill(backendStatusColor)
                                .frame(width: 8, height: 8)
                            Text(backendStatusText)
                                .font(.system(size: 13, weight: .medium))
                        }
                    }

                    Divider()

                    HStack(spacing: 12) {
                        Button {
                            isRestartingBackend = true
                            Task {
                                await appState.restartBackend()
                                isRestartingBackend = false
                            }
                        } label: {
                            HStack(spacing: 4) {
                                if isRestartingBackend {
                                    ProgressView()
                                        .controlSize(.small)
                                }
                                Text("Restart Engine")
                                    .font(.system(size: 13, weight: .medium))
                            }
                        }
                        .disabled(isRestartingBackend || isCleanInstalling)

                        Button(role: .destructive) {
                            showCleanInstallConfirmation = true
                        } label: {
                            HStack(spacing: 4) {
                                if isCleanInstalling {
                                    ProgressView()
                                        .controlSize(.small)
                                }
                                Text("Clean Install")
                                    .font(.system(size: 13, weight: .medium))
                            }
                        }
                        .disabled(isRestartingBackend || isCleanInstalling)
                        .alert("Clean Install Backend?", isPresented: $showCleanInstallConfirmation) {
                            Button("Cancel", role: .cancel) {}
                            Button("Clean Install", role: .destructive) {
                                isCleanInstalling = true
                                Task {
                                    await appState.cleanInstallBackend()
                                    isCleanInstalling = false
                                }
                            }
                        } message: {
                            Text(
                                "This will reset the music engine and reinstall all components. "
                                + "This may take several minutes."
                            )
                        }
                    }
                }
            }

            // Storage
            settingsCard {
                VStack(alignment: .leading, spacing: 12) {
                    Label("Storage", systemImage: "internaldrive")
                        .font(.system(size: 14, weight: .semibold))

                    HStack {
                        Text("Tracks")
                            .font(.system(size: 13))
                            .foregroundColor(.secondary)
                        Spacer()
                        Text("\(appState.tracks.count)")
                            .font(.system(size: 13, weight: .medium))
                    }

                    HStack {
                        Text("Storage Used")
                            .font(.system(size: 13))
                            .foregroundColor(.secondary)
                        Spacer()
                        Text(storageUsed)
                            .font(.system(size: 13, weight: .medium))
                    }

                    Divider()

                    Button(role: .destructive) {
                        showClearTracksConfirmation = true
                    } label: {
                        Text("Clear All Tracks")
                            .font(.system(size: 13, weight: .medium))
                    }
                    .disabled(appState.tracks.isEmpty)
                    .alert("Clear All Tracks?", isPresented: $showClearTracksConfirmation) {
                        Button("Cancel", role: .cancel) {}
                        Button("Clear All", role: .destructive) {
                            clearAllTracks()
                        }
                    } message: {
                        Text("This permanently deletes \(appState.tracks.count) track(s) and their audio files.")
                    }
                }
            }
        }
    }

    // MARK: - Backend Status Helpers

    private var backendStatusColor: Color {
        switch appState.backendManager.state {
        case .running:
            return .green
        case .error:
            return .red
        case .notStarted:
            return .gray
        default:
            return .yellow
        }
    }

    private var backendStatusText: String {
        switch appState.backendManager.state {
        case .running:
            return "Running"
        case .error:
            return "Error"
        case .notStarted:
            return "Stopped"
        default:
            return "Starting..."
        }
    }

    // MARK: - Updates Section

    private var updatesSection: some View {
        VStack(alignment: .leading, spacing: 24) {
            // Current Version
            SettingsSection(title: "Current Version") {
                VStack(alignment: .leading, spacing: 0) {
                    HStack {
                        VStack(alignment: .leading, spacing: 4) {
                            Text("LoopMaker \(updateService.currentVersion)")
                                .font(.system(size: 15, weight: .semibold))
                            Text("Build \(updateService.currentBuild)")
                                .font(.system(size: 13))
                                .foregroundColor(.secondary)
                        }
                        Spacer()
                        Image(systemName: "checkmark.circle.fill")
                            .foregroundColor(.green)
                            .font(.system(size: 20))
                    }
                }
            }

            // Check for Updates
            SettingsSection(title: "Check for Updates", footer: "Last checked: \(updateService.lastCheckDateFormatted)") {
                VStack(alignment: .leading, spacing: 12) {
                    Button {
                        updateService.checkForUpdates()
                    } label: {
                        HStack {
                            if updateService.isCheckingForUpdates {
                                ProgressView()
                                    .controlSize(.small)
                                    .padding(.trailing, 4)
                            }
                            Text(updateService.isCheckingForUpdates ? "Checking..." : "Check for Updates")
                        }
                    }
                    .buttonStyle(.borderedProminent)
                    .disabled(updateService.isCheckingForUpdates || !updateService.canCheckForUpdates)
                }
            }

            // Automatic Updates
            SettingsSection(
                title: "Automatic Updates",
                footer: "When enabled, LoopMaker will periodically check for updates in the background."
            ) {
                VStack(alignment: .leading, spacing: 0) {
                    SettingsToggleRow(label: "Check for updates automatically", isOn: $automaticChecks)
                        .onChange(of: automaticChecks) { _, newValue in
                            updateService.automaticUpdateChecks = newValue
                        }

                    SettingsDivider()

                    SettingsToggleRow(label: "Download updates automatically", isOn: $automaticDownloads)
                        .onChange(of: automaticDownloads) { _, newValue in
                            updateService.automaticDownloads = newValue
                        }
                        .disabled(!automaticChecks)
                        .opacity(automaticChecks ? 1.0 : 0.5)
                }
            }

            // Update Channel Info
            SettingsSection(title: "About Updates") {
                VStack(alignment: .leading, spacing: 0) {
                    Label("Updates are delivered securely via Sparkle", systemImage: "lock.shield")
                        .font(.system(size: 13))
                    SettingsDivider()
                    Label("All updates are signed and verified", systemImage: "checkmark.seal")
                        .font(.system(size: 13))
                    SettingsDivider()
                    Label("Your data never leaves your device", systemImage: "hand.raised")
                        .font(.system(size: 13))
                }
            }
        }
        .onAppear {
            automaticChecks = updateService.automaticUpdateChecks
            automaticDownloads = updateService.automaticDownloads
        }
    }

    // MARK: - Helpers

    private func settingsCard<Content: View>(@ViewBuilder content: () -> Content) -> some View {
        content()
            .padding(16)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(
                Color(nsColor: .controlBackgroundColor),
                in: RoundedRectangle(cornerRadius: 14)
            )
    }

    private func sectionTitle(_ title: String) -> some View {
        Text(title)
            .font(.system(size: 13, weight: .semibold))
    }

    private var storageUsed: String {
        let totalBytes = appState.tracks.reduce(0) { total, track in
            let size = (try? FileManager.default.attributesOfItem(
                atPath: track.audioURL.path
            )[.size] as? Int) ?? 0
            return total + size
        }
        let formatter = ByteCountFormatter()
        formatter.allowedUnits = [.useMB, .useGB]
        formatter.countStyle = .file
        return formatter.string(fromByteCount: Int64(totalBytes))
    }

    private func clearAllTracks() {
        appState.clearAllTracks()
    }
}

#if PREVIEWS
#Preview {
    SettingsView()
        .environmentObject(AppState())
}
#endif
