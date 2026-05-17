import Foundation

/// Wire-shape DTOs for OpenAI's `/chat/completions` endpoint. Kept internal — public
/// callers operate against `OpenAIChatModel`'s typed API, not the raw shape.

struct OpenAIRequest: Encodable {
    let model: String
    let messages: [OpenAIRequestMessage]
    let temperature: Double?
    let maxCompletionTokens: Int?
    let tools: [JSONValue]?
    let stream: Bool?
    let responseFormat: JSONValue?
    let streamOptions: StreamOptions?

    struct StreamOptions: Encodable {
        let includeUsage: Bool
        enum CodingKeys: String, CodingKey { case includeUsage = "include_usage" }
    }

    enum CodingKeys: String, CodingKey {
        case model
        case messages
        case temperature
        case maxCompletionTokens = "max_completion_tokens"
        case tools
        case stream
        case responseFormat = "response_format"
        case streamOptions = "stream_options"
    }
}

struct OpenAIRequestMessage: Encodable {
    let role: String
    let content: OpenAIContent?
    let name: String?
    let toolCalls: [OpenAIRequestToolCall]?
    let toolCallId: String?

    enum CodingKeys: String, CodingKey {
        case role
        case content
        case name
        case toolCalls = "tool_calls"
        case toolCallId = "tool_call_id"
    }
}

/// Either a plain string or a multi-part array (image + text). OpenAI requires the array
/// shape when any image attachment is present.
enum OpenAIContent: Encodable {
    case text(String)
    case parts([OpenAIContentPart])

    func encode(to encoder: Encoder) throws {
        var container = encoder.singleValueContainer()
        switch self {
        case .text(let value): try container.encode(value)
        case .parts(let parts): try container.encode(parts)
        }
    }
}

struct OpenAIContentPart: Encodable {
    let type: String
    let text: String?
    let imageURL: ImageURL?

    struct ImageURL: Encodable {
        let url: String
        let detail: String?
    }

    enum CodingKeys: String, CodingKey {
        case type
        case text
        case imageURL = "image_url"
    }
}

struct OpenAIRequestToolCall: Encodable {
    let id: String
    let type: String
    let function: OpenAIRequestToolFunction
}

struct OpenAIRequestToolFunction: Encodable {
    let name: String
    let arguments: String
}

struct OpenAIResponse: Decodable {
    let id: String?
    let choices: [Choice]
    let usage: OpenAIUsage?

    struct Choice: Decodable {
        let message: OpenAIResponseMessage
        let finishReason: String?

        enum CodingKeys: String, CodingKey {
            case message
            case finishReason = "finish_reason"
        }
    }
}

struct OpenAIResponseMessage: Decodable {
    let content: String?
    let toolCalls: [OpenAIResponseToolCall]?

    enum CodingKeys: String, CodingKey {
        case content
        case toolCalls = "tool_calls"
    }
}

struct OpenAIResponseToolCall: Decodable {
    let id: String
    let type: String?
    let function: OpenAIResponseToolFunction
}

struct OpenAIResponseToolFunction: Decodable {
    let name: String
    let arguments: String
}

struct OpenAIUsage: Decodable {
    let promptTokens: Int
    let completionTokens: Int
    let totalTokens: Int

    enum CodingKeys: String, CodingKey {
        case promptTokens = "prompt_tokens"
        case completionTokens = "completion_tokens"
        case totalTokens = "total_tokens"
    }
}

// MARK: - Streaming DTOs

struct OpenAIStreamChunk: Decodable {
    let id: String?
    let choices: [Choice]
    let usage: OpenAIUsage?

    struct Choice: Decodable {
        let delta: Delta?
        let finishReason: String?

        enum CodingKeys: String, CodingKey {
            case delta
            case finishReason = "finish_reason"
        }
    }

    struct Delta: Decodable {
        let content: String?
        let toolCalls: [DeltaToolCall]?

        enum CodingKeys: String, CodingKey {
            case content
            case toolCalls = "tool_calls"
        }
    }

    struct DeltaToolCall: Decodable {
        let index: Int
        let id: String?
        let function: DeltaToolFunction?
    }

    struct DeltaToolFunction: Decodable {
        let name: String?
        let arguments: String?
    }
}

// MARK: - Conversion

extension UsageMetadata {
    init(from usage: OpenAIUsage) {
        self.init(
            inputTokens: usage.promptTokens,
            outputTokens: usage.completionTokens,
            totalTokens: usage.totalTokens
        )
    }
}
