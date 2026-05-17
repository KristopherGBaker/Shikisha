import Foundation

/// Trim or rewrite retrieved documents before they reach the model. Used by
/// `ContextualCompressionRetriever`. Implementations include embedding similarity filters,
/// LLM-driven extractors, LLM-driven rerankers.
public protocol DocumentCompressor: Sendable {
    func compress(documents: [Document], query: String) async throws -> [Document]
}

/// Apply a list of compressors in order.
public struct DocumentCompressorPipeline: DocumentCompressor {
    public let compressors: [any DocumentCompressor]

    public init(_ compressors: [any DocumentCompressor]) {
        self.compressors = compressors
    }

    public func compress(documents: [Document], query: String) async throws -> [Document] {
        var current = documents
        for compressor in compressors {
            current = try await compressor.compress(documents: current, query: query)
        }
        return current
    }
}
