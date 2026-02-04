import SwiftUI
import UniformTypeIdentifiers

struct ExportView: View {
    @Environment(\.dismiss) var dismiss
    let track: Track

    @State private var selectedFormat: AudioExportFormat = .wav
    @State private var isExporting = false
    @State private var showShareSheet = false

    var body: some View {
        NavigationStack {
            VStack(spacing: 24) {
                // Track Info
                trackInfoSection

                // Format Selection
                formatSection

                // Licensing Notice
                LicensingNoticeView()

                Spacer()

                // Export Button
                exportButton
            }
            .padding(24)
            .navigationTitle("Export Track")
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") {
                        dismiss()
                    }
                }
            }
        }
        .frame(width: 450, height: 500)
    }

    private var trackInfoSection: some View {
        HStack(spacing: 16) {
            RoundedRectangle(cornerRadius: 12)
                .fill(.blue.gradient)
                .frame(width: 80, height: 80)
                .overlay {
                    Image(systemName: "waveform")
                        .font(.largeTitle)
                        .foregroundStyle(.white)
                }

            VStack(alignment: .leading, spacing: 4) {
                Text(track.displayTitle)
                    .font(.title3.bold())
                    .lineLimit(2)

                Text(track.prompt)
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .lineLimit(2)

                HStack {
                    Label(track.duration.displayName, systemImage: "clock")
                    Label(track.model.displayName, systemImage: "cpu")
                }
                .font(.caption2)
                .foregroundStyle(.tertiary)
            }

            Spacer()
        }
        .padding()
        .background(.regularMaterial)
        .clipShape(RoundedRectangle(cornerRadius: 12))
    }

    private var formatSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Export Format")
                .font(.headline)

            Picker("Format", selection: $selectedFormat) {
                ForEach(AudioExportFormat.allCases, id: \.self) { format in
                    VStack(alignment: .leading) {
                        Text(format.displayName)
                        Text(format.description)
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }
                    .tag(format)
                }
            }
            .pickerStyle(.radioGroup)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }

    private var exportButton: some View {
        Button {
            exportTrack()
        } label: {
            HStack {
                if isExporting {
                    ProgressView()
                        .scaleEffect(0.8)
                } else {
                    Image(systemName: "square.and.arrow.up")
                }
                Text(isExporting ? "Exporting..." : "Export")
            }
            .frame(maxWidth: .infinity)
            .frame(height: 44)
        }
        .buttonStyle(.borderedProminent)
        .disabled(isExporting)
    }

    private func exportTrack() {
        isExporting = true

        let panel = NSSavePanel()
        panel.allowedContentTypes = [UTType(filenameExtension: selectedFormat.fileExtension)!]
        panel.nameFieldStringValue = "\(track.displayTitle).\(selectedFormat.fileExtension)"
        panel.canCreateDirectories = true

        panel.begin { response in
            defer { isExporting = false }

            guard response == .OK, let url = panel.url else { return }

            do {
                if selectedFormat == .wav {
                    // Direct copy for WAV
                    try FileManager.default.copyItem(at: track.audioURL, to: url)
                } else {
                    // Convert to M4A
                    try convertToM4A(from: track.audioURL, to: url)
                }
                dismiss()
            } catch {
                // Show error
                print("Export error: \(error)")
            }
        }
    }

    private func convertToM4A(from source: URL, to destination: URL) throws {
        // For now, just copy - real implementation would use AVAssetExportSession
        try FileManager.default.copyItem(at: source, to: destination)
    }
}

#Preview {
    ExportView(track: Track(
        prompt: "Chill lo-fi beats with vinyl crackle",
        duration: .medium,
        model: .small,
        audioURL: URL(fileURLWithPath: "/tmp/test.wav")
    ))
}
