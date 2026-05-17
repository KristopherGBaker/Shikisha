import Foundation

/// Slice long text into smaller chunks suitable for embedding or model context. The base
/// protocol takes the document, returns a sequence of `Document`s sharing the same metadata
/// (with optional `startIndex` if `addStartIndex` is on).
public protocol TextSplitter: Sendable {
    func splitText(_ text: String) -> [String]

    func splitDocuments(_ documents: [Document]) -> [Document]
}

public extension TextSplitter {
    func splitDocuments(_ documents: [Document]) -> [Document] {
        documents.flatMap { document in
            splitText(document.pageContent).enumerated().map { index, chunk in
                var metadata = document.metadata
                metadata["chunk"] = .int(Int64(index))
                return Document(pageContent: chunk, metadata: metadata, id: document.id)
            }
        }
    }
}
