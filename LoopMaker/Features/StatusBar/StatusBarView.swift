import SwiftUI

/// Always-visible status bar at the bottom of the app window
struct StatusBarView: View {
    var embeddedInSidebar: Bool = false
    @EnvironmentObject var appState: AppState
    @State private var backendCPUPercent: Double?
    @State private var backendCPURawPercent: Double?
    @State private var lastCPUSampleAt: Date?
    @State private var isHoveringCPUStatus = false
    @State private var cpuSamplingLoopTask: Task<Void, Never>?
    @State private var cpuReadTask: Task<Void, Never>?

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
            cpuReadTask?.cancel()
            cpuReadTask = nil
        }
    }

    private var statusPanel: some View {
        GlassEffectContainer(spacing: 8) {
            HStack(spacing: 8) {
                statusItem(icon: "dot.radiowaves.left.and.right", text: backendStatusText, tint: backendStatusColor)
                cpuStatusItem
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

    @ViewBuilder
    private func statusItem(icon: String, text: String, tint: Color, tooltip: String? = nil) -> some View {
        let item = HStack(spacing: 5) {
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

        if let tooltip, !tooltip.isEmpty {
            item.help(tooltip)
        } else {
            item
        }
    }

    private var cpuStatusItem: some View {
        statusItem(icon: "cpu", text: cpuText, tint: cpuTintColor, tooltip: cpuTooltip)
            .popover(isPresented: $isHoveringCPUStatus, arrowEdge: .top) {
                cpuTooltipBubble
                    .padding(8)
            }
            .onHover { hovering in
                withAnimation(.easeOut(duration: 0.12)) {
                    isHoveringCPUStatus = hovering
                }
            }
    }

    private var cpuTooltipBubble: some View {
        Text(cpuTooltip)
            .font(.system(size: 11, weight: .medium))
            .foregroundStyle(DesignSystem.Colors.textPrimary)
            .multilineTextAlignment(.leading)
            .lineSpacing(2)
            .fixedSize(horizontal: false, vertical: true)
            .frame(width: 250, alignment: .leading)
            .padding(10)
            .background(.regularMaterial, in: RoundedRectangle(cornerRadius: 10))
            .overlay(
                RoundedRectangle(cornerRadius: 10)
                    .stroke(Color.primary.opacity(0.14), lineWidth: 1)
            )
            .shadow(color: .black.opacity(0.16), radius: 10, y: 4)
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
        return "CPU \(Self.formatPercent(cpu))"
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

    private var cpuTooltip: String {
        guard appState.backendConnected else {
            return "Backend is offline.\nCPU usage is shown when the engine is connected."
        }

        guard let cpu = backendCPUPercent,
              let rawCPU = backendCPURawPercent else {
            return "Sampling backend CPU usage...\nRefreshes every 2 seconds."
        }

        let pidText = appState.backendManager.currentBackendPID.map(String.init) ?? "Unknown"
        let coreCount = ProcessInfo.processInfo.activeProcessorCount
        let sampledAtText = lastCPUSampleAt.map { $0.formatted(date: .omitted, time: .standard) } ?? "Just now"
        let multicoreNote = rawCPU > 100
            ? "\nRaw process CPU can exceed 100% when multiple cores are active."
            : ""

        return """
        Backend CPU details
        Total CPU usage: \(Self.formatPercent(cpu))
        Process CPU (raw): \(Self.formatPercent(rawCPU))
        Backend PID: \(pidText)
        Logical cores: \(coreCount)
        Sampled at: \(sampledAtText)
        Refresh rate: 2 seconds\(multicoreNote)
        """
    }

    private func refreshCPUUsage() {
        cpuReadTask?.cancel()

        guard appState.backendConnected,
              let pid = appState.backendManager.currentBackendPID else {
            backendCPUPercent = nil
            backendCPURawPercent = nil
            lastCPUSampleAt = nil
            return
        }

        cpuReadTask = Task {
            let snapshot = await Self.readCPUPercent(pid: pid)
            guard !Task.isCancelled else { return }
            backendCPUPercent = snapshot?.normalizedPercent
            backendCPURawPercent = snapshot?.rawPercent
            lastCPUSampleAt = snapshot?.sampledAt
        }
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

    nonisolated private struct CPUSnapshot {
        let rawPercent: Double
        let normalizedPercent: Double
        let sampledAt: Date
    }

    nonisolated private static func readCPUPercent(pid: Int32) async -> CPUSnapshot? {
        await withCheckedContinuation { continuation in
            let process = Process()
            process.executableURL = URL(fileURLWithPath: "/bin/ps")
            process.arguments = ["-p", "\(pid)", "-o", "%cpu="]

            let outputPipe = Pipe()
            process.standardOutput = outputPipe
            process.standardError = FileHandle.nullDevice

            process.terminationHandler = { process in
                guard process.terminationStatus == 0 else {
                    continuation.resume(returning: nil)
                    return
                }

                let data = outputPipe.fileHandleForReading.readDataToEndOfFile()
                guard let raw = String(data: data, encoding: .utf8)?
                    .trimmingCharacters(in: .whitespacesAndNewlines),
                    !raw.isEmpty
                else {
                    continuation.resume(returning: nil)
                    return
                }

                let normalized = raw.replacingOccurrences(of: ",", with: ".")
                guard let rawPercent = Double(normalized) else {
                    continuation.resume(returning: nil)
                    return
                }

                continuation.resume(
                    returning: CPUSnapshot(
                        rawPercent: rawPercent,
                        normalizedPercent: normalizedCPUPercent(fromRawPercent: rawPercent),
                        sampledAt: Date()
                    )
                )
            }

            do {
                try process.run()
            } catch {
                continuation.resume(returning: nil)
            }
        }
    }

    nonisolated private static func normalizedCPUPercent(fromRawPercent rawPercent: Double) -> Double {
        let coreCount = max(ProcessInfo.processInfo.activeProcessorCount, 1)
        let normalized = rawPercent / Double(coreCount)
        return min(max(normalized, 0), 100)
    }

    nonisolated private static func formatPercent(_ value: Double) -> String {
        if value < 0.1 {
            return "<0.1%"
        }
        return String(format: "%.1f%%", value)
    }
}

#if PREVIEWS
#Preview {
    VStack {
        Spacer()
        StatusBarView()
            .environmentObject(AppState())
    }
    .frame(width: 900, height: 100)
}
#endif
