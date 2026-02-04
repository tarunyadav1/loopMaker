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
        // MusicGen models (small/medium) support up to 60s
        XCTAssertTrue(TrackDuration.short.isCompatible(with: .small))
        XCTAssertTrue(TrackDuration.medium.isCompatible(with: .small))
        XCTAssertTrue(TrackDuration.long.isCompatible(with: .small))
        XCTAssertFalse(TrackDuration.extended.isCompatible(with: .small))
        XCTAssertFalse(TrackDuration.maximum.isCompatible(with: .small))

        // ACE-Step supports up to 240s
        XCTAssertTrue(TrackDuration.short.isCompatible(with: .acestep))
        XCTAssertTrue(TrackDuration.extended.isCompatible(with: .acestep))
        XCTAssertTrue(TrackDuration.maximum.isCompatible(with: .acestep))
    }

    func testAvailableDurationsForModel() {
        let smallDurations = TrackDuration.available(for: .small)
        XCTAssertEqual(smallDurations.count, 3)
        XCTAssertTrue(smallDurations.contains(.short))
        XCTAssertFalse(smallDurations.contains(.extended))

        let acestepDurations = TrackDuration.available(for: .acestep)
        XCTAssertEqual(acestepDurations.count, 5)
        XCTAssertTrue(acestepDurations.contains(.maximum))
    }

    // MARK: - Model Type Tests

    func testModelTypeProperties() {
        XCTAssertEqual(ModelType.small.sizeGB, 1.2)
        XCTAssertEqual(ModelType.medium.sizeGB, 6.0)
        XCTAssertEqual(ModelType.acestep.sizeGB, 7.0)

        XCTAssertEqual(ModelType.small.minimumRAM, 8)
        XCTAssertEqual(ModelType.medium.minimumRAM, 16)
        XCTAssertEqual(ModelType.acestep.minimumRAM, 16)
    }

    func testModelTypeSizeFormatted() {
        XCTAssertEqual(ModelType.small.sizeFormatted, "1.2 GB")
        XCTAssertEqual(ModelType.medium.sizeFormatted, "6.0 GB")
        XCTAssertEqual(ModelType.acestep.sizeFormatted, "7.0 GB")
    }

    func testModelTypeFamily() {
        XCTAssertEqual(ModelType.small.family, .musicgen)
        XCTAssertEqual(ModelType.medium.family, .musicgen)
        XCTAssertEqual(ModelType.acestep.family, .acestep)
    }

    func testModelTypeMaxDuration() {
        XCTAssertEqual(ModelType.small.maxDurationSeconds, 60)
        XCTAssertEqual(ModelType.medium.maxDurationSeconds, 60)
        XCTAssertEqual(ModelType.acestep.maxDurationSeconds, 240)
    }

    func testModelTypeSupportsLyrics() {
        XCTAssertFalse(ModelType.small.supportsLyrics)
        XCTAssertFalse(ModelType.medium.supportsLyrics)
        XCTAssertTrue(ModelType.acestep.supportsLyrics)
    }

    // MARK: - Quality Mode Tests

    func testQualityModeInferenceSteps() {
        XCTAssertEqual(QualityMode.fast.inferenceSteps, 27)
        XCTAssertEqual(QualityMode.quality.inferenceSteps, 60)
    }

    func testQualityModeDisplayName() {
        XCTAssertEqual(QualityMode.fast.displayName, "Fast")
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
        let lofiPreset = GenrePreset.allPresets.first { $0.id == "lofi" }!

        let requestWithGenre = GenerationRequest(
            prompt: "chill beats",
            duration: .medium,
            model: .small,
            genre: lofiPreset
        )

        XCTAssertTrue(requestWithGenre.fullPrompt.contains("chill beats"))
        XCTAssertTrue(requestWithGenre.fullPrompt.contains(lofiPreset.promptSuffix))

        let requestWithoutGenre = GenerationRequest(
            prompt: "epic music",
            duration: .long,
            model: .medium,
            genre: nil
        )

        XCTAssertEqual(requestWithoutGenre.fullPrompt, "epic music")
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
        XCTAssertEqual(acestepRequest.guidanceScale, 15.0) // default

        // ACE-Step instrumental (no lyrics)
        let instrumentalRequest = GenerationRequest(
            prompt: "ambient soundscape",
            duration: .long,
            model: .acestep
        )
        XCTAssertEqual(instrumentalRequest.effectiveLyrics, "[inst]")

        // MusicGen request should have nil effectiveLyrics
        let musicgenRequest = GenerationRequest(
            prompt: "jazz",
            duration: .medium,
            model: .small
        )
        XCTAssertNil(musicgenRequest.effectiveLyrics)
    }

    // MARK: - Track Tests

    func testTrackDisplayTitle() {
        let trackWithTitle = Track(
            id: UUID(),
            prompt: "Test prompt",
            duration: .medium,
            model: .small,
            audioURL: URL(fileURLWithPath: "/tmp/test.wav"),
            createdAt: Date(),
            title: "Custom Title"
        )

        XCTAssertEqual(trackWithTitle.displayTitle, "Custom Title")

        let trackWithoutTitle = Track(
            id: UUID(),
            prompt: "This is a longer test prompt for testing",
            duration: .medium,
            model: .small,
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
