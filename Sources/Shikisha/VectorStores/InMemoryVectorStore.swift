import Foundation

/// Cosine-similarity vector store backed by an in-memory dictionary. Fine for prototypes
/// and tests; use `JsonFileVectorStore` for persistence or `SqliteVectorStore` for larger
/// corpora.
public actor InMemoryVectorStore: VectorStore {
    public nonisolated let embeddings: any Embeddings

    private struct Entry: Sendable {
        let id: String
        let document: Document
        let vector: [Float]
    }

    private var entries: [String: Entry] = [:]

    public init(embeddings: any Embeddings) {
        self.embeddings = embeddings
    }

    public func addDocuments(_ documents: [Document]) async throws -> [String] {
        guard !documents.isEmpty else { return [] }
        let texts = documents.map(\.pageContent)
        let vectors = try await embeddings.embedDocuments(texts)
        precondition(vectors.count == documents.count, "embedding count mismatch")
        var ids: [String] = []
        for (document, vector) in zip(documents, vectors) {
            let id = document.id ?? UUID().uuidString
            entries[id] = Entry(id: id, document: document, vector: vector)
            ids.append(id)
        }
        return ids
    }

    public func deleteDocuments(ids: [String]) async throws -> Int {
        var removed = 0
        for id in ids where entries.removeValue(forKey: id) != nil {
            removed += 1
        }
        return removed
    }

    public func similaritySearch(
        query: String,
        topK: Int,
        filter: MetadataFilter?
    ) async throws -> [VectorSearchResult] {
        let queryVector = try await embeddings.embedQuery(query)
        return search(queryVector: queryVector, topK: topK, filter: filter)
    }

    /// Direct search with a precomputed query vector. Used by `MmrRetriever` and any caller that
    /// wants to embed once and search multiple stores.
    public func similaritySearchByVector(
        _ vector: [Float],
        topK: Int,
        filter: MetadataFilter? = nil
    ) -> [VectorSearchResult] {
        search(queryVector: vector, topK: topK, filter: filter)
    }

    /// Snapshot of every `(id, document, vector)` triple — read-only.
    public func allEntries() -> [(id: String, document: Document, vector: [Float])] {
        entries.values.map { ($0.id, $0.document, $0.vector) }
    }

    private func search(queryVector: [Float], topK: Int, filter: MetadataFilter?) -> [VectorSearchResult] {
        let filtered = entries.values.filter { filter?.matches($0.document.metadata) ?? true }
        let scored = filtered.map { entry in
            VectorSearchResult(
                document: Document(
                    pageContent: entry.document.pageContent,
                    metadata: entry.document.metadata,
                    id: entry.id
                ),
                score: cosineSimilarity(queryVector, entry.vector)
            )
        }
        return Array(scored.sorted { $0.score > $1.score }.prefix(topK))
    }
}
