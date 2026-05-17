import Foundation

/// Load a JSON document and project one or more text fields. `textFieldPath` is a
/// dot-separated path into each top-level item; for `{ "items": [{...}, {...}] }`, set
/// `arrayPath: "items"` and `textFieldPath: "body"`. For a top-level array, leave `arrayPath`
/// nil.
public struct JSONDocumentLoader: DocumentLoader {
    public let url: URL
    public let arrayPath: String?
    public let textFieldPath: String
    public let metadataFields: [String]

    public init(
        url: URL,
        arrayPath: String? = nil,
        textFieldPath: String,
        metadataFields: [String] = []
    ) {
        self.url = url
        self.arrayPath = arrayPath
        self.textFieldPath = textFieldPath
        self.metadataFields = metadataFields
    }

    public func load() async throws -> [Document] {
        let data = try Data(contentsOf: url)
        let value = try JSONDecoder().decode(JSONValue.self, from: data)
        let items: [JSONValue]
        if let arrayPath {
            guard case .array(let array) = lookup(path: arrayPath, in: value) ?? .null else {
                return []
            }
            items = array
        } else if case .array(let array) = value {
            items = array
        } else {
            items = [value]
        }
        return items.compactMap { item -> Document? in
            guard let text = lookup(path: textFieldPath, in: item)?.stringValue else { return nil }
            var metadata: [String: JSONValue] = ["source": .string(url.absoluteString)]
            for field in metadataFields {
                if let value = lookup(path: field, in: item) {
                    metadata[field] = value
                }
            }
            return Document(pageContent: text, metadata: metadata)
        }
    }
}

func lookup(path: String, in value: JSONValue) -> JSONValue? {
    var current: JSONValue? = value
    for component in path.split(separator: ".") {
        current = current?[String(component)]
    }
    return current
}
