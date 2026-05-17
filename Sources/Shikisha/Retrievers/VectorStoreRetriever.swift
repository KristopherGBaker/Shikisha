import Foundation

/// Plug any `VectorStore` into the `Retriever` protocol. Strips scores; callers that need them
/// should hit the store directly.
public struct VectorStoreRetriever: Retriever {
    public let store: any VectorStore
    public let k: Int
    public let filter: MetadataFilter?

    public init(store: any VectorStore, k: Int = 4, filter: MetadataFilter? = nil) {
        self.store = store
        self.k = k
        self.filter = filter
    }

    public func retrieve(_ query: String) async throws -> [Document] {
        let results = try await store.similaritySearch(query: query, k: k, filter: filter)
        return results.map(\.document)
    }
}

public extension VectorStore {
    /// Lift this store into a `Retriever`. Shorthand for `VectorStoreRetriever(store: self, ...)`.
    func asRetriever(k: Int = 4, filter: MetadataFilter? = nil) -> VectorStoreRetriever {
        VectorStoreRetriever(store: self, k: k, filter: filter)
    }
}
