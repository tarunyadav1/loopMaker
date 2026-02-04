import SwiftUI

struct GenerationView: View {
    @EnvironmentObject var appState: AppState
    @State private var prompt = ""
    @State private var selectedDuration: TrackDuration = .medium
    @State private var selectedGenre: GenrePreset?

    var body: some View {
        ScrollView {
            VStack(spacing: 24) {
                // Header
                headerSection

                // Prompt Input
                promptSection

                // Genre Presets
                genreSection

                // Duration & Model
                settingsSection

                // Generate Button
                generateButton

                // Progress
                if appState.isGenerating {
                    progressSection
                }

                Spacer()
            }
            .padding(32)
        }
        .navigationTitle("Generate Music")
        .background(Color(nsColor: .windowBackgroundColor))
    }

    // MARK: - Sections

    private var headerSection: some View {
        VStack(spacing: 8) {
            Image(systemName: "waveform.circle.fill")
                .font(.system(size: 64))
                .foregroundStyle(.blue.gradient)

            Text("Create AI Music")
                .font(.largeTitle.bold())

            Text("Describe the music you want to create")
                .font(.subheadline)
                .foregroundStyle(.secondary)
        }
        .padding(.bottom, 16)
    }

    private var promptSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            Label("Prompt", systemImage: "text.bubble")
                .font(.headline)

            TextEditor(text: $prompt)
                .font(.body)
                .frame(height: 100)
                .padding(12)
                .background(.regularMaterial)
                .clipShape(RoundedRectangle(cornerRadius: 12))
                .overlay(
                    RoundedRectangle(cornerRadius: 12)
                        .stroke(.quaternary, lineWidth: 1)
                )

            Text("Example: \"chill lo-fi beats with vinyl crackle and soft piano\"")
                .font(.caption)
                .foregroundStyle(.secondary)
        }
    }

    private var genreSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            Label("Genre Preset", systemImage: "music.note")
                .font(.headline)

            LazyVGrid(columns: [
                GridItem(.adaptive(minimum: 120, maximum: 160), spacing: 12)
            ], spacing: 12) {
                ForEach(GenrePreset.allPresets) { preset in
                    GenreButton(
                        preset: preset,
                        isSelected: selectedGenre?.id == preset.id
                    ) {
                        if selectedGenre?.id == preset.id {
                            selectedGenre = nil
                        } else {
                            selectedGenre = preset
                        }
                    }
                }
            }
        }
    }

    private var settingsSection: some View {
        HStack(spacing: 24) {
            // Duration
            VStack(alignment: .leading, spacing: 8) {
                Label("Duration", systemImage: "clock")
                    .font(.headline)

                Picker("Duration", selection: $selectedDuration) {
                    ForEach(TrackDuration.allCases, id: \.self) { duration in
                        Text(duration.displayName).tag(duration)
                    }
                }
                .pickerStyle(.segmented)
            }

            // Model
            VStack(alignment: .leading, spacing: 8) {
                Label("Model", systemImage: "cpu")
                    .font(.headline)

                Picker("Model", selection: $appState.selectedModel) {
                    ForEach(ModelType.allCases, id: \.self) { model in
                        Text(model.displayName).tag(model)
                    }
                }
                .pickerStyle(.segmented)
            }
        }
    }

    private var generateButton: some View {
        Button(action: generate) {
            HStack(spacing: 12) {
                if appState.isGenerating {
                    ProgressView()
                        .scaleEffect(0.8)
                        .progressViewStyle(.circular)
                } else {
                    Image(systemName: "waveform")
                }
                Text(appState.isGenerating ? "Generating..." : "Generate Music")
                    .fontWeight(.semibold)
            }
            .frame(maxWidth: .infinity)
            .frame(height: 50)
        }
        .buttonStyle(.borderedProminent)
        .controlSize(.large)
        .disabled(!canGenerate)
    }

    private var progressSection: some View {
        VStack(spacing: 12) {
            ProgressView(value: appState.generationProgress)
                .progressViewStyle(.linear)

            Text(appState.generationStatus)
                .font(.caption)
                .foregroundStyle(.secondary)

            Button("Cancel") {
                appState.cancelGeneration()
            }
            .buttonStyle(.bordered)
        }
        .padding()
        .background(.regularMaterial)
        .clipShape(RoundedRectangle(cornerRadius: 12))
    }

    // MARK: - Helpers

    private var canGenerate: Bool {
        !prompt.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty && appState.canGenerate
    }

    private func generate() {
        let request = GenerationRequest(
            prompt: prompt,
            duration: selectedDuration,
            model: appState.selectedModel,
            genre: selectedGenre
        )
        appState.startGeneration(request: request)
    }
}

struct GenreButton: View {
    let preset: GenrePreset
    let isSelected: Bool
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            VStack(spacing: 8) {
                Image(systemName: preset.icon)
                    .font(.title2)
                Text(preset.name)
                    .font(.caption.weight(.medium))
            }
            .frame(maxWidth: .infinity)
            .frame(height: 70)
            .background(isSelected ? Color.accentColor.opacity(0.2) : Color.clear)
            .background(.regularMaterial)
            .clipShape(RoundedRectangle(cornerRadius: 12))
            .overlay(
                RoundedRectangle(cornerRadius: 12)
                    .stroke(isSelected ? Color.accentColor : Color.clear, lineWidth: 2)
            )
        }
        .buttonStyle(.plain)
    }
}

#Preview {
    GenerationView()
        .environmentObject(AppState())
}
