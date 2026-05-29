import Foundation

/// Pure-Swift BM25 retriever. No embeddings; pure lexical match. Useful as the keyword leg of
/// a `HybridRetriever` or when embedding cost is a problem.
public actor BM25Retriever: Retriever {
    /// Number of documents to return.
    public let topK: Int
    /// Term-frequency saturation (the BM25 `k1` parameter). Higher values let repeated terms keep
    /// accruing weight; lower values saturate quickly.
    public let termSaturation: Double
    /// Document-length normalization (the BM25 `b` parameter), in `[0, 1]`. Higher values penalize
    /// long documents more.
    public let lengthNormalization: Double

    private struct Indexed: Sendable {
        let document: Document
        let termFrequencies: [String: Int]
        let length: Int
    }

    private var indexed: [Indexed] = []
    private var documentFrequencies: [String: Int] = [:]
    private var averageDocumentLength: Double = 0

    public init(topK: Int = 4, termSaturation: Double = 1.5, lengthNormalization: Double = 0.75) {
        self.topK = topK
        self.termSaturation = termSaturation
        self.lengthNormalization = lengthNormalization
    }

    public func addDocuments(_ documents: [Document]) {
        for document in documents { ingest(document) }
    }

    public func retrieve(_ query: String) async throws -> [Document] {
        let queryTerms = tokenize(query)
        guard !queryTerms.isEmpty, !indexed.isEmpty else { return [] }
        let totalDocuments = Double(indexed.count)
        let scored = indexed.map { entry -> (Document, Double) in
            var score = 0.0
            for term in queryTerms {
                guard let termFrequencies = entry.termFrequencies[term] else { continue }
                let documentFrequency = documentFrequencies[term] ?? 0
                let idfNumerator = totalDocuments - Double(documentFrequency) + 0.5
                let idf = log(idfNumerator / (Double(documentFrequency) + 0.5) + 1)
                let lengthRatio = averageDocumentLength == 0 ? 1.0 : Double(entry.length) / averageDocumentLength
                let lengthFactor = 1 - lengthNormalization + lengthNormalization * lengthRatio
                let frequencyComponent = (Double(termFrequencies) * (termSaturation + 1))
                    / (Double(termFrequencies) + termSaturation * lengthFactor)
                score += idf * frequencyComponent
            }
            return (entry.document, score)
        }
        return scored
            .sorted { $0.1 > $1.1 }
            .prefix(topK)
            .map(\.0)
    }

    private func ingest(_ document: Document) {
        let tokens = tokenize(document.pageContent)
        var counts: [String: Int] = [:]
        for token in tokens { counts[token, default: 0] += 1 }
        for term in Set(tokens) { documentFrequencies[term, default: 0] += 1 }
        indexed.append(Indexed(document: document, termFrequencies: counts, length: tokens.count))
        let totalLength = indexed.reduce(0) { $0 + $1.length }
        averageDocumentLength = Double(totalLength) / Double(indexed.count)
    }
}

func tokenize(_ text: String) -> [String] {
    text.lowercased()
        .components(separatedBy: CharacterSet.alphanumerics.inverted)
        .filter { !$0.isEmpty }
}
