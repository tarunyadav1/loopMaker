#if canImport(XCTest)
import XCTest
@testable import LoopMaker

final class LoopMakerTests: XCTestCase {

    // MARK: - Track Duration Tests

    func testTrackDurationSeconds() {
        XCTAssertEqual(TrackDuration.short.seconds, 10)
        XCTAssertEqual(TrackDuration.medium.seconds, 30)
        XCTAssertEqual(TrackDuration.long.seconds, 60)
    }

    func testTrackDurationDisplayName() {
        XCTAssertEqual(TrackDuration.short.displayName, "10 sec")
        XCTAssertEqual(TrackDuration.medium.displayName, "30 sec")
        XCTAssertEqual(TrackDuration.long.displayName, "1 min")
        XCTAssertEqual(TrackDuration.extended.displayName, "2 min")
        XCTAssertEqual(TrackDuration.maximum.displayName, "4 min")
    }

    func testTrackDurationSeconds_Extended() {
        XCTAssertEqual(TrackDuration.extended.seconds, 120)
        XCTAssertEqual(TrackDuration.maximum.seconds, 240)
    }

    func testTrackDurationCompatibility() {
        // ACE-Step supports up to 240s (all durations)
        XCTAssertTrue(TrackDuration.short.isCompatible(with: .acestep))
        XCTAssertTrue(TrackDuration.medium.isCompatible(with: .acestep))
        XCTAssertTrue(TrackDuration.long.isCompatible(with: .acestep))
        XCTAssertTrue(TrackDuration.extended.isCompatible(with: .acestep))
        XCTAssertTrue(TrackDuration.maximum.isCompatible(with: .acestep))
    }

    func testAvailableDurationsForModel() {
        let acestepDurations = TrackDuration.available(for: .acestep)
        XCTAssertEqual(acestepDurations.count, 5)
        XCTAssertTrue(acestepDurations.contains(.short))
        XCTAssertTrue(acestepDurations.contains(.maximum))
    }

    // MARK: - Model Type Tests

    func testModelTypeProperties() {
        XCTAssertEqual(ModelType.acestep.sizeGB, 5.0)
        XCTAssertEqual(ModelType.acestep.minimumRAM, 8)
    }

    func testModelTypeSizeFormatted() {
        XCTAssertEqual(ModelType.acestep.sizeFormatted, "5.0 GB")
    }

    func testModelTypeMaxDuration() {
        XCTAssertEqual(ModelType.acestep.maxDurationSeconds, 240)
    }

    func testModelTypeSupportsLyrics() {
        XCTAssertTrue(ModelType.acestep.supportsLyrics)
    }

    func testModelTypeAllCases() {
        XCTAssertEqual(ModelType.allCases, [.acestep])
    }

    // MARK: - Quality Mode Tests

    func testQualityModeInferenceSteps() {
        XCTAssertEqual(QualityMode.draft.inferenceSteps, 4)
        XCTAssertEqual(QualityMode.fast.inferenceSteps, 8)    // v1.5 turbo
        XCTAssertEqual(QualityMode.quality.inferenceSteps, 50) // v1.5 base/sft
    }

    func testQualityModeDisplayName() {
        XCTAssertEqual(QualityMode.draft.displayName, "Draft")
        XCTAssertEqual(QualityMode.fast.displayName, "Turbo")
        XCTAssertEqual(QualityMode.quality.displayName, "Quality")
    }

    // MARK: - Genre Preset Tests

    func testGenrePresetsExist() {
        XCTAssertFalse(GenrePreset.allPresets.isEmpty)
        XCTAssertEqual(GenrePreset.allPresets.count, 6)
    }

    func testGenrePresetHasRequiredFields() {
        for preset in GenrePreset.allPresets {
            XCTAssertFalse(preset.id.isEmpty)
            XCTAssertFalse(preset.name.isEmpty)
            XCTAssertFalse(preset.icon.isEmpty)
            XCTAssertFalse(preset.promptSuffix.isEmpty)
        }
    }

    // MARK: - Generation Request Tests

    func testGenerationRequestFullPrompt() {
        // fullPrompt adds a language directive when lyrics imply a specific language.
        let requestWithGenre = GenerationRequest(
            prompt: "chill beats",
            duration: .medium,
            model: .acestep
        )

        XCTAssertEqual(requestWithGenre.fullPrompt, "chill beats")

        let hindiRequest = GenerationRequest(
            prompt: "bollywood romantic ballad",
            duration: .long,
            lyrics: "[verse]\ndil ki baat tu samajh le",
            genre: nil
        )

        XCTAssertTrue(hindiRequest.fullPrompt.contains("Vocal language: Hindi"))
        XCTAssertTrue(hindiRequest.fullPrompt.contains("bollywood romantic ballad"))
    }

    func testGenerationRequestACEStepParams() {
        // ACE-Step request with lyrics
        let acestepRequest = GenerationRequest(
            prompt: "upbeat pop song",
            duration: .extended,
            model: .acestep,
            lyrics: "[verse]\nHello world",
            qualityMode: .quality
        )

        XCTAssertEqual(acestepRequest.effectiveLyrics, "[verse]\nHello world")
        XCTAssertEqual(acestepRequest.qualityMode, .quality)
        XCTAssertEqual(acestepRequest.guidanceScale, 7.0) // v1.5 default

        // Instrumental (no lyrics) returns [inst]
        let instrumentalRequest = GenerationRequest(
            prompt: "ambient soundscape",
            duration: .long
        )
        XCTAssertEqual(instrumentalRequest.effectiveLyrics, "[inst]")
    }

    func testGenerationRequestLanguageHintDetection() {
        let hindiFromPrompt = GenerationRequest(
            prompt: "bollywood track in hindi",
            duration: .medium,
            lyrics: "[verse]\ntera dil mera dil"
        )
        XCTAssertEqual(hindiFromPrompt.languageHint, .hindi)

        let spanishFromMarkers = GenerationRequest(
            prompt: "latin pop track",
            duration: .medium,
            lyrics: "[verse]\ncorazon y sueno en la noche"
        )
        XCTAssertEqual(spanishFromMarkers.languageHint, .spanish)

        let koreanFromPrompt = GenerationRequest(
            prompt: "k-pop dance anthem",
            duration: .medium,
            lyrics: "[verse]\nmodeun geot-i bichna"
        )
        XCTAssertEqual(koreanFromPrompt.languageHint, .korean)

        let multiLanguage = GenerationRequest(
            prompt: "multilingual pop with hindi and english sections",
            duration: .medium,
            lyrics: "[chorus]\nhello dil se bolo"
        )
        XCTAssertEqual(multiLanguage.languageHint, .multilingual)
    }

    func testGenerationRequestLanguageHintSkippedForInstrumentalAndKeepVocals() {
        let instrumental = GenerationRequest(
            prompt: "hindi pop",
            duration: .medium,
            lyrics: nil
        )
        XCTAssertNil(instrumental.languageHint)

        let keepVocalsCover = GenerationRequest(
            prompt: "spanish reggaeton cover",
            duration: .medium,
            lyrics: "",
            taskType: .cover
        )
        XCTAssertNil(keepVocalsCover.languageHint)
        XCTAssertEqual(keepVocalsCover.fullPrompt, "spanish reggaeton cover")
    }

    // MARK: - Track Tests

    func testTrackDisplayTitle() {
        let trackWithTitle = Track(
            id: UUID(),
            prompt: "Test prompt",
            duration: .medium,
            model: .acestep,
            audioURL: URL(fileURLWithPath: "/tmp/test.wav"),
            createdAt: Date(),
            title: "Custom Title"
        )

        XCTAssertEqual(trackWithTitle.displayTitle, "Custom Title")

        let trackWithoutTitle = Track(
            id: UUID(),
            prompt: "This is a longer test prompt for testing",
            duration: .medium,
            model: .acestep,
            audioURL: URL(fileURLWithPath: "/tmp/test.wav"),
            createdAt: Date()
        )

        XCTAssertTrue(trackWithoutTitle.displayTitle.contains("This is a longer"))
    }

    // MARK: - Audio Export Format Tests

    func testAudioExportFormatExtensions() {
        XCTAssertEqual(AudioExportFormat.wav.fileExtension, "wav")
        XCTAssertEqual(AudioExportFormat.m4a.fileExtension, "m4a")
    }

    func testAudioExportFormatMimeTypes() {
        XCTAssertEqual(AudioExportFormat.wav.mimeType, "audio/wav")
        XCTAssertEqual(AudioExportFormat.m4a.mimeType, "audio/mp4")
    }

    // MARK: - Download State Tests

    func testModelDownloadState() {
        XCTAssertFalse(ModelDownloadState.notDownloaded.isDownloaded)
        XCTAssertFalse(ModelDownloadState.notDownloaded.isDownloading)

        XCTAssertFalse(ModelDownloadState.downloading(progress: 0.5).isDownloaded)
        XCTAssertTrue(ModelDownloadState.downloading(progress: 0.5).isDownloading)

        XCTAssertTrue(ModelDownloadState.downloaded.isDownloaded)
        XCTAssertFalse(ModelDownloadState.downloaded.isDownloading)

        XCTAssertFalse(ModelDownloadState.error("test").isDownloaded)
        XCTAssertFalse(ModelDownloadState.error("test").isDownloading)
    }
}
#endif
