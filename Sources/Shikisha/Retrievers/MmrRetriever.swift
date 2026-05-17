import Foundation

/// Maximal Marginal Relevance — picks `k` documents that balance similarity to the query with
/// diversity from each other. Higher `lambda` (toward 1) favors relevance; lower (toward 0)
/// favors diversity.
public struct MmrRetriever: Retriever {
    public let store: InMemoryVectorStore
    public let k: Int
    public let fetchK: Int
    public let lambda: Double

    public init(store: InMemoryVectorStore, k: Int = 4, fetchK: Int = 20, lambda: Double = 0.5) {
        precondition(k > 0, "k must be > 0")
        precondition(fetchK >= k, "fetchK must be >= k")
        precondition(lambda >= 0 && lambda <= 1, "lambda must be in [0, 1]")
        self.store = store
        self.k = k
        self.fetchK = fetchK
        self.lambda = lambda
    }

    public func retrieve(_ query: String) async throws -> [Document] {
        let queryVector = try await store.embeddings.embedQuery(query)
        let initial = await store.similaritySearchByVector(queryVector, k: fetchK)
        guard !initial.isEmpty else { return [] }
        let entries = await store.allEntries()
        let lookup = Dictionary(uniqueKeysWithValues: entries.map { ($0.id, $0.vector) })

        var selected: [(Document, [Float])] = []
        var candidates = initial.compactMap { result -> (Document, [Float])? in
            guard let id = result.document.id, let vector = lookup[id] else { return nil }
            return (result.document, vector)
        }
        let scaledLambda = Float(lambda)

        while selected.count < k, !candidates.isEmpty {
            var bestIndex = 0
            var bestScore: Float = -.infinity
            for (index, candidate) in candidates.enumerated() {
                let relevance = cosineSimilarity(queryVector, candidate.1)
                let diversity = selected
                    .map { cosineSimilarity($0.1, candidate.1) }
                    .max() ?? 0
                let score = scaledLambda * relevance - (1 - scaledLambda) * diversity
                if score > bestScore {
                    bestScore = score
                    bestIndex = index
                }
            }
            selected.append(candidates.remove(at: bestIndex))
        }
        return selected.map(\.0)
    }
}
