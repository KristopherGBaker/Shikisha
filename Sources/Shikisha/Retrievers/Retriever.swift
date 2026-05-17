import Foundation

/// Anything that takes a text query and returns ranked `Document`s. Vector-store retrievers,
/// BM25, hybrid, LLM-reranked — they all conform.
public protocol Retriever: Runnable where Input == String, Output == [Document] {
    func retrieve(_ query: String) async throws -> [Document]
}

public extension Retriever {
    func invoke(_ input: String) async throws -> [Document] {
        try await retrieve(input)
    }
}
