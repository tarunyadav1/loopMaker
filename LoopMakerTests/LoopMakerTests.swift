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
        XCTAssertEqual(TrackDuration.long.displayName, "60 sec")
    }

    // MARK: - Model Type Tests

    func testModelTypeProperties() {
        XCTAssertEqual(ModelType.small.sizeGB, 1.2)
        XCTAssertEqual(ModelType.medium.sizeGB, 6.0)

        XCTAssertEqual(ModelType.small.minimumRAM, 8)
        XCTAssertEqual(ModelType.medium.minimumRAM, 16)
    }

    func testModelTypeSizeFormatted() {
        XCTAssertEqual(ModelType.small.sizeFormatted, "1.2 GB")
        XCTAssertEqual(ModelType.medium.sizeFormatted, "6.0 GB")
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

    // MARK: - System Requirements Tests

    func testSystemRequirementCheck() {
        let passCheck = SystemRequirementCheck(
            availableRAM: 32,
            requiredRAM: 16,
            recommendedRAM: 32,
            meetsMinimum: true,
            meetsRecommended: true
        )

        XCTAssertNil(passCheck.warningMessage)

        let warningCheck = SystemRequirementCheck(
            availableRAM: 16,
            requiredRAM: 16,
            recommendedRAM: 32,
            meetsMinimum: true,
            meetsRecommended: false
        )

        XCTAssertNotNil(warningCheck.warningMessage)
        XCTAssertTrue(warningCheck.warningMessage!.contains("32GB is recommended"))

        let failCheck = SystemRequirementCheck(
            availableRAM: 8,
            requiredRAM: 16,
            recommendedRAM: 32,
            meetsMinimum: false,
            meetsRecommended: false
        )

        XCTAssertNotNil(failCheck.warningMessage)
        XCTAssertTrue(failCheck.warningMessage!.contains("requires at least"))
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
