import Foundation

/// Wrap any retriever with a `DocumentCompressor`. The base retriever fetches a broad set;
/// the compressor narrows down by relevance / extracts the useful spans.
public struct ContextualCompressionRetriever: Retriever {
    public let base: any Retriever
    public let compressor: any DocumentCompressor

    public init(base: any Retriever, compressor: any DocumentCompressor) {
        self.base = base
        self.compressor = compressor
    }

    public func retrieve(_ query: String) async throws -> [Document] {
        let documents = try await base.retrieve(query)
        return try await compressor.compress(documents: documents, query: query)
    }
}
