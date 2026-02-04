import SwiftUI

struct SettingsView: View {
    @EnvironmentObject var appState: AppState
    @Environment(\.dismiss) var dismiss

    var body: some View {
        NavigationStack {
            Form {
                // Models Section
                Section("Models") {
                    ForEach(ModelType.allCases, id: \.self) { model in
                        ModelRow(model: model)
                    }
                }

                // Storage Section
                Section("Storage") {
                    LabeledContent("Tracks", value: "\(appState.tracks.count)")
                    LabeledContent("Storage Used", value: storageUsed)

                    Button("Clear All Tracks", role: .destructive) {
                        clearAllTracks()
                    }
                    .disabled(appState.tracks.isEmpty)
                }

                // About Section
                Section("About") {
                    LabeledContent("Version", value: "1.0.0")
                    LabeledContent("Build", value: "1")

                    Link("Privacy Policy", destination: URL(string: "https://loopmaker.app/privacy")!)
                    Link("Terms of Service", destination: URL(string: "https://loopmaker.app/terms")!)
                }

                // Licensing Section
                Section {
                    LicensingNoticeView()
                } header: {
                    Text("Licensing")
                } footer: {
                    Text("MusicGen model weights are licensed CC-BY-NC 4.0")
                }
            }
            .formStyle(.grouped)
            .navigationTitle("Settings")
            .toolbar {
                ToolbarItem(placement: .confirmationAction) {
                    Button("Done") {
                        dismiss()
                    }
                }
            }
        }
        .frame(minWidth: 500, minHeight: 600)
    }

    private var storageUsed: String {
        let totalBytes = appState.tracks.reduce(0) { total, track in
            let size = (try? FileManager.default.attributesOfItem(atPath: track.audioURL.path)[.size] as? Int) ?? 0
            return total + size
        }

        let formatter = ByteCountFormatter()
        formatter.allowedUnits = [.useMB, .useGB]
        formatter.countStyle = .file
        return formatter.string(fromByteCount: Int64(totalBytes))
    }

    private func clearAllTracks() {
        for track in appState.tracks {
            try? FileManager.default.removeItem(at: track.audioURL)
        }
        appState.tracks.removeAll()
        appState.selectedTrack = nil
    }
}

struct ModelRow: View {
    @EnvironmentObject var appState: AppState
    let model: ModelType

    var downloadState: ModelDownloadState {
        appState.modelDownloadStates[model] ?? .notDownloaded
    }

    var body: some View {
        HStack {
            VStack(alignment: .leading, spacing: 4) {
                Text(model.displayName)
                    .font(.headline)

                Text("\(model.parameters) parameters • \(model.sizeFormatted)")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }

            Spacer()

            downloadStateView
        }
        .padding(.vertical, 4)
    }

    @ViewBuilder
    private var downloadStateView: some View {
        switch downloadState {
        case .notDownloaded:
            Button("Download") {
                appState.downloadModel(model)
            }
            .buttonStyle(.bordered)

        case .downloading(let progress):
            HStack(spacing: 8) {
                ProgressView(value: progress)
                    .frame(width: 100)
                Text("\(Int(progress * 100))%")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }

        case .downloaded:
            Label("Downloaded", systemImage: "checkmark.circle.fill")
                .foregroundStyle(.green)

        case .error:
            VStack(alignment: .trailing) {
                Label("Error", systemImage: "exclamationmark.triangle.fill")
                    .foregroundStyle(.red)
                Button("Retry") {
                    appState.downloadModel(model)
                }
                .buttonStyle(.bordered)
                .controlSize(.small)
            }
        }
    }
}

struct LicensingNoticeView: View {
    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            Label("Non-Commercial Use Only", systemImage: "exclamationmark.triangle.fill")
                .font(.headline)
                .foregroundStyle(.orange)

            Text("""
                Generated music uses Meta's MusicGen model (CC-BY-NC 4.0).

                You MAY use for:
                • Personal projects
                • Educational content
                • Non-monetized videos

                You may NOT use for:
                • Monetized YouTube/TikTok
                • Commercial podcasts
                • Paid client work
                • Commercial products
                """)
                .font(.caption)
                .foregroundStyle(.secondary)
        }
        .padding()
        .background(.orange.opacity(0.1))
        .clipShape(RoundedRectangle(cornerRadius: 8))
    }
}

#Preview {
    SettingsView()
        .environmentObject(AppState())
}
