import Foundation

/// Run multiple retrievers in parallel and fuse the result rankings via reciprocal rank fusion.
/// The classic recipe for combining semantic (vector) and lexical (BM25) signals.
public struct HybridRetriever: Retriever {
    public let retrievers: [any Retriever]
    public let k: Int
    public let rrfConstant: Double

    public init(retrievers: [any Retriever], k: Int = 4, rrfConstant: Double = 60) {
        precondition(!retrievers.isEmpty, "HybridRetriever needs at least one retriever")
        self.retrievers = retrievers
        self.k = k
        self.rrfConstant = rrfConstant
    }

    public func retrieve(_ query: String) async throws -> [Document] {
        let allResults: [[Document]] = try await withThrowingTaskGroup(of: (Int, [Document]).self) { group in
            for (index, retriever) in retrievers.enumerated() {
                group.addTask {
                    let docs = try await retriever.retrieve(query)
                    return (index, docs)
                }
            }
            var collected: [(Int, [Document])] = []
            for try await result in group { collected.append(result) }
            return collected.sorted { $0.0 < $1.0 }.map(\.1)
        }

        var scores: [String: (document: Document, score: Double)] = [:]
        for rankings in allResults {
            for (rank, document) in rankings.enumerated() {
                let key = document.id ?? "\(document.pageContent.hashValue)"
                let bonus = 1.0 / (rrfConstant + Double(rank + 1))
                if let existing = scores[key] {
                    scores[key] = (existing.document, existing.score + bonus)
                } else {
                    scores[key] = (document, bonus)
                }
            }
        }
        return scores.values
            .sorted { $0.score > $1.score }
            .prefix(k)
            .map(\.document)
    }
}
