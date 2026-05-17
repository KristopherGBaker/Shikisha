import Foundation

/// Use an LLM to translate a natural-language query into `(query, MetadataFilter)`. The query
/// goes to the underlying retriever; the filter is applied after results come back.
public struct SelfQueryingRetriever: Retriever {
    public let base: any Retriever
    public let model: any ChatModel
    public let attributeDescriptions: [AttributeDescription]

    public struct AttributeDescription: Sendable {
        public let name: String
        public let type: String      // "string" / "int" / "double" / "bool"
        public let description: String

        public init(name: String, type: String, description: String) {
            self.name = name
            self.type = type
            self.description = description
        }
    }

    public init(base: any Retriever, model: any ChatModel, attributeDescriptions: [AttributeDescription]) {
        self.base = base
        self.model = model
        self.attributeDescriptions = attributeDescriptions
    }

    public func retrieve(_ query: String) async throws -> [Document] {
        let (cleanedQuery, filter) = try await translate(query)
        let documents = try await base.retrieve(cleanedQuery)
        guard let filter else { return documents }
        return documents.filter { filter.matches($0.metadata) }
    }

    private func translate(_ query: String) async throws -> (String, MetadataFilter?) {
        let attributes = attributeDescriptions
            .map { "- \($0.name) (\($0.type)): \($0.description)" }
            .joined(separator: "\n")
        let messages: [any Message] = [
            SystemMessage(content: """
                Given a user query and a list of filterable metadata attributes, produce a JSON
                object with two fields:

                {
                  "query": "<text query stripped of any filter clauses>",
                  "filter": { ... } | null
                }

                The filter, if present, must follow this grammar:

                  { "and": [<filter>, ...] }
                  { "or": [<filter>, ...] }
                  { "not": <filter> }
                  { "eq" | "neq" | "gt" | "gte" | "lt" | "lte": { "field": "x", "value": ... } }
                  { "in": { "field": "x", "values": [...] } }

                Attributes available:
                \(attributes)
                """),
            HumanMessage(content: query)
        ]
        let response = try await model.invoke(messages)
        let stripped = stripCodeFence(response.content)
        guard let value = JSONValue.parse(stripped),
              case .object(let fields) = value else {
            return (query, nil)
        }
        let cleanedQuery = fields["query"]?.stringValue ?? query
        let filter = fields["filter"].flatMap { parseFilter($0) }
        return (cleanedQuery, filter)
    }
}

func parseFilter(_ value: JSONValue) -> MetadataFilter? {
    guard case .object(let fields) = value else { return nil }
    if let andValue = fields["and"], let array = andValue.arrayValue {
        return .and(array.compactMap(parseFilter))
    }
    if let orValue = fields["or"], let array = orValue.arrayValue {
        return .or(array.compactMap(parseFilter))
    }
    if let notValue = fields["not"], let nested = parseFilter(notValue) {
        return .not(nested)
    }
    let comparators: [(String, (String, JSONValue) -> MetadataFilter)] = [
        ("eq", MetadataFilter.equal(field:value:)),
        ("neq", MetadataFilter.notEqual(field:value:)),
        ("gt", MetadataFilter.greaterThan(field:value:)),
        ("gte", MetadataFilter.greaterThanOrEqual(field:value:)),
        ("lt", MetadataFilter.lessThan(field:value:)),
        ("lte", MetadataFilter.lessThanOrEqual(field:value:))
    ]
    for (key, builder) in comparators {
        if case .object(let inner)? = fields[key],
           let field = inner["field"]?.stringValue,
           let value = inner["value"] {
            return builder(field, value)
        }
    }
    if case .object(let inner)? = fields["in"],
       let field = inner["field"]?.stringValue,
       let values = inner["values"]?.arrayValue {
        return .in(field: field, values: values)
    }
    return nil
}
