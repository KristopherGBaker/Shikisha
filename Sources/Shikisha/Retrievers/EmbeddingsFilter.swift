import Foundation

/// Embed every retrieved document and the query, keep those above `similarityThreshold` (and
/// optionally cap at `maxDocuments`). Cheap precision filter to pair with a recall-oriented
/// retriever.
public struct EmbeddingsFilter: DocumentCompressor {
    public let embeddings: any Embeddings
    public let similarityThreshold: Float
    public let maxDocuments: Int?

    public init(embeddings: any Embeddings, similarityThreshold: Float = 0.7, maxDocuments: Int? = nil) {
        self.embeddings = embeddings
        self.similarityThreshold = similarityThreshold
        self.maxDocuments = maxDocuments
    }

    public func compress(documents: [Document], query: String) async throws -> [Document] {
        guard !documents.isEmpty else { return [] }
        let texts = documents.map(\.pageContent) + [query]
        let vectors = try await embeddings.embedDocuments(texts)
        guard let queryVector = vectors.last else { return documents }
        let documentVectors = vectors.dropLast()
        let scored = zip(documents, documentVectors)
            .map { ($0, cosineSimilarity($1, queryVector)) }
            .filter { $0.1 >= similarityThreshold }
            .sorted { $0.1 > $1.1 }
        let limited = maxDocuments.map { Array(scored.prefix($0)) } ?? Array(scored)
        return limited.map(\.0)
    }
}
