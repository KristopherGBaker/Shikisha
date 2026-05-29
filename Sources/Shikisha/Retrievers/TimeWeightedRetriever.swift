import Foundation

/// Boost recently-accessed documents. Score = `similarity + (1 - decayRate)^hoursSinceAccess`.
/// Tracks per-document last-access time on every retrieve.
public actor TimeWeightedRetriever: Retriever {
    public let store: any VectorStore
    public let topK: Int
    public let decayRate: Double
    public let now: @Sendable () -> Date

    private var lastAccess: [String: Date] = [:]

    public init(
        store: any VectorStore,
        topK: Int = 4,
        decayRate: Double = 0.01,
        now: @Sendable @escaping () -> Date = Date.init
    ) {
        self.store = store
        self.topK = topK
        self.decayRate = decayRate
        self.now = now
    }

    public func retrieve(_ query: String) async throws -> [Document] {
        let results = try await store.similaritySearch(query: query, topK: topK * 4, filter: nil)
        let currentTime = now()
        let scored = results.map { result -> (Document, Double) in
            let id = result.document.id ?? result.document.pageContent
            let lastSeen = lastAccess[id] ?? currentTime
            let hours = max(0, currentTime.timeIntervalSince(lastSeen) / 3600.0)
            let recency = pow(1 - decayRate, hours)
            return (result.document, Double(result.score) + recency)
        }
        let top = scored.sorted { $0.1 > $1.1 }.prefix(topK).map(\.0)
        for document in top {
            let id = document.id ?? document.pageContent
            lastAccess[id] = currentTime
        }
        return top
    }
}
