import SwiftUI

/// Always-visible status bar at the bottom of the app window
struct StatusBarView: View {
    var embeddedInSidebar: Bool = false
    @EnvironmentObject var appState: AppState
    @State private var backendCPUPercent: Double?
    @State private var cpuSamplingLoopTask: Task<Void, Never>?

    var body: some View {
        Group {
            if embeddedInSidebar {
                statusPanel
                    .frame(maxWidth: .infinity, alignment: .leading)
            } else {
                HStack {
                    statusPanel
                    Spacer(minLength: 0)
                }
                .padding(.horizontal, Spacing.sm)
                .padding(.vertical, 4)
                .frame(height: 32)
                .background(.ultraThinMaterial)
            }
        }
        .onAppear {
            startCPUSamplingLoop()
        }
        .onChange(of: appState.backendConnected) {
            refreshCPUUsage()
        }
        .onDisappear {
            cpuSamplingLoopTask?.cancel()
            cpuSamplingLoopTask = nil
        }
    }

    private var statusPanel: some View {
        GlassEffectContainer(spacing: 8) {
            HStack(spacing: 8) {
                statusItem(icon: "dot.radiowaves.left.and.right", text: backendStatusText, tint: backendStatusColor)
                statusItem(icon: "cpu", text: cpuText, tint: cpuTintColor)
            }
        }
        .padding(.horizontal, 8)
        .padding(.vertical, 8)
        .background(
            RoundedRectangle(cornerRadius: 14)
                .fill(Color.primary.opacity(0.04))
        )
        .glassEffect(.regular, in: RoundedRectangle(cornerRadius: 14))
    }

    private func statusItem(icon: String, text: String, tint: Color) -> some View {
        HStack(spacing: 5) {
            Image(systemName: icon)
                .font(.system(size: 11, weight: .semibold))
                .foregroundStyle(tint)
            Text(text)
                .font(.system(size: 10, weight: .bold))
                .monospacedDigit()
                .foregroundStyle(DesignSystem.Colors.textPrimary)
                .lineLimit(1)
                .minimumScaleFactor(0.9)
        }
        .padding(.horizontal, 10)
        .padding(.vertical, 6)
        .glassEffect(.regular.tint(tint.opacity(0.2)), in: Capsule())
    }

    private var backendStatusColor: Color {
        if appState.isGenerating {
            return DesignSystem.Colors.warning
        } else if appState.backendConnected {
            return DesignSystem.Colors.success
        } else if appState.backendManager.state.isSetupPhase {
            return DesignSystem.Colors.warning
        } else {
            return DesignSystem.Colors.error
        }
    }

    private var backendStatusText: String {
        if appState.isGenerating {
            return embeddedInSidebar ? "Generating" : "Generating"
        } else if appState.backendConnected {
            return embeddedInSidebar ? "Ready" : "Engine Ready"
        } else if appState.backendManager.state.isSetupPhase {
            return "Connecting"
        } else {
            return "Offline"
        }
    }

    private var cpuText: String {
        guard appState.backendConnected else { return "CPU --" }
        guard let cpu = backendCPUPercent else { return "CPU .." }
        if cpu < 0.1 {
            return "CPU <0.1%"
        }
        return String(format: "CPU %.1f%%", cpu)
    }

    private var cpuTintColor: Color {
        guard let cpu = backendCPUPercent else {
            return DesignSystem.Colors.textSecondary
        }
        switch cpu {
        case ..<40:
            return DesignSystem.Colors.success
        case ..<80:
            return DesignSystem.Colors.warning
        default:
            return DesignSystem.Colors.error
        }
    }

    private func refreshCPUUsage() {
        guard appState.backendConnected,
              let pid = appState.backendManager.currentBackendPID else {
            backendCPUPercent = nil
            return
        }

        backendCPUPercent = Self.readCPUPercent(pid: pid)
    }

    private func startCPUSamplingLoop() {
        cpuSamplingLoopTask?.cancel()
        cpuSamplingLoopTask = Task {
            refreshCPUUsage()
            while !Task.isCancelled {
                try? await Task.sleep(for: .seconds(2))
                guard !Task.isCancelled else { break }
                refreshCPUUsage()
            }
        }
    }

    nonisolated private static func readCPUPercent(pid: Int32) -> Double? {
        let process = Process()
        process.executableURL = URL(fileURLWithPath: "/bin/zsh")
        process.arguments = ["-lc", "ps -p \(pid) -o %cpu="]

        let outputPipe = Pipe()
        process.standardOutput = outputPipe
        process.standardError = FileHandle.nullDevice

        do {
            try process.run()
            process.waitUntilExit()
            guard process.terminationStatus == 0 else { return nil }
            let data = outputPipe.fileHandleForReading.readDataToEndOfFile()
            guard let raw = String(data: data, encoding: .utf8)?
                .trimmingCharacters(in: .whitespacesAndNewlines),
                !raw.isEmpty
            else {
                return nil
            }

            let normalized = raw.replacingOccurrences(of: ",", with: ".")
            return Double(normalized)
        } catch {
            return nil
        }
    }
}

#Preview {
    VStack {
        Spacer()
        StatusBarView()
            .environmentObject(AppState())
    }
    .frame(width: 900, height: 100)
}
