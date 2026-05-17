import Foundation

/// `ChatModel` targeting Ollama's native `/api/chat` endpoint. Streaming is NDJSON — one
/// JSON object per line, terminated by a frame with `done: true`.
public struct OllamaChatModel: ChatModel {
    public let modelName: String
    public let config: OllamaConfig
    public let temperature: Double?
    public let numPredict: Int?
    public let tools: [JSONValue]?
    public let format: JSONValue?
    public let httpClient: any HTTPClient
    public let callbacks: CallbackManager

    public init(
        config: OllamaConfig = OllamaConfig(),
        model: String,
        temperature: Double? = nil,
        numPredict: Int? = nil,
        tools: [JSONValue]? = nil,
        format: JSONValue? = nil,
        httpClient: any HTTPClient = URLSessionHTTPClient(),
        callbacks: CallbackManager = .empty
    ) {
        self.config = config
        self.modelName = model
        self.temperature = temperature
        self.numPredict = numPredict
        self.tools = tools
        self.format = format
        self.httpClient = httpClient
        self.callbacks = callbacks
    }

    public func invoke(_ input: [any Message]) async throws -> AIMessage {
        await callbacks.onLLMStart(model: modelName, messages: input)
        do {
            let request = try makeRequest(messages: input, stream: false)
            let response = try await httpClient.send(request)
            guard response.isSuccess else {
                throw HTTPError.status(code: response.statusCode, body: response.bodyString())
            }
            let decoded = try JSONDecoder().decode(OllamaChatResponse.self, from: response.body)
            guard let message = decoded.message else {
                throw HTTPError.decoding(message: "Ollama returned no message")
            }
            let toolCalls = (message.toolCalls ?? []).enumerated().map { index, call in
                ToolCall(id: "call_\(index)", name: call.function.name, arguments: call.function.arguments)
            }
            let result = AIMessage(
                content: message.content,
                toolCalls: toolCalls,
                usageMetadata: decoded.usage
            )
            await callbacks.onLLMEnd(model: modelName, response: result)
            return result
        } catch {
            await callbacks.onLLMError(model: modelName, error: error)
            throw error
        }
    }

    public func stream(_ messages: [any Message]) -> AsyncThrowingStream<AIMessageChunk, Error> {
        AsyncThrowingStream { continuation in
            let task = Task {
                do {
                    await callbacks.onLLMStart(model: modelName, messages: messages)
                    let request = try makeRequest(messages: messages, stream: true)
                    let (response, bytes) = try await httpClient.stream(request)
                    guard response.isSuccess else {
                        throw HTTPError.status(code: response.statusCode, body: response.bodyString())
                    }
                    var accumulator = AIMessageChunk()
                    for try await frame in parseNDJSON(bytes) {
                        guard let decoded = try? JSONDecoder().decode(OllamaChatResponse.self, from: frame) else {
                            continue
                        }
                        let chunk = AIMessageChunk(
                            content: decoded.message?.content ?? "",
                            usageMetadata: decoded.done ? decoded.usage : nil
                        )
                        accumulator = accumulator + chunk
                        continuation.yield(chunk)
                        if decoded.done { break }
                    }
                    await callbacks.onLLMEnd(model: modelName, response: accumulator.toAIMessage())
                    continuation.finish()
                } catch {
                    await callbacks.onLLMError(model: modelName, error: error)
                    continuation.finish(throwing: error)
                }
            }
            continuation.onTermination = { _ in task.cancel() }
        }
    }

    private func makeRequest(messages: [any Message], stream: Bool) throws -> HTTPRequest {
        let dto = OllamaChatRequest(
            model: modelName,
            messages: messages.map { encode(message: $0) },
            stream: stream,
            options: (temperature != nil || numPredict != nil)
                ? OllamaOptions(temperature: temperature, numPredict: numPredict)
                : nil,
            tools: tools,
            format: format
        )
        let body = try JSONEncoder().encode(dto)
        var headers = config.extraHeaders
        headers["Content-Type"] = "application/json"
        let url = URL(string: "\(config.baseURL)/api/chat")!
        return HTTPRequest(method: .post, url: url, headers: headers, body: body)
    }
}

private func encode(message: any Message) -> OllamaRequestMessage {
    switch message {
    case let m as HumanMessage:
        return OllamaRequestMessage(role: "user", content: m.content, toolCalls: nil)
    case let m as SystemMessage:
        return OllamaRequestMessage(role: "system", content: m.content, toolCalls: nil)
    case let m as AIMessage:
        let calls = m.toolCalls.isEmpty ? nil : m.toolCalls.map { call in
            OllamaRequestToolCall(function: OllamaRequestToolCallFunction(name: call.name, arguments: call.arguments))
        }
        return OllamaRequestMessage(role: "assistant", content: m.content, toolCalls: calls)
    case let m as ToolMessage:
        return OllamaRequestMessage(role: "tool", content: m.content, toolCalls: nil)
    default:
        return OllamaRequestMessage(role: message.role.rawValue, content: message.content, toolCalls: nil)
    }
}

// MARK: - Wire DTOs

struct OllamaChatRequest: Encodable {
    let model: String
    let messages: [OllamaRequestMessage]
    let stream: Bool
    let options: OllamaOptions?
    let tools: [JSONValue]?
    let format: JSONValue?
}

struct OllamaOptions: Encodable {
    let temperature: Double?
    let numPredict: Int?

    enum CodingKeys: String, CodingKey {
        case temperature
        case numPredict = "num_predict"
    }
}

struct OllamaRequestMessage: Encodable {
    let role: String
    let content: String
    let toolCalls: [OllamaRequestToolCall]?

    enum CodingKeys: String, CodingKey {
        case role
        case content
        case toolCalls = "tool_calls"
    }
}

struct OllamaRequestToolCall: Encodable {
    let function: OllamaRequestToolCallFunction
}

struct OllamaRequestToolCallFunction: Encodable {
    let name: String
    let arguments: JSONValue
}

struct OllamaChatResponse: Decodable {
    let model: String?
    let message: OllamaResponseMessage?
    let done: Bool
    let promptEvalCount: Int?
    let evalCount: Int?

    enum CodingKeys: String, CodingKey {
        case model
        case message
        case done
        case promptEvalCount = "prompt_eval_count"
        case evalCount = "eval_count"
    }

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        self.model = try container.decodeIfPresent(String.self, forKey: .model)
        self.message = try container.decodeIfPresent(OllamaResponseMessage.self, forKey: .message)
        self.done = (try container.decodeIfPresent(Bool.self, forKey: .done)) ?? false
        self.promptEvalCount = try container.decodeIfPresent(Int.self, forKey: .promptEvalCount)
        self.evalCount = try container.decodeIfPresent(Int.self, forKey: .evalCount)
    }

    var usage: UsageMetadata? {
        guard promptEvalCount != nil || evalCount != nil else { return nil }
        let input = promptEvalCount ?? 0
        let output = evalCount ?? 0
        return UsageMetadata(inputTokens: input, outputTokens: output)
    }
}

struct OllamaResponseMessage: Decodable {
    let role: String
    let content: String
    let toolCalls: [OllamaResponseToolCall]?

    enum CodingKeys: String, CodingKey {
        case role
        case content
        case toolCalls = "tool_calls"
    }
}

struct OllamaResponseToolCall: Decodable {
    let function: OllamaResponseToolCallFunction
}

struct OllamaResponseToolCallFunction: Decodable {
    let name: String
    let arguments: JSONValue
}
