import Foundation

/// Load a plain text file as a single `Document`. The `source` metadata key holds the file URL.
public struct TextDocumentLoader: DocumentLoader {
    public let url: URL
    public let encoding: String.Encoding

    public init(url: URL, encoding: String.Encoding = .utf8) {
        self.url = url
        self.encoding = encoding
    }

    public func load() async throws -> [Document] {
        let raw = try Data(contentsOf: url)
        let text = String(data: raw, encoding: encoding) ?? ""
        return [Document(pageContent: text, metadata: ["source": .string(url.absoluteString)])]
    }
}
