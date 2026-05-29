import Foundation

/// Search a corpus of *small* chunks (for retrieval precision), return the *parent* documents
/// they came from (for context). The classic trade-off resolver: small chunks find the right
/// passage, parents give the model enough surrounding context to actually use it.
public actor ParentDocumentRetriever: Retriever {
    public let childStore: any VectorStore
    public let parentIDKey: String
    public let topK: Int

    private var parentDocuments: [String: Document] = [:]

    public init(childStore: any VectorStore, parentIDKey: String = "parent_id", topK: Int = 4) {
        self.childStore = childStore
        self.parentIDKey = parentIDKey
        self.topK = topK
    }

    /// Register parent documents, chunk them, and index the chunks. Each chunk gets a
    /// `parent_id` metadata key pointing back to the parent.
    public func addDocuments(_ parents: [Document], childSplitter: any TextSplitter) async throws {
        var chunks: [Document] = []
        for parent in parents {
            let id = parent.id ?? UUID().uuidString
            parentDocuments[id] = Document(pageContent: parent.pageContent, metadata: parent.metadata, id: id)
            let chunkedTexts = childSplitter.splitText(parent.pageContent)
            for chunk in chunkedTexts {
                var metadata = parent.metadata
                metadata[parentIDKey] = .string(id)
                chunks.append(Document(pageContent: chunk, metadata: metadata))
            }
        }
        _ = try await childStore.addDocuments(chunks)
    }

    public func retrieve(_ query: String) async throws -> [Document] {
        let results = try await childStore.similaritySearch(query: query, topK: topK * 4, filter: nil)
        var seen = Set<String>()
        var parents: [Document] = []
        for result in results {
            guard let parentID = result.document.metadata[parentIDKey]?.stringValue,
                  seen.insert(parentID).inserted,
                  let parent = parentDocuments[parentID] else { continue }
            parents.append(parent)
            if parents.count >= topK { break }
        }
        return parents
    }
}
