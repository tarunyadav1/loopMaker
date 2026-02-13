import AVFoundation
import SwiftUI
import UniformTypeIdentifiers

struct ExportView: View {
    @Environment(\.dismiss) var dismiss
    let track: Track

    @State private var selectedFormat: AudioExportFormat = .wav
    @State private var isExporting = false
    @State private var errorMessage: String?
    @State private var showErrorAlert = false

    var body: some View {
        NavigationStack {
            VStack(spacing: 24) {
                // Track Info
                trackInfoSection

                // Format Selection
                formatSection

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
        .alert("Export Failed", isPresented: $showErrorAlert) {
            Button("OK", role: .cancel) {}
        } message: {
            Text(errorMessage ?? "Something went wrong while exporting the track.")
        }
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

            VStack(spacing: 8) {
                ForEach(AudioExportFormat.allCases, id: \.self) { format in
                    FormatOptionCard(
                        format: format,
                        isSelected: selectedFormat == format,
                        estimatedSize: estimateFileSize(for: format)
                    ) {
                        selectedFormat = format
                    }
                }
            }

            // Format guidance
            HStack(spacing: 6) {
                Image(systemName: "info.circle")
                    .font(.system(size: 11))
                Text(formatGuidance)
                    .font(.caption)
            }
            .foregroundStyle(.secondary)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }

    private var formatGuidance: String {
        switch selectedFormat {
        case .wav:
            return "Best for music production and editing. Larger file, no quality loss."
        case .m4a:
            return "Best for sharing and listening. ~10x smaller file with near-lossless quality."
        }
    }

    private func estimateFileSize(for format: AudioExportFormat) -> String {
        let seconds = track.durationSeconds
        switch format {
        case .wav:
            // 44.1kHz * 16bit * 2ch = ~176KB/s
            let bytes = seconds * 176_400
            return formatBytes(bytes)
        case .m4a:
            // ~128kbps AAC = ~16KB/s
            let bytes = seconds * 16_000
            return formatBytes(bytes)
        }
    }

    private func formatBytes(_ bytes: Double) -> String {
        if bytes >= 1_048_576 {
            return String(format: "~%.1f MB", bytes / 1_048_576)
        }
        return String(format: "~%.0f KB", bytes / 1024)
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

            if selectedFormat == .wav {
                do {
                    if FileManager.default.fileExists(atPath: url.path) {
                        try FileManager.default.removeItem(at: url)
                    }
                    try FileManager.default.copyItem(at: track.audioURL, to: url)
                    dismiss()
                } catch {
                    showExportError(error, context: "WAV export")
                    Log.export.error("WAV export error: \(error.localizedDescription)")
                }
            } else {
                convertToM4A(from: track.audioURL, to: url)
            }
        }
    }

    private func convertToM4A(from source: URL, to destination: URL) {
        let asset = AVAsset(url: source)
        guard let session = AVAssetExportSession(asset: asset, presetName: AVAssetExportPresetAppleM4A) else {
            showExportError(nil, context: "M4A export")
            Log.export.error("Failed to create AVAssetExportSession")
            isExporting = false
            return
        }

        // Remove destination if it already exists (export session won't overwrite)
        try? FileManager.default.removeItem(at: destination)

        session.outputURL = destination
        session.outputFileType = .m4a

        session.exportAsynchronously {
            DispatchQueue.main.async {
                self.isExporting = false
                switch session.status {
                case .completed:
                    self.dismiss()
                case .failed:
                    self.showExportError(session.error, context: "M4A export")
                    Log.export.error("M4A export failed: \(session.error?.localizedDescription ?? "unknown")")
                case .cancelled:
                    self.showExportError(nil, context: "M4A export was cancelled")
                    Log.export.error("M4A export cancelled")
                default:
                    break
                }
            }
        }
    }

    private func showExportError(_ error: Error?, context: String) {
        let reason = error?.localizedDescription ?? "Please choose a different location and try again."
        errorMessage = "\(context) failed. \(reason)"
        showErrorAlert = true
    }
}

// MARK: - Format Option Card

struct FormatOptionCard: View {
    let format: AudioExportFormat
    let isSelected: Bool
    let estimatedSize: String
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            HStack(spacing: 12) {
                // Radio circle
                ZStack {
                    Circle()
                        .strokeBorder(isSelected ? DesignSystem.Colors.accent : Color.secondary.opacity(0.3), lineWidth: 2)
                        .frame(width: 18, height: 18)

                    if isSelected {
                        Circle()
                            .fill(DesignSystem.Colors.accent)
                            .frame(width: 10, height: 10)
                    }
                }

                VStack(alignment: .leading, spacing: 2) {
                    Text(format.displayName)
                        .font(.system(size: 13, weight: .medium))
                        .foregroundStyle(.primary)

                    Text(format.description)
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }

                Spacer()

                // Estimated size
                Text(estimatedSize)
                    .font(.system(size: 11, weight: .medium, design: .monospaced))
                    .foregroundStyle(.tertiary)
            }
            .padding(10)
            .background(
                RoundedRectangle(cornerRadius: 8)
                    .fill(isSelected ? DesignSystem.Colors.accent.opacity(0.08) : Color.primary.opacity(0.03))
            )
            .overlay(
                RoundedRectangle(cornerRadius: 8)
                    .strokeBorder(isSelected ? DesignSystem.Colors.accent.opacity(0.3) : Color.clear, lineWidth: 1)
            )
        }
        .buttonStyle(.plain)
    }
}

#Preview {
    ExportView(track: Track(
        prompt: "Chill lo-fi beats with vinyl crackle",
        duration: .medium,
        model: .acestep,
        audioURL: URL(fileURLWithPath: "/tmp/test.wav")
    ))
}
