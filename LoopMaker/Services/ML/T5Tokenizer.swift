import Foundation

/// Tokenizer for T5 text encoder
public final class T5Tokenizer: @unchecked Sendable {
    public let vocab: [String: Int]
    public let reverseVocab: [Int: String]
    public let merges: [(String, String)]

    public let padToken = "<pad>"
    public let eosToken = "</s>"
    public let unkToken = "<unk>"

    public var padTokenId: Int { vocab[padToken] ?? 0 }
    public var eosTokenId: Int { vocab[eosToken] ?? 1 }
    public var unkTokenId: Int { vocab[unkToken] ?? 2 }

    public init(vocab: [String: Int], merges: [(String, String)] = []) {
        self.vocab = vocab
        self.reverseVocab = Dictionary(uniqueKeysWithValues: vocab.map { ($1, $0) })
        self.merges = merges
    }

    /// Encode text to token IDs
    public func encode(_ text: String, addSpecialTokens: Bool = true) -> [Int] {
        // Simple whitespace tokenization with SentencePiece-style underscore prefix
        let normalized = text.lowercased().trimmingCharacters(in: .whitespacesAndNewlines)
        let words = normalized.split(separator: " ")

        var tokens: [Int] = []

        for (index, word) in words.enumerated() {
            let prefix = index == 0 ? "" : "▁"
            let tokenStr = prefix + String(word)

            if let tokenId = vocab[tokenStr] {
                tokens.append(tokenId)
            } else if let tokenId = vocab["▁" + String(word)] {
                tokens.append(tokenId)
            } else {
                // Fall back to character-level or UNK
                tokens.append(unkTokenId)
            }
        }

        if addSpecialTokens {
            tokens.append(eosTokenId)
        }

        return tokens
    }

    /// Decode token IDs back to text
    public func decode(_ tokens: [Int]) -> String {
        var result = ""
        for tokenId in tokens {
            if tokenId == padTokenId || tokenId == eosTokenId {
                continue
            }
            if let token = reverseVocab[tokenId] {
                let cleaned = token.replacingOccurrences(of: "▁", with: " ")
                result += cleaned
            }
        }
        return result.trimmingCharacters(in: .whitespaces)
    }

    /// Load tokenizer from files
    public static func load(from directory: URL) throws -> T5Tokenizer {
        let vocabURL = directory.appendingPathComponent("spiece.model")

        // For now, return a minimal tokenizer
        // In production, this would parse the SentencePiece model
        var vocab: [String: Int] = [
            "<pad>": 0,
            "</s>": 1,
            "<unk>": 2
        ]

        // Add some common tokens
        let commonTokens = ["▁a", "▁the", "▁music", "▁beat", "▁lo", "▁fi", "▁chill"]
        for (i, token) in commonTokens.enumerated() {
            vocab[token] = 3 + i
        }

        return T5Tokenizer(vocab: vocab)
    }
}
