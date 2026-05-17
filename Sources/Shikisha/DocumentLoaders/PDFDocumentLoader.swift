import Foundation
#if canImport(PDFKit)
import PDFKit

/// One `Document` per PDF page via PDFKit. Page numbers are 1-indexed and stored as
/// `page` metadata; the file URL is stored as `source`.
public struct PDFDocumentLoader: DocumentLoader {
    public let url: URL

    public init(url: URL) { self.url = url }

    public func load() async throws -> [Document] {
        guard let pdf = PDFDocument(url: url) else {
            throw HTTPError.decoding(message: "could not open PDF at \(url.path)")
        }
        var documents: [Document] = []
        for index in 0..<pdf.pageCount {
            guard let page = pdf.page(at: index) else { continue }
            let text = page.string ?? ""
            let metadata: [String: JSONValue] = [
                "source": .string(url.absoluteString),
                "page": .int(Int64(index + 1))
            ]
            documents.append(Document(pageContent: text, metadata: metadata))
        }
        return documents
    }
}
#else
public struct PDFDocumentLoader: DocumentLoader {
    public let url: URL
    public init(url: URL) { self.url = url }
    public func load() async throws -> [Document] {
        throw HTTPError.transport(message: "PDFKit not available on this platform")
    }
}
#endif
