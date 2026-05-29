import Foundation

/// Pick a subset of examples to include in a few-shot prompt. Implementations range from
/// "always pick the same topK" (`FixedExampleSelector`) to "embed query, pick topK nearest"
/// (`SemanticSimilarityExampleSelector`).
public protocol ExampleSelector: Sendable {
    associatedtype Example: Sendable
    func select(for input: [String: any Sendable], examples: [Example]) async throws -> [Example]
}

/// Always return the first `topK` examples. Useful when example order matters more than relevance.
public struct FixedExampleSelector<Example: Sendable>: ExampleSelector {
    public let topK: Int

    public init(topK: Int) {
        precondition(topK > 0, "topK must be > 0")
        self.topK = topK
    }

    public func select(for _: [String: any Sendable], examples: [Example]) async throws -> [Example] {
        Array(examples.prefix(topK))
    }
}

/// Rank examples by cosine similarity between the query embedding and each example's embedding,
/// then return the top `topK`. The example value type is opaque — provide a `keyExtractor` that
/// returns the text to embed.
public struct SemanticSimilarityExampleSelector<Example: Sendable>: ExampleSelector {
    public let topK: Int
    public let embeddings: any Embeddings
    public let queryKey: String
    public let keyExtractor: @Sendable (Example) -> String

    public init(
        topK: Int,
        embeddings: any Embeddings,
        queryKey: String,
        keyExtractor: @Sendable @escaping (Example) -> String
    ) {
        precondition(topK > 0, "topK must be > 0")
        self.topK = topK
        self.embeddings = embeddings
        self.queryKey = queryKey
        self.keyExtractor = keyExtractor
    }

    public func select(for input: [String: any Sendable], examples: [Example]) async throws -> [Example] {
        guard let queryAny = input[queryKey] else {
            throw MissingPromptVariableError(variable: queryKey)
        }
        let query = "\(queryAny)"

        let exampleTexts = examples.map(keyExtractor)
        let vectors = try await embeddings.embedDocuments(exampleTexts + [query])
        guard let queryVector = vectors.last else { return Array(examples.prefix(topK)) }
        let exampleVectors = vectors.dropLast()

        let scored = zip(examples, exampleVectors)
            .map { (example: $0, score: cosineSimilarity($1, queryVector)) }
            .sorted { $0.score > $1.score }
        return Array(scored.prefix(topK).map(\.example))
    }
}

func cosineSimilarity(_ lhs: [Float], _ rhs: [Float]) -> Float {
    guard !lhs.isEmpty, lhs.count == rhs.count else { return 0 }
    var dot: Float = 0
    var leftSquaredNorm: Float = 0
    var rightSquaredNorm: Float = 0
    for index in 0..<lhs.count {
        dot += lhs[index] * rhs[index]
        leftSquaredNorm += lhs[index] * lhs[index]
        rightSquaredNorm += rhs[index] * rhs[index]
    }
    let denominator = (leftSquaredNorm.squareRoot()) * (rightSquaredNorm.squareRoot())
    return denominator == 0 ? 0 : dot / denominator
}
