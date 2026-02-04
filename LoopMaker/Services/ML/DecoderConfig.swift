import Foundation

/// Configuration for MusicGen decoder transformer
public struct DecoderConfig: Sendable {
    public let hiddenSize: Int
    public let numLayers: Int
    public let numHeads: Int
    public let vocabSize: Int
    public let numCodebooks: Int
    public let maxPositionEmbeddings: Int
    public let intermediateSize: Int
    public let activationFunction: String
    public let layerNormEps: Float

    /// Head dimension computed from hidden size and num heads
    public var headDim: Int {
        hiddenSize / numHeads
    }

    public init(
        hiddenSize: Int,
        numLayers: Int,
        numHeads: Int,
        vocabSize: Int = 2048,
        numCodebooks: Int = 4,
        maxPositionEmbeddings: Int = 2048,
        intermediateSize: Int? = nil,
        activationFunction: String = "gelu",
        layerNormEps: Float = 1e-5
    ) {
        self.hiddenSize = hiddenSize
        self.numLayers = numLayers
        self.numHeads = numHeads
        self.vocabSize = vocabSize
        self.numCodebooks = numCodebooks
        self.maxPositionEmbeddings = maxPositionEmbeddings
        self.intermediateSize = intermediateSize ?? (hiddenSize * 4)
        self.activationFunction = activationFunction
        self.layerNormEps = layerNormEps
    }

    /// Small model configuration (300M parameters)
    public static let small = DecoderConfig(
        hiddenSize: 1024,
        numLayers: 24,
        numHeads: 16,
        vocabSize: 2048,
        numCodebooks: 4
    )

    /// Medium model configuration (1.5B parameters)
    public static let medium = DecoderConfig(
        hiddenSize: 1536,
        numLayers: 48,
        numHeads: 24,
        vocabSize: 2048,
        numCodebooks: 4
    )
}
