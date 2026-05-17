import Foundation

/// A chunk of text with arbitrary metadata. The base unit for every loader, splitter,
/// vector store, and retriever in Shikisha.
public struct Document: Sendable, Hashable, Codable {
    public let pageContent: String
    public let metadata: [String: JSONValue]
    public let id: String?

    public init(pageContent: String, metadata: [String: JSONValue] = [:], id: String? = nil) {
        self.pageContent = pageContent
        self.metadata = metadata
        self.id = id
    }

    /// Return a new `Document` with `metadata` merged on top of the existing fields.
    public func withMetadata(_ updates: [String: JSONValue]) -> Document {
        var merged = metadata
        for (key, value) in updates { merged[key] = value }
        return Document(pageContent: pageContent, metadata: merged, id: id)
    }
}
