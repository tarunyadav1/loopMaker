import Foundation

/// Manages the delay pattern for multi-codebook generation
/// MusicGen uses a delay pattern where each codebook is offset by one step
public final class DelayPatternScheduler: @unchecked Sendable {
    public let numCodebooks: Int
    public let padTokenId: Int

    public init(numCodebooks: Int = 4, padTokenId: Int = 2048) {
        self.numCodebooks = numCodebooks
        self.padTokenId = padTokenId
    }

    /// Get token indices for each codebook at a given step
    /// Returns nil for codebooks that haven't started yet
    public func getTokenIndices(for step: Int) -> [Int?] {
        var indices: [Int?] = []
        for codebook in 0..<numCodebooks {
            let index = step - codebook
            if index >= 0 {
                indices.append(index)
            } else {
                indices.append(nil)
            }
        }
        return indices
    }

    /// Check if generation is complete for target length
    public func isComplete(currentStep: Int, targetLength: Int) -> Bool {
        // Last codebook starts at step (numCodebooks - 1)
        // Complete when last codebook has generated targetLength tokens
        let lastCodebookStart = numCodebooks - 1
        let lastCodebookTokens = currentStep - lastCodebookStart
        return lastCodebookTokens >= targetLength
    }

    /// Get the step at which generation should end for a target length
    public func totalStepsNeeded(for targetLength: Int) -> Int {
        // Need to generate targetLength tokens for last codebook
        // which starts at offset (numCodebooks - 1)
        return targetLength + numCodebooks - 1
    }

    /// Reorder generated tokens back to parallel alignment
    public func reorderTokens(_ tokens: [[Int]]) -> [[Int]] {
        guard !tokens.isEmpty else { return [] }

        // Remove delay by shifting each codebook
        var reordered: [[Int]] = Array(repeating: [], count: numCodebooks)
        _ = tokens.map { $0.count }.max() ?? 0

        for codebook in 0..<numCodebooks {
            let offset = codebook
            let startIdx = offset
            if startIdx < tokens[codebook].count {
                reordered[codebook] = Array(tokens[codebook][startIdx...])
            }
        }

        return reordered
    }
}
