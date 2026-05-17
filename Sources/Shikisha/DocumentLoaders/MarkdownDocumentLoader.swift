import Foundation

/// Heading-aware Markdown loader. Splits at headings via `MarkdownHeaderTextSplitter` and
/// attaches cumulative `h1`/`h2`/`h3` metadata. Falls back to a single-document return if
/// the file has no headings.
public struct MarkdownDocumentLoader: DocumentLoader {
    public let url: URL
    public let splitter: MarkdownHeaderTextSplitter

    public init(url: URL, splitter: MarkdownHeaderTextSplitter = MarkdownHeaderTextSplitter()) {
        self.url = url
        self.splitter = splitter
    }

    public func load() async throws -> [Document] {
        let data = try Data(contentsOf: url)
        let text = String(decoding: data, as: UTF8.self)
        let documents = splitter.splitText(text)
        if documents.isEmpty {
            return [Document(pageContent: text, metadata: ["source": .string(url.absoluteString)])]
        }
        return documents.map { $0.withMetadata(["source": .string(url.absoluteString)]) }
    }
}
