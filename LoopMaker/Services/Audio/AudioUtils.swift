import Foundation
import AVFoundation

/// Audio processing utilities
public enum AudioUtils {
    /// Create WAV file data from audio samples
    public static func createWAVData(samples: [Float], sampleRate: Int, channels: Int = 1, bitDepth: Int = 16) -> Data {
        var data = Data()

        let bytesPerSample = bitDepth / 8
        let dataSize = samples.count * bytesPerSample
        let fileSize = 36 + dataSize

        // RIFF header
        data.append(contentsOf: "RIFF".utf8)
        data.append(contentsOf: withUnsafeBytes(of: UInt32(fileSize).littleEndian) { Array($0) })
        data.append(contentsOf: "WAVE".utf8)

        // fmt chunk
        data.append(contentsOf: "fmt ".utf8)
        data.append(contentsOf: withUnsafeBytes(of: UInt32(16).littleEndian) { Array($0) }) // chunk size
        data.append(contentsOf: withUnsafeBytes(of: UInt16(1).littleEndian) { Array($0) }) // PCM format
        data.append(contentsOf: withUnsafeBytes(of: UInt16(channels).littleEndian) { Array($0) })
        data.append(contentsOf: withUnsafeBytes(of: UInt32(sampleRate).littleEndian) { Array($0) })

        let byteRate = sampleRate * channels * bytesPerSample
        data.append(contentsOf: withUnsafeBytes(of: UInt32(byteRate).littleEndian) { Array($0) })

        let blockAlign = channels * bytesPerSample
        data.append(contentsOf: withUnsafeBytes(of: UInt16(blockAlign).littleEndian) { Array($0) })
        data.append(contentsOf: withUnsafeBytes(of: UInt16(bitDepth).littleEndian) { Array($0) })

        // data chunk
        data.append(contentsOf: "data".utf8)
        data.append(contentsOf: withUnsafeBytes(of: UInt32(dataSize).littleEndian) { Array($0) })

        // Convert float samples to int16
        for sample in samples {
            let clamped = max(-1.0, min(1.0, sample))
            let intSample = Int16(clamped * Float(Int16.max))
            data.append(contentsOf: withUnsafeBytes(of: intSample.littleEndian) { Array($0) })
        }

        return data
    }

    /// Normalize audio samples to target peak level
    public static func normalize(samples: [Float], targetPeak: Float = 0.95) -> [Float] {
        guard !samples.isEmpty else { return samples }

        let maxAbs = samples.map { abs($0) }.max() ?? 1.0
        guard maxAbs > 0 else { return samples }

        let scale = targetPeak / maxAbs
        return samples.map { $0 * scale }
    }

    /// Apply fade in and fade out to samples
    public static func applyFades(samples: [Float], fadeInSamples: Int, fadeOutSamples: Int) -> [Float] {
        guard !samples.isEmpty else { return samples }

        var result = samples

        // Fade in
        let fadeInCount = min(fadeInSamples, samples.count)
        for i in 0..<fadeInCount {
            let factor = Float(i) / Float(fadeInCount)
            result[i] *= factor
        }

        // Fade out
        let fadeOutCount = min(fadeOutSamples, samples.count)
        let fadeOutStart = samples.count - fadeOutCount
        for i in 0..<fadeOutCount {
            let factor = Float(fadeOutCount - i) / Float(fadeOutCount)
            result[fadeOutStart + i] *= factor
        }

        return result
    }

    /// Convert stereo to mono by averaging channels
    public static func stereoToMono(_ samples: [Float]) -> [Float] {
        guard samples.count >= 2 else { return samples }

        var mono: [Float] = []
        mono.reserveCapacity(samples.count / 2)

        for i in stride(from: 0, to: samples.count - 1, by: 2) {
            let avg = (samples[i] + samples[i + 1]) / 2.0
            mono.append(avg)
        }

        return mono
    }

    /// Resample audio to target sample rate (simple linear interpolation)
    public static func resample(_ samples: [Float], from sourceSampleRate: Int, to targetSampleRate: Int) -> [Float] {
        guard sourceSampleRate != targetSampleRate, !samples.isEmpty else { return samples }

        let ratio = Double(targetSampleRate) / Double(sourceSampleRate)
        let newCount = Int(Double(samples.count) * ratio)

        var resampled: [Float] = []
        resampled.reserveCapacity(newCount)

        for i in 0..<newCount {
            let sourceIndex = Double(i) / ratio
            let index0 = Int(sourceIndex)
            let index1 = min(index0 + 1, samples.count - 1)
            let fraction = Float(sourceIndex - Double(index0))

            let interpolated = samples[index0] * (1 - fraction) + samples[index1] * fraction
            resampled.append(interpolated)
        }

        return resampled
    }
}
