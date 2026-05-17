import Foundation

/// Wire-shape DTOs for Anthropic's `/v1/messages` endpoint.

// MARK: - Request

struct AnthropicRequest: Encodable {
    let model: String
    let maxTokens: Int
    let messages: [AnthropicRequestMessage]
    let system: AnthropicSystem?
    let temperature: Double?
    let tools: [AnthropicToolSpec]?
    let stream: Bool?

    enum CodingKeys: String, CodingKey {
        case model
        case maxTokens = "max_tokens"
        case messages
        case system
        case temperature
        case tools
        case stream
    }
}

/// Either a bare string (no caching) or an array of `text` blocks with optional cache control.
enum AnthropicSystem: Encodable {
    case text(String)
    case blocks([AnthropicSystemBlock])

    func encode(to encoder: Encoder) throws {
        var container = encoder.singleValueContainer()
        switch self {
        case .text(let value): try container.encode(value)
        case .blocks(let blocks): try container.encode(blocks)
        }
    }
}

struct AnthropicSystemBlock: Encodable {
    let type: String
    let text: String
    let cacheControl: AnthropicCacheControl?

    enum CodingKeys: String, CodingKey {
        case type
        case text
        case cacheControl = "cache_control"
    }
}

struct AnthropicCacheControl: Encodable {
    let type: String

    init(type: String = "ephemeral") { self.type = type }
}

struct AnthropicRequestMessage: Encodable {
    let role: String
    let content: [AnthropicContentBlock]
}

enum AnthropicContentBlock: Encodable {
    case text(text: String, cacheControl: AnthropicCacheControl?)
    case image(source: AnthropicImageSource, cacheControl: AnthropicCacheControl?)
    case toolUse(id: String, name: String, input: JSONValue, cacheControl: AnthropicCacheControl?)
    case toolResult(toolUseId: String, content: String, isError: Bool?, cacheControl: AnthropicCacheControl?)

    private enum CodingKeys: String, CodingKey {
        case type
        case text
        case source
        case id
        case name
        case input
        case toolUseId = "tool_use_id"
        case content
        case isError = "is_error"
        case cacheControl = "cache_control"
    }

    func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        switch self {
        case .text(let text, let cache):
            try container.encode("text", forKey: .type)
            try container.encode(text, forKey: .text)
            try container.encodeIfPresent(cache, forKey: .cacheControl)
        case .image(let source, let cache):
            try container.encode("image", forKey: .type)
            try container.encode(source, forKey: .source)
            try container.encodeIfPresent(cache, forKey: .cacheControl)
        case .toolUse(let id, let name, let input, let cache):
            try container.encode("tool_use", forKey: .type)
            try container.encode(id, forKey: .id)
            try container.encode(name, forKey: .name)
            try container.encode(input, forKey: .input)
            try container.encodeIfPresent(cache, forKey: .cacheControl)
        case .toolResult(let toolUseId, let content, let isError, let cache):
            try container.encode("tool_result", forKey: .type)
            try container.encode(toolUseId, forKey: .toolUseId)
            try container.encode(content, forKey: .content)
            try container.encodeIfPresent(isError, forKey: .isError)
            try container.encodeIfPresent(cache, forKey: .cacheControl)
        }
    }
}

enum AnthropicImageSource: Encodable {
    case base64(mediaType: String, data: String)
    case url(String)

    private enum CodingKeys: String, CodingKey {
        case type
        case mediaType = "media_type"
        case data
        case url
    }

    func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        switch self {
        case .base64(let mediaType, let data):
            try container.encode("base64", forKey: .type)
            try container.encode(mediaType, forKey: .mediaType)
            try container.encode(data, forKey: .data)
        case .url(let url):
            try container.encode("url", forKey: .type)
            try container.encode(url, forKey: .url)
        }
    }
}

struct AnthropicToolSpec: Encodable {
    let name: String
    let description: String
    let inputSchema: JSONValue
    let cacheControl: AnthropicCacheControl?

    enum CodingKeys: String, CodingKey {
        case name
        case description
        case inputSchema = "input_schema"
        case cacheControl = "cache_control"
    }
}

// MARK: - Response

struct AnthropicResponse: Decodable {
    let id: String?
    let content: [AnthropicResponseBlock]
    let usage: AnthropicUsage?
    let stopReason: String?

    enum CodingKeys: String, CodingKey {
        case id
        case content
        case usage
        case stopReason = "stop_reason"
    }
}

enum AnthropicResponseBlock: Decodable {
    case text(String)
    case toolUse(id: String, name: String, input: JSONValue)

    private enum CodingKeys: String, CodingKey {
        case type
        case text
        case id
        case name
        case input
    }

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        let type = try container.decode(String.self, forKey: .type)
        switch type {
        case "text":
            self = .text(try container.decode(String.self, forKey: .text))
        case "tool_use":
            self = .toolUse(
                id: try container.decode(String.self, forKey: .id),
                name: try container.decode(String.self, forKey: .name),
                input: try container.decode(JSONValue.self, forKey: .input)
            )
        default:
            self = .text("")
        }
    }
}

struct AnthropicUsage: Decodable {
    let inputTokens: Int
    let outputTokens: Int
    let cacheCreationInputTokens: Int?
    let cacheReadInputTokens: Int?

    enum CodingKeys: String, CodingKey {
        case inputTokens = "input_tokens"
        case outputTokens = "output_tokens"
        case cacheCreationInputTokens = "cache_creation_input_tokens"
        case cacheReadInputTokens = "cache_read_input_tokens"
    }
}

extension UsageMetadata {
    init(from usage: AnthropicUsage) {
        self.init(
            inputTokens: usage.inputTokens,
            outputTokens: usage.outputTokens,
            totalTokens: usage.inputTokens + usage.outputTokens,
            cacheReadInputTokens: usage.cacheReadInputTokens ?? 0,
            cacheCreationInputTokens: usage.cacheCreationInputTokens ?? 0
        )
    }
}

// MARK: - Streaming

struct AnthropicStreamEvent: Decodable {
    let type: String
    let index: Int?
    let contentBlock: AnthropicStreamContentBlock?
    let delta: AnthropicStreamDelta?
    let usage: AnthropicUsage?

    enum CodingKeys: String, CodingKey {
        case type
        case index
        case contentBlock = "content_block"
        case delta
        case usage
    }
}

struct AnthropicStreamContentBlock: Decodable {
    let type: String
    let id: String?
    let name: String?
}

struct AnthropicStreamDelta: Decodable {
    let type: String
    let text: String?
    let partialJSON: String?
    let stopReason: String?

    enum CodingKeys: String, CodingKey {
        case type
        case text
        case partialJSON = "partial_json"
        case stopReason = "stop_reason"
    }
}
