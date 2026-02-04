import Foundation
import MLX

/// Key-Value cache for transformer attention
public final class KVCache: @unchecked Sendable {
    public private(set) var keys: MLXArray?
    public private(set) var values: MLXArray?

    public init() {}

    /// Current sequence length in cache
    public var sequenceLength: Int {
        keys?.dim(2) ?? 0
    }

    /// Update cache with new keys and values
    /// Returns concatenated keys and values
    @discardableResult
    public func update(newKeys: MLXArray, newValues: MLXArray) -> (MLXArray, MLXArray) {
        if let existingKeys = keys, let existingValues = values {
            // Concatenate along sequence dimension (dim 2)
            keys = MLX.concatenated([existingKeys, newKeys], axis: 2)
            values = MLX.concatenated([existingValues, newValues], axis: 2)
        } else {
            keys = newKeys
            values = newValues
        }
        return (keys!, values!)
    }

    /// Reset cache
    public func reset() {
        keys = nil
        values = nil
    }
}

/// Cache for all layers in a transformer
public final class LayerCache: @unchecked Sendable {
    public let layers: [KVCache]

    public init(numLayers: Int) {
        self.layers = (0..<numLayers).map { _ in KVCache() }
    }

    public subscript(index: Int) -> KVCache {
        layers[index]
    }

    public func reset() {
        layers.forEach { $0.reset() }
    }
}
