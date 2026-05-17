import Foundation

/// One `Document` per row, with header-keyed metadata. Tolerant of quoted fields with
/// embedded delimiters / newlines via `CsvOutputParser`'s parser.
public struct CsvDocumentLoader: DocumentLoader {
    public let url: URL
    public let delimiter: Character
    public let contentColumn: String?

    public init(url: URL, delimiter: Character = ",", contentColumn: String? = nil) {
        self.url = url
        self.delimiter = delimiter
        self.contentColumn = contentColumn
    }

    public static func from(string text: String, source: String = "string", delimiter: Character = ",", contentColumn: String? = nil) -> [Document] {
        let rows = parseCSV(text, delimiter: delimiter)
        return Self.makeDocuments(rows: rows, source: source, contentColumn: contentColumn)
    }

    public func load() async throws -> [Document] {
        let raw = try Data(contentsOf: url)
        let text = String(bytes: raw, encoding: .utf8) ?? ""
        let rows = parseCSV(text, delimiter: delimiter)
        return Self.makeDocuments(rows: rows, source: url.absoluteString, contentColumn: contentColumn)
    }

    static func makeDocuments(rows: [[String]], source: String, contentColumn: String?) -> [Document] {
        guard rows.count >= 2 else { return [] }
        let headers = rows[0]
        let bodyRows = rows.dropFirst()
        let contentIndex: Int
        if let contentColumn, let index = headers.firstIndex(of: contentColumn) {
            contentIndex = index
        } else {
            contentIndex = 0
        }
        return bodyRows.compactMap { row -> Document? in
            guard row.indices.contains(contentIndex) else { return nil }
            var metadata: [String: JSONValue] = ["source": .string(source)]
            for (index, header) in headers.enumerated() where index != contentIndex && row.indices.contains(index) {
                metadata[header] = .string(row[index])
            }
            return Document(pageContent: row[contentIndex], metadata: metadata)
        }
    }
}
