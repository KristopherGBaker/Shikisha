import Foundation

/// `ChatModel` targeting OpenAI's `/chat/completions` and any compatible endpoint
/// (OpenRouter, vLLM, Ollama OpenAI shim) via configurable `baseURL`.
public struct OpenAIChatModel: ChatModel {
    public let modelName: String
    public let config: OpenAIConfig
    public let temperature: Double?
    public let maxTokens: Int?
    public let tools: [JSONValue]?
    public let responseFormat: JSONValue?
    public let httpClient: any HTTPClient
    public let callbacks: CallbackManager

    public init(
        config: OpenAIConfig,
        model: String,
        temperature: Double? = nil,
        maxTokens: Int? = nil,
        tools: [JSONValue]? = nil,
        responseFormat: JSONValue? = nil,
        httpClient: any HTTPClient = URLSessionHTTPClient(),
        callbacks: CallbackManager = .empty
    ) {
        self.config = config
        self.modelName = model
        self.temperature = temperature
        self.maxTokens = maxTokens
        self.tools = tools
        self.responseFormat = responseFormat
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
            let decoded = try JSONDecoder().decode(OpenAIResponse.self, from: response.body)
            guard let choice = decoded.choices.first else {
                throw HTTPError.decoding(message: "OpenAI returned no choices")
            }
            let toolCalls = (choice.message.toolCalls ?? []).map { call in
                ToolCall(
                    id: call.id,
                    name: call.function.name,
                    arguments: JSONValue.parse(call.function.arguments) ?? .object([:])
                )
            }
            let result = AIMessage(
                content: choice.message.content ?? "",
                toolCalls: toolCalls,
                usageMetadata: decoded.usage.map(UsageMetadata.init(from:)),
                id: decoded.id
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
                    for try await event in parseSSE(bytes) {
                        let payload = event.data
                        if payload == "[DONE]" { break }
                        guard let data = payload.data(using: .utf8),
                              let chunk = try? JSONDecoder().decode(OpenAIStreamChunk.self, from: data) else {
                            continue
                        }
                        let choice = chunk.choices.first
                        let deltaContent = choice?.delta?.content ?? ""
                        let deltaToolCalls = (choice?.delta?.toolCalls ?? []).map { call in
                            ToolCallChunk(
                                index: call.index,
                                id: call.id,
                                name: call.function?.name,
                                argumentsBuffer: call.function?.arguments ?? ""
                            )
                        }
                        let usage = chunk.usage.map(UsageMetadata.init(from:))
                        let next = AIMessageChunk(
                            content: deltaContent,
                            toolCallChunks: deltaToolCalls,
                            usageMetadata: usage,
                            id: chunk.id
                        )
                        accumulator += next
                        continuation.yield(next)
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

    func makeRequest(messages: [any Message], stream: Bool) throws -> HTTPRequest {
        let dto = OpenAIRequest(
            model: modelName,
            messages: messages.map { encode(message: $0) },
            temperature: temperature,
            maxCompletionTokens: maxTokens,
            tools: tools,
            stream: stream ? true : nil,
            responseFormat: responseFormat,
            streamOptions: stream ? .init(includeUsage: true) : nil
        )
        let encoder = JSONEncoder()
        encoder.outputFormatting = []
        let body = try encoder.encode(dto)
        var headers = config.extraHeaders
        headers["Authorization"] = "Bearer \(config.apiKey)"
        headers["Content-Type"] = "application/json"
        headers["Accept"] = stream ? "text/event-stream" : "application/json"
        if let organization = config.organization {
            headers["OpenAI-Organization"] = organization
        }
        let url = URL(string: "\(config.baseURL)/chat/completions")!
        return HTTPRequest(method: .post, url: url, headers: headers, body: body)
    }
}

func encode(message: any Message) -> OpenAIRequestMessage {
    switch message {
    case let m as SystemMessage:
        return OpenAIRequestMessage(role: "system", content: .text(m.content), name: m.name, toolCalls: nil, toolCallId: nil)
    case let m as HumanMessage:
        let content: OpenAIContent
        if m.attachments.isEmpty {
            content = .text(m.content)
        } else {
            var parts: [OpenAIContentPart] = []
            if !m.content.isEmpty {
                parts.append(.init(type: "text", text: m.content, imageURL: nil))
            }
            for attachment in m.attachments {
                switch attachment {
                case .imageURL(let url, let detail):
                    parts.append(.init(
                        type: "image_url",
                        text: nil,
                        imageURL: .init(url: url, detail: detail?.rawValue)
                    ))
                case .imageBase64(let data, let mediaType, let detail):
                    let url = "data:\(mediaType);base64,\(data)"
                    parts.append(.init(
                        type: "image_url",
                        text: nil,
                        imageURL: .init(url: url, detail: detail?.rawValue)
                    ))
                }
            }
            content = .parts(parts)
        }
        return OpenAIRequestMessage(role: "user", content: content, name: m.name, toolCalls: nil, toolCallId: nil)
    case let m as AIMessage:
        let toolCalls = m.toolCalls.isEmpty ? nil : m.toolCalls.map { call in
            OpenAIRequestToolCall(
                id: call.id,
                type: "function",
                function: OpenAIRequestToolFunction(name: call.name, arguments: call.arguments.serialized())
            )
        }
        let content: OpenAIContent? = m.content.isEmpty ? nil : .text(m.content)
        return OpenAIRequestMessage(role: "assistant", content: content, name: m.name, toolCalls: toolCalls, toolCallId: nil)
    case let m as ToolMessage:
        return OpenAIRequestMessage(role: "tool", content: .text(m.content), name: m.name, toolCalls: nil, toolCallId: m.toolCallId)
    default:
        return OpenAIRequestMessage(role: message.role.rawValue, content: .text(message.content), name: message.name, toolCalls: nil, toolCallId: nil)
    }
}

// MARK: - Response format helpers

public enum OpenAIResponseFormat {
    /// `response_format: {type: "json_object"}` — model emits valid JSON, no schema enforcement.
    public static func jsonObject() -> JSONValue {
        .object(["type": .string("json_object")])
    }

    /// `response_format: {type: "json_schema", json_schema: {...}}` — strict JSON Schema mode.
    /// Pass a schema built via `JSONSchema.object(...)`.
    public static func jsonSchema(name: String, schema: JSONValue, strict: Bool = true) -> JSONValue {
        .object([
            "type": .string("json_schema"),
            "json_schema": .object([
                "name": .string(name),
                "strict": .bool(strict),
                "schema": schema
            ])
        ])
    }
}
