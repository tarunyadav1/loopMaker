import Foundation

/// Configuration for EnCodec audio tokenizer
public struct EnCodecConfig: Sendable {
    public let channels: Int
    public let codebookSize: Int
    public let numCodebooks: Int
    public let sampleRate: Int
    public let frameRate: Int
    public let encoderDim: Int
    public let encoderRatios: [Int]
    public let decoderDim: Int
    public let decoderRatios: [Int]
    public let bandwidth: Float

    /// Computed upsample ratio from decoder ratios
    public var upsampleRatio: Int {
        decoderRatios.reduce(1, *)
    }

    public init(
        channels: Int = 1,
        codebookSize: Int = 2048,
        numCodebooks: Int = 4,
        sampleRate: Int = 32000,
        frameRate: Int = 50,
        encoderDim: Int = 64,
        encoderRatios: [Int] = [8, 5, 4, 2],
        decoderDim: Int = 64,
        decoderRatios: [Int] = [8, 5, 4, 2],
        bandwidth: Float = 6.0
    ) {
        self.channels = channels
        self.codebookSize = codebookSize
        self.numCodebooks = numCodebooks
        self.sampleRate = sampleRate
        self.frameRate = frameRate
        self.encoderDim = encoderDim
        self.encoderRatios = encoderRatios
        self.decoderDim = decoderDim
        self.decoderRatios = decoderRatios
        self.bandwidth = bandwidth
    }

    /// Default EnCodec configuration for MusicGen
    public static let `default` = EnCodecConfig(
        channels: 1,
        codebookSize: 2048,
        numCodebooks: 4,
        sampleRate: 32000,
        frameRate: 50,
        encoderDim: 64,
        encoderRatios: [8, 5, 4, 2],
        decoderDim: 64,
        decoderRatios: [8, 5, 4, 2]
    )
}
