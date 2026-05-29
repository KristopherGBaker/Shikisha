import Foundation

/// Plug any `VectorStore` into the `Retriever` protocol. Strips scores; callers that need them
/// should hit the store directly.
public struct VectorStoreRetriever: Retriever {
    public let store: any VectorStore
    public let topK: Int
    public let filter: MetadataFilter?

    public init(store: any VectorStore, topK: Int = 4, filter: MetadataFilter? = nil) {
        self.store = store
        self.topK = topK
        self.filter = filter
    }

    public func retrieve(_ query: String) async throws -> [Document] {
        let results = try await store.similaritySearch(query: query, topK: topK, filter: filter)
        return results.map(\.document)
    }
}

public extension VectorStore {
    /// Lift this store into a `Retriever`. Shorthand for `VectorStoreRetriever(store: self, ...)`.
    func asRetriever(topK: Int = 4, filter: MetadataFilter? = nil) -> VectorStoreRetriever {
        VectorStoreRetriever(store: self, topK: topK, filter: filter)
    }
}
