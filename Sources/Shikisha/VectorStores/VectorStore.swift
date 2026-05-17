import Foundation

/// A result returned by a vector-store search. `score` is the similarity (cosine) score.
public struct VectorSearchResult: Sendable, Hashable {
    public let document: Document
    public let score: Float

    public init(document: Document, score: Float) {
        self.document = document
        self.score = score
    }
}

/// A store of `(Document, vector)` pairs that can be queried by similarity to a query vector.
/// Backed by in-memory cosine, JSON-on-disk, or SQLite in this package; other backends can
/// conform without changes upstream.
public protocol VectorStore: Sendable {
    /// Embeddings model used to encode queries (and `addDocuments` inputs, if the impl wants).
    var embeddings: any Embeddings { get }

    /// Add documents to the store. Returns the IDs assigned. Implementations decide whether
    /// to generate IDs or honor `Document.id`.
    func addDocuments(_ documents: [Document]) async throws -> [String]

    /// Delete documents by ID. Returns the count actually removed.
    func deleteDocuments(ids: [String]) async throws -> Int

    /// Top-`k` documents by similarity to `query`, with filter applied to metadata.
    func similaritySearch(query: String, k: Int, filter: MetadataFilter?) async throws -> [VectorSearchResult]
}

public extension VectorStore {
    func similaritySearch(query: String, k: Int = 4) async throws -> [VectorSearchResult] {
        try await similaritySearch(query: query, k: k, filter: nil)
    }
}
