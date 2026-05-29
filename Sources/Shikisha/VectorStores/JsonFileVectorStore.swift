import Foundation

/// File-backed vector store. The whole `(id, document, vector)` map lives in a single JSON
/// file; loads and saves are atomic. Use for small corpora (~thousands of documents); larger
/// ones should use `SqliteVectorStore`.
public actor JsonFileVectorStore: VectorStore {
    public nonisolated let embeddings: any Embeddings
    public let file: URL

    private struct StoredEntry: Codable, Sendable {
        let id: String
        let document: Document
        let vector: [Float]
    }

    private var entries: [String: StoredEntry] = [:]

    public init(file: URL, embeddings: any Embeddings) throws {
        self.embeddings = embeddings
        self.file = file
        let directory = file.deletingLastPathComponent()
        try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
        if let data = try? Data(contentsOf: file),
           let stored = try? JSONDecoder().decode([StoredEntry].self, from: data) {
            entries = Dictionary(uniqueKeysWithValues: stored.map { ($0.id, $0) })
        }
    }

    public func addDocuments(_ documents: [Document]) async throws -> [String] {
        guard !documents.isEmpty else { return [] }
        let vectors = try await embeddings.embedDocuments(documents.map(\.pageContent))
        var ids: [String] = []
        for (document, vector) in zip(documents, vectors) {
            let id = document.id ?? UUID().uuidString
            entries[id] = StoredEntry(id: id, document: document, vector: vector)
            ids.append(id)
        }
        try persist()
        return ids
    }

    public func deleteDocuments(ids: [String]) async throws -> Int {
        var removed = 0
        for id in ids where entries.removeValue(forKey: id) != nil { removed += 1 }
        if removed > 0 { try persist() }
        return removed
    }

    public func similaritySearch(
        query: String,
        topK: Int,
        filter: MetadataFilter?
    ) async throws -> [VectorSearchResult] {
        let queryVector = try await embeddings.embedQuery(query)
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

    private func persist() throws {
        let payload = Array(entries.values)
        let data = try JSONEncoder().encode(payload)
        try data.write(to: file, options: .atomic)
    }
}
