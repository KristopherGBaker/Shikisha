import Foundation

/// Pure-Swift BM25 retriever. No embeddings; pure lexical match. Useful as the keyword leg of
/// a `HybridRetriever` or when embedding cost is a problem.
public actor BM25Retriever: Retriever {
    public let k: Int
    public let k1: Double
    public let b: Double

    private struct Indexed: Sendable {
        let document: Document
        let termFrequencies: [String: Int]
        let length: Int
    }

    private var indexed: [Indexed] = []
    private var documentFrequencies: [String: Int] = [:]
    private var averageDocumentLength: Double = 0

    public init(k: Int = 4, k1: Double = 1.5, b: Double = 0.75) {
        self.k = k
        self.k1 = k1
        self.b = b
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
                let idf = log((totalDocuments - Double(documentFrequency) + 0.5) / (Double(documentFrequency) + 0.5) + 1)
                let lengthRatio = averageDocumentLength == 0 ? 1.0 : Double(entry.length) / averageDocumentLength
                let frequencyComponent = (Double(termFrequencies) * (k1 + 1))
                    / (Double(termFrequencies) + k1 * (1 - b + b * lengthRatio))
                score += idf * frequencyComponent
            }
            return (entry.document, score)
        }
        return scored
            .sorted { $0.1 > $1.1 }
            .prefix(k)
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
