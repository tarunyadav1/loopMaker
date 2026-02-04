import Foundation

/// Configuration for T5 text encoder
public struct T5Config: Sendable {
    public let vocabSize: Int
    public let dModel: Int
    public let dKV: Int
    public let dFF: Int
    public let numLayers: Int
    public let numHeads: Int
    public let relativeAttentionNumBuckets: Int
    public let relativeAttentionMaxDistance: Int
    public let dropoutRate: Float
    public let layerNormEps: Float
    public let isEncoderDecoder: Bool
    public let isGatedAct: Bool
    public let denseActFn: String

    public init(
        vocabSize: Int = 32128,
        dModel: Int = 768,
        dKV: Int = 64,
        dFF: Int = 2048,
        numLayers: Int = 12,
        numHeads: Int = 12,
        relativeAttentionNumBuckets: Int = 32,
        relativeAttentionMaxDistance: Int = 128,
        dropoutRate: Float = 0.1,
        layerNormEps: Float = 1e-6,
        isEncoderDecoder: Bool = false,
        isGatedAct: Bool = false,
        denseActFn: String = "gelu_new"
    ) {
        self.vocabSize = vocabSize
        self.dModel = dModel
        self.dKV = dKV
        self.dFF = dFF
        self.numLayers = numLayers
        self.numHeads = numHeads
        self.relativeAttentionNumBuckets = relativeAttentionNumBuckets
        self.relativeAttentionMaxDistance = relativeAttentionMaxDistance
        self.dropoutRate = dropoutRate
        self.layerNormEps = layerNormEps
        self.isEncoderDecoder = isEncoderDecoder
        self.isGatedAct = isGatedAct
        self.denseActFn = denseActFn
    }

    /// Small T5 configuration for MusicGen
    public static let small = T5Config(
        vocabSize: 32128,
        dModel: 768,
        dKV: 64,
        dFF: 2048,
        numLayers: 12,
        numHeads: 12
    )
}
