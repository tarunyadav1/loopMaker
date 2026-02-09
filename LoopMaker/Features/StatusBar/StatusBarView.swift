import SwiftUI

/// Always-visible status bar at the bottom of the app window
struct StatusBarView: View {
    @EnvironmentObject var appState: AppState

    @State private var cpuUsage: Double = 0
    @State private var memoryUsage: Double = 0
    @State private var gpuUsage: Double = 0
    @State private var timer: Timer?

    var body: some View {
        HStack(spacing: 0) {
            // Left: Backend status
            backendStatusPill
                .padding(.leading, Spacing.sm)

            Spacer()

            // Center: System stats
            systemStats

            Spacer()

            // Right: Model info
            trailingLinks
                .padding(.trailing, Spacing.sm)
        }
        .frame(height: 24)
        .background(.ultraThinMaterial)
        .onAppear { startMonitoring() }
        .onDisappear { stopMonitoring() }
    }

    // MARK: - Backend Status Pill

    private var backendStatusPill: some View {
        HStack(spacing: 4) {
            Circle()
                .fill(backendStatusColor)
                .frame(width: 6, height: 6)

            Text(backendStatusText)
                .font(.system(size: 10, weight: .medium))
                .foregroundStyle(backendStatusColor)
        }
        .padding(.horizontal, 8)
        .padding(.vertical, 2)
        .background(
            Capsule()
                .fill(backendStatusColor.opacity(0.15))
        )
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
            return "Generating..."
        } else if appState.backendConnected {
            return "Backend Ready"
        } else if appState.backendManager.state.isSetupPhase {
            return "Connecting..."
        } else {
            return "Backend Offline"
        }
    }

    // MARK: - System Stats

    private var systemStats: some View {
        HStack(spacing: Spacing.md) {
            statItem(label: "CPU", value: cpuUsage)
            statDivider
            statItem(label: "RAM", value: memoryUsage)
        }
    }

    private func statItem(label: String, value: Double) -> some View {
        HStack(spacing: 4) {
            Text(label)
                .font(.system(size: 10, weight: .medium, design: .monospaced))
                .foregroundStyle(DesignSystem.Colors.textMuted)

            Text(String(format: "%.1f%%", value))
                .font(.system(size: 10, weight: .semibold, design: .monospaced))
                .foregroundStyle(statColor(for: value))
        }
    }

    private var statDivider: some View {
        Text("\u{00B7}")
            .font(.system(size: 10))
            .foregroundStyle(DesignSystem.Colors.textMuted)
    }

    private func statColor(for value: Double) -> Color {
        if value > 85 {
            return DesignSystem.Colors.error
        } else if value > 60 {
            return DesignSystem.Colors.warning
        }
        return DesignSystem.Colors.textSecondary
    }

    // MARK: - Trailing Links

    private var trailingLinks: some View {
        HStack(spacing: Spacing.sm) {
            if appState.isProUser {
                Text("Pro")
                    .font(.system(size: 10, weight: .bold))
                    .foregroundStyle(DesignSystem.Colors.accent)
            } else {
                Text("Free")
                    .font(.system(size: 10, weight: .medium))
                    .foregroundStyle(DesignSystem.Colors.textMuted)
            }
        }
    }

    // MARK: - System Monitoring

    private func startMonitoring() {
        updateStats()
        timer = Timer.scheduledTimer(withTimeInterval: 3.0, repeats: true) { _ in
            Task { @MainActor in
                updateStats()
            }
        }
    }

    private func stopMonitoring() {
        timer?.invalidate()
        timer = nil
    }

    private func updateStats() {
        cpuUsage = SystemMonitor.cpuUsage()
        memoryUsage = SystemMonitor.memoryUsage()
        gpuUsage = SystemMonitor.gpuUsage()
    }
}

// MARK: - System Monitor

@MainActor
enum SystemMonitor {
    // Store previous CPU ticks for delta-based usage calculation
    private nonisolated(unsafe) static var prevUser: Double = 0
    private nonisolated(unsafe) static var prevSystem: Double = 0
    private nonisolated(unsafe) static var prevIdle: Double = 0
    private nonisolated(unsafe) static var prevNice: Double = 0
    private nonisolated(unsafe) static var hasBaseline = false

    /// Read raw CPU tick counters from the kernel.
    /// IMPORTANT: Uses non-optional host_cpu_load_info to avoid Optional tag byte
    /// corrupting the memory layout when rebound to integer_t for host_statistics.
    private static func readCPUTicks() -> (user: Double, system: Double, idle: Double, nice: Double)? {
        var cpuLoadInfo = host_cpu_load_info()  // non-optional: correct memory layout
        var count = mach_msg_type_number_t(
            MemoryLayout<host_cpu_load_info>.size / MemoryLayout<integer_t>.size
        )

        let result: kern_return_t = withUnsafeMutablePointer(to: &cpuLoadInfo) { ptr in
            ptr.withMemoryRebound(to: integer_t.self, capacity: Int(count)) { intPtr in
                host_statistics(
                    mach_host_self(),
                    HOST_CPU_LOAD_INFO,
                    intPtr,
                    &count
                )
            }
        }

        guard result == KERN_SUCCESS else { return nil }

        return (
            Double(cpuLoadInfo.cpu_ticks.0),   // CPU_STATE_USER
            Double(cpuLoadInfo.cpu_ticks.1),   // CPU_STATE_SYSTEM
            Double(cpuLoadInfo.cpu_ticks.2),   // CPU_STATE_IDLE
            Double(cpuLoadInfo.cpu_ticks.3)    // CPU_STATE_NICE
        )
    }

    /// System-wide CPU usage computed from tick deltas between readings.
    static func cpuUsage() -> Double {
        guard let ticks = readCPUTicks() else { return 0 }

        if !hasBaseline {
            prevUser = ticks.user
            prevSystem = ticks.system
            prevIdle = ticks.idle
            prevNice = ticks.nice
            hasBaseline = true
            return 0
        }

        let dUser = ticks.user - prevUser
        let dSystem = ticks.system - prevSystem
        let dIdle = ticks.idle - prevIdle
        let dNice = ticks.nice - prevNice

        prevUser = ticks.user
        prevSystem = ticks.system
        prevIdle = ticks.idle
        prevNice = ticks.nice

        let total = dUser + dSystem + dIdle + dNice
        guard total > 0 else { return 0 }

        return ((dUser + dSystem + dNice) / total) * 100.0
    }

    /// System-wide memory usage via vm_statistics64 (not just this app).
    static func memoryUsage() -> Double {
        var vmStats = vm_statistics64()
        var count = mach_msg_type_number_t(
            MemoryLayout<vm_statistics64_data_t>.size / MemoryLayout<integer_t>.size
        )

        let result = withUnsafeMutablePointer(to: &vmStats) { ptr in
            ptr.withMemoryRebound(to: integer_t.self, capacity: Int(count)) { intPtr in
                host_statistics64(
                    mach_host_self(),
                    HOST_VM_INFO64,
                    intPtr,
                    &count
                )
            }
        }

        guard result == KERN_SUCCESS else { return 0 }

        // macOS page size: 16384 on Apple Silicon, 4096 on Intel.
        // Use sysctl to get it safely without accessing mutable global state.
        let pageSize: Double = {
            var size: vm_size_t = 0
            var len = MemoryLayout<vm_size_t>.size
            sysctlbyname("hw.pagesize", &size, &len, nil, 0)
            return size > 0 ? Double(size) : 16384
        }()
        let active = Double(vmStats.active_count) * pageSize
        let wired = Double(vmStats.wire_count) * pageSize
        let compressed = Double(vmStats.compressor_page_count) * pageSize
        let totalPhysical = Double(ProcessInfo.processInfo.physicalMemory)

        guard totalPhysical > 0 else { return 0 }
        return ((active + wired + compressed) / totalPhysical) * 100.0
    }

    /// GPU usage - not available via public macOS API
    static func gpuUsage() -> Double {
        return 0.0
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
