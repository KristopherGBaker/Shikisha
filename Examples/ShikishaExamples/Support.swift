import Foundation
import Shikisha

// MARK: - Local embeddings

/// A deterministic, dependency-free `Embeddings` implementation for offline demos and tests.
///
/// It hashes characters into a small fixed-size vector. It is *not* semantically meaningful —
/// it just lets the vector-store and retriever examples run without calling a real embeddings
/// provider. In production you would use ``OpenAIEmbeddings``, ``GoogleEmbeddings``, or
/// ``OllamaEmbeddings`` instead.
struct LocalHashEmbeddings: Embeddings {
    let modelName = "local-hash-embeddings"
    let dimensions: Int? = 32

    func embedDocuments(_ texts: [String]) async throws -> [[Float]] {
        texts.map { text in
            var vector = [Float](repeating: 0, count: 32)
            for token in text.lowercased().split(whereSeparator: { !$0.isLetter && !$0.isNumber }) {
                var hash: UInt64 = 1_469_598_103_934_665_603
                for scalar in token.unicodeScalars {
                    hash = (hash ^ UInt64(scalar.value)) &* 1_099_511_628_211
                }
                vector[Int(hash % 32)] += 1
            }
            let norm = sqrt(vector.reduce(0) { $0 + $1 * $1 })
            return norm > 0 ? vector.map { $0 / norm } : vector
        }
    }
}

// MARK: - Output helpers

/// Prints a labelled section header so example output is easy to scan.
func section(_ title: String) {
    print("— \(title) " + String(repeating: "—", count: max(0, 56 - title.count)))
}
