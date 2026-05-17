import Foundation

/// Turn text into dense float vectors. Every provider that exposes embeddings (OpenAI,
/// Google Gemini, Ollama, …) conforms.
public protocol Embeddings: Sendable {
    /// Identifier of the embedding model (e.g. `"text-embedding-3-small"`).
    var modelName: String { get }

    /// Number of dimensions in each returned vector. `nil` if unknown until the first call.
    var dimensions: Int? { get }

    /// Embed a batch of documents in a single round-trip. Returns vectors in the same
    /// order as `texts`.
    func embedDocuments(_ texts: [String]) async throws -> [[Float]]

    /// Embed a single query string. Default implementation delegates to `embedDocuments`.
    func embedQuery(_ text: String) async throws -> [Float]
}

public extension Embeddings {
    var dimensions: Int? { nil }

    func embedQuery(_ text: String) async throws -> [Float] {
        let vectors = try await embedDocuments([text])
        guard let first = vectors.first else {
            throw HTTPError.decoding(message: "embeddings returned empty response")
        }
        return first
    }
}
