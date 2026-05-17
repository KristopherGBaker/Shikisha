import Foundation

/// Counts approximate tokens in a string. Used by `trimMessages`, token-buffer memory,
/// and the rate limiter to budget without round-tripping to a tokenizer.
public protocol TokenCounter: Sendable {
    func countTokens(_ text: String) -> Int
    func countTokens(in messages: [any Message]) -> Int
}

public extension TokenCounter {
    func countTokens(in messages: [any Message]) -> Int {
        messages.reduce(0) { $0 + countTokens($1.content) + 4 }  // role/separator overhead
    }
}

/// Cheap heuristic: 1 token ≈ 4 characters. Good enough for trimming windows and
/// rate-limit accounting; do not rely on it for exact billing.
public struct ApproximateTokenCounter: TokenCounter, Sendable {
    public let charactersPerToken: Double

    public init(charactersPerToken: Double = 4.0) {
        self.charactersPerToken = charactersPerToken
    }

    public func countTokens(_ text: String) -> Int {
        max(0, Int((Double(text.count) / charactersPerToken).rounded(.up)))
    }
}
