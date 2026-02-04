import XCTest
@testable import LoopMaker
import MLX
import MLXNN

/// Tests for MusicGen model components
final class MusicGenTests: XCTestCase {

    // MARK: - Configuration Tests

    func testDecoderConfigSmall() {
        let config = DecoderConfig.small

        XCTAssertEqual(config.hiddenSize, 1024)
        XCTAssertEqual(config.numLayers, 24)
        XCTAssertEqual(config.numHeads, 16)
        XCTAssertEqual(config.headDim, 64) // 1024 / 16
        XCTAssertEqual(config.vocabSize, 2048)
        XCTAssertEqual(config.numCodebooks, 4)
    }

    func testDecoderConfigMedium() {
        let config = DecoderConfig.medium

        XCTAssertEqual(config.hiddenSize, 1536)
        XCTAssertEqual(config.numLayers, 48)
        XCTAssertEqual(config.numHeads, 24)
        XCTAssertEqual(config.headDim, 64) // 1536 / 24
    }

    func testT5Config() {
        let config = T5Config.small

        XCTAssertEqual(config.vocabSize, 32128)
        XCTAssertEqual(config.dModel, 768)
        XCTAssertEqual(config.dKV, 64)
        XCTAssertEqual(config.numLayers, 12)
        XCTAssertEqual(config.numHeads, 12)
    }

    func testEnCodecConfig() {
        let config = EnCodecConfig.default

        XCTAssertEqual(config.channels, 1)
        XCTAssertEqual(config.codebookSize, 2048)
        XCTAssertEqual(config.numCodebooks, 4)
        XCTAssertEqual(config.sampleRate, 32000)
        XCTAssertEqual(config.upsampleRatio, 320) // 8 * 5 * 4 * 2
    }

    // MARK: - Delay Pattern Tests

    func testDelayPatternScheduler() {
        let scheduler = DelayPatternScheduler(numCodebooks: 4, padTokenId: 2048)

        // Test initial steps
        let indices0 = scheduler.getTokenIndices(for: 0)
        XCTAssertEqual(indices0, [0, nil, nil, nil])

        let indices1 = scheduler.getTokenIndices(for: 1)
        XCTAssertEqual(indices1, [1, 0, nil, nil])

        let indices3 = scheduler.getTokenIndices(for: 3)
        XCTAssertEqual(indices3, [3, 2, 1, 0])

        let indices5 = scheduler.getTokenIndices(for: 5)
        XCTAssertEqual(indices5, [5, 4, 3, 2])
    }

    func testDelayPatternCompletion() {
        let scheduler = DelayPatternScheduler(numCodebooks: 4)

        // With target length 10, need steps until last codebook has 10 tokens
        // Last codebook starts at step 3, so complete at step 12
        XCTAssertFalse(scheduler.isComplete(currentStep: 10, targetLength: 10))
        XCTAssertFalse(scheduler.isComplete(currentStep: 12, targetLength: 10))
        XCTAssertTrue(scheduler.isComplete(currentStep: 13, targetLength: 10))
    }

    // MARK: - Audio Utils Tests

    func testWAVCreation() {
        // Create simple sine wave
        let sampleRate = 32000
        let frequency = 440.0 // A4 note
        let duration = 0.1 // 100ms

        var samples = [Float]()
        for i in 0..<Int(Double(sampleRate) * duration) {
            let t = Double(i) / Double(sampleRate)
            let sample = Float(sin(2.0 * .pi * frequency * t))
            samples.append(sample)
        }

        let wavData = AudioUtils.createWAVData(samples: samples, sampleRate: sampleRate)

        // Check WAV header
        XCTAssertGreaterThan(wavData.count, 44) // At least header size

        // Check RIFF header
        let riff = String(data: wavData.prefix(4), encoding: .ascii)
        XCTAssertEqual(riff, "RIFF")

        // Check WAVE format
        let wave = String(data: wavData[8..<12], encoding: .ascii)
        XCTAssertEqual(wave, "WAVE")
    }

    func testAudioNormalization() {
        let samples: [Float] = [0.5, -0.5, 0.2, -0.2]
        let normalized = AudioUtils.normalize(samples: samples, targetPeak: 0.95)

        // Check that max value is near target
        let maxAbs = normalized.map { abs($0) }.max()!
        XCTAssertEqual(maxAbs, 0.95, accuracy: 0.001)
    }

    func testAudioFades() {
        let samples = [Float](repeating: 1.0, count: 100)
        let faded = AudioUtils.applyFades(samples: samples, fadeInSamples: 10, fadeOutSamples: 10)

        // Check fade in
        XCTAssertEqual(faded[0], 0.0, accuracy: 0.001)
        XCTAssertLessThan(faded[5], 1.0)

        // Check middle (no fade)
        XCTAssertEqual(faded[50], 1.0, accuracy: 0.001)

        // Check fade out
        XCTAssertEqual(faded[99], 0.1, accuracy: 0.001)
    }

    // MARK: - Tokenizer Tests

    func testBasicTokenization() throws {
        // Create basic tokenizer with minimal vocab
        var vocab = [String: Int]()
        vocab["<pad>"] = 0
        vocab["</s>"] = 1
        vocab["<unk>"] = 2
        vocab["▁a"] = 3
        vocab["▁test"] = 4

        let tokenizer = T5Tokenizer(vocab: vocab, merges: [])

        let tokens = tokenizer.encode("a test")

        // Should have tokens + EOS
        XCTAssertTrue(tokens.contains(1)) // EOS token
    }

    // MARK: - KV Cache Tests

    func testKVCacheUpdate() {
        let cache = KVCache()
        XCTAssertEqual(cache.sequenceLength, 0)

        // First update
        let keys1 = MLXArray.zeros([1, 4, 5, 64]) // [batch, heads, seq, dim]
        let values1 = MLXArray.zeros([1, 4, 5, 64])
        let (k1, v1) = cache.update(newKeys: keys1, newValues: values1)

        XCTAssertEqual(cache.sequenceLength, 5)
        XCTAssertEqual(k1.shape, [1, 4, 5, 64])

        // Second update
        let keys2 = MLXArray.zeros([1, 4, 3, 64])
        let values2 = MLXArray.zeros([1, 4, 3, 64])
        let (k2, _) = cache.update(newKeys: keys2, newValues: values2)

        XCTAssertEqual(cache.sequenceLength, 8)
        XCTAssertEqual(k2.shape, [1, 4, 8, 64])
    }

    func testKVCacheReset() {
        let cache = KVCache()

        // Add some data
        let keys = MLXArray.zeros([1, 4, 5, 64])
        let values = MLXArray.zeros([1, 4, 5, 64])
        _ = cache.update(newKeys: keys, newValues: values)

        XCTAssertEqual(cache.sequenceLength, 5)

        // Reset
        cache.reset()
        XCTAssertEqual(cache.sequenceLength, 0)
        XCTAssertNil(cache.keys)
        XCTAssertNil(cache.values)
    }
}
