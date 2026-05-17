import Foundation

/// Build JSON Schema (draft 7 subset) programmatically. Used to feed structured-output
/// modes (`response_format: json_schema` on OpenAI, `tools` schemas everywhere).
public enum JSONSchema {
    public static func object(
        properties: [String: JSONValue],
        required: [String] = [],
        additionalProperties: Bool = false,
        description: String? = nil
    ) -> JSONValue {
        var schema: [String: JSONValue] = [
            "type": "object",
            "properties": .object(properties),
            "additionalProperties": .bool(additionalProperties)
        ]
        if !required.isEmpty {
            schema["required"] = .array(required.map { .string($0) })
        }
        if let description {
            schema["description"] = .string(description)
        }
        return .object(schema)
    }

    public static func string(description: String? = nil, enumValues: [String]? = nil) -> JSONValue {
        var schema: [String: JSONValue] = ["type": "string"]
        if let description { schema["description"] = .string(description) }
        if let enumValues { schema["enum"] = .array(enumValues.map { .string($0) }) }
        return .object(schema)
    }

    public static func integer(description: String? = nil) -> JSONValue {
        var schema: [String: JSONValue] = ["type": "integer"]
        if let description { schema["description"] = .string(description) }
        return .object(schema)
    }

    public static func number(description: String? = nil) -> JSONValue {
        var schema: [String: JSONValue] = ["type": "number"]
        if let description { schema["description"] = .string(description) }
        return .object(schema)
    }

    public static func boolean(description: String? = nil) -> JSONValue {
        var schema: [String: JSONValue] = ["type": "boolean"]
        if let description { schema["description"] = .string(description) }
        return .object(schema)
    }

    public static func array(items: JSONValue, description: String? = nil) -> JSONValue {
        var schema: [String: JSONValue] = [
            "type": "array",
            "items": items
        ]
        if let description { schema["description"] = .string(description) }
        return .object(schema)
    }

    public static func nullable(_ inner: JSONValue) -> JSONValue {
        guard case .object(var fields) = inner, let typeValue = fields["type"] else {
            return inner
        }
        switch typeValue {
        case .string(let typeName):
            fields["type"] = .array([.string(typeName), .string("null")])
        case .array(var types):
            if !types.contains(.string("null")) { types.append(.string("null")) }
            fields["type"] = .array(types)
        default: break
        }
        return .object(fields)
    }
}
