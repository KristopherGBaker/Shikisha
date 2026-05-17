import Foundation

/// `ChatModel` for Anthropic's `/v1/messages` (Claude). Anthropic differs from OpenAI in
/// three ways this adapter handles transparently:
///
/// - System prompts live at the top level, not in the message list.
/// - Assistant content is an array of typed blocks (`text`, `tool_use`) rather than a string.
/// - Tool results come back in the next `user` turn as `tool_result` blocks.
public struct AnthropicChatModel: ChatModel {
    public let modelName: String
    public let config: AnthropicConfig
    public let maxTokens: Int
    public let temperature: Double?
    public let tools: [AnthropicToolSpecInput]?
    public let cacheSystem: Bool
    public let cacheTools: Bool
    public let httpClient: any HTTPClient
    public let callbacks: CallbackManager

    public init(
        config: AnthropicConfig,
        model: String,
        maxTokens: Int = 1024,
        temperature: Double? = nil,
        tools: [AnthropicToolSpecInput]? = nil,
        cacheSystem: Bool = false,
        cacheTools: Bool = false,
        httpClient: any HTTPClient = URLSessionHTTPClient(),
        callbacks: CallbackManager = .empty
    ) {
        self.config = config
        self.modelName = model
        self.maxTokens = maxTokens
        self.temperature = temperature
        self.tools = tools
        self.cacheSystem = cacheSystem
        self.cacheTools = cacheTools
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
            let decoded = try JSONDecoder().decode(AnthropicResponse.self, from: response.body)
            var content = ""
            var toolCalls: [ToolCall] = []
            for block in decoded.content {
                switch block {
                case .text(let text): content += text
                case .toolUse(let id, let name, let input):
                    toolCalls.append(ToolCall(id: id, name: name, arguments: input))
                }
            }
            let result = AIMessage(
                content: content,
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
                    var lastUsage: UsageMetadata?
                    for try await event in parseSSE(bytes) {
                        guard let data = event.data.data(using: .utf8),
                              let evt = try? JSONDecoder().decode(AnthropicStreamEvent.self, from: data) else {
                            continue
                        }
                        switch evt.type {
                        case "content_block_start":
                            guard let block = evt.contentBlock, block.type == "tool_use" else { break }
                            let chunk = AIMessageChunk(toolCallChunks: [
                                ToolCallChunk(index: evt.index ?? 0, id: block.id, name: block.name, argumentsBuffer: "")
                            ])
                            accumulator = accumulator + chunk
                            continuation.yield(chunk)
                        case "content_block_delta":
                            guard let delta = evt.delta else { break }
                            switch delta.type {
                            case "text_delta":
                                if let text = delta.text {
                                    let chunk = AIMessageChunk(content: text)
                                    accumulator = accumulator + chunk
                                    continuation.yield(chunk)
                                }
                            case "input_json_delta":
                                if let partial = delta.partialJSON {
                                    let chunk = AIMessageChunk(toolCallChunks: [
                                        ToolCallChunk(index: evt.index ?? 0, argumentsBuffer: partial)
                                    ])
                                    accumulator = accumulator + chunk
                                    continuation.yield(chunk)
                                }
                            default: break
                            }
                        case "message_delta":
                            if let usage = evt.usage { lastUsage = UsageMetadata(from: usage) }
                        case "message_stop":
                            if let usage = lastUsage {
                                let chunk = AIMessageChunk(usageMetadata: usage)
                                accumulator = accumulator + chunk
                                continuation.yield(chunk)
                                lastUsage = nil
                            }
                        default: break
                        }
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

    // MARK: - Request building

    private func makeRequest(messages: [any Message], stream: Bool) throws -> HTTPRequest {
        let (systemText, requestMessages) = splitSystemAndMessages(messages)
        let dto = AnthropicRequest(
            model: modelName,
            maxTokens: maxTokens,
            messages: requestMessages,
            system: makeSystem(systemText),
            temperature: temperature,
            tools: makeTools(),
            stream: stream ? true : nil
        )
        let body = try JSONEncoder().encode(dto)
        var headers = config.extraHeaders
        headers["x-api-key"] = config.apiKey
        headers["anthropic-version"] = config.version
        headers["Content-Type"] = "application/json"
        headers["Accept"] = stream ? "text/event-stream" : "application/json"
        let url = URL(string: "\(config.baseURL)/messages")!
        return HTTPRequest(method: .post, url: url, headers: headers, body: body)
    }

    private func splitSystemAndMessages(_ input: [any Message]) -> (String?, [AnthropicRequestMessage]) {
        let systemParts = input.compactMap { ($0 as? SystemMessage)?.content }
        let systemText = systemParts.isEmpty ? nil : systemParts.joined(separator: "\n\n")
        var messages: [AnthropicRequestMessage] = []
        for message in input where !(message is SystemMessage) {
            switch message {
            case let human as HumanMessage:
                messages.append(AnthropicRequestMessage(role: "user", content: humanContent(human)))
            case let ai as AIMessage:
                var blocks: [AnthropicContentBlock] = []
                if !ai.content.isEmpty {
                    blocks.append(.text(text: ai.content, cacheControl: nil))
                }
                for call in ai.toolCalls {
                    blocks.append(.toolUse(id: call.id, name: call.name, input: call.arguments, cacheControl: nil))
                }
                if !blocks.isEmpty {
                    messages.append(AnthropicRequestMessage(role: "assistant", content: blocks))
                }
            case let tool as ToolMessage:
                let block = AnthropicContentBlock.toolResult(
                    toolUseId: tool.toolCallId,
                    content: tool.content,
                    isError: tool.isError ? true : nil,
                    cacheControl: nil
                )
                if let last = messages.last, last.role == "user" {
                    messages[messages.count - 1] = AnthropicRequestMessage(role: "user", content: last.content + [block])
                } else {
                    messages.append(AnthropicRequestMessage(role: "user", content: [block]))
                }
            default: break
            }
        }
        return (systemText, messages)
    }

    private func humanContent(_ message: HumanMessage) -> [AnthropicContentBlock] {
        var blocks: [AnthropicContentBlock] = []
        if !message.content.isEmpty {
            blocks.append(.text(text: message.content, cacheControl: nil))
        }
        for attachment in message.attachments {
            switch attachment {
            case .imageBase64(let data, let mediaType, _):
                blocks.append(.image(source: .base64(mediaType: mediaType, data: data), cacheControl: nil))
            case .imageURL(let url, _):
                blocks.append(.image(source: .url(url), cacheControl: nil))
            }
        }
        if blocks.isEmpty {
            blocks.append(.text(text: "", cacheControl: nil))
        }
        return blocks
    }

    private func makeSystem(_ text: String?) -> AnthropicSystem? {
        guard let text, !text.isEmpty else { return nil }
        if cacheSystem {
            return .blocks([AnthropicSystemBlock(type: "text", text: text, cacheControl: AnthropicCacheControl())])
        }
        return .text(text)
    }

    private func makeTools() -> [AnthropicToolSpec]? {
        guard let tools, !tools.isEmpty else { return nil }
        let specs = tools.enumerated().map { index, tool in
            let isLast = index == tools.count - 1
            let cache = (cacheTools && isLast) ? AnthropicCacheControl() : nil
            return AnthropicToolSpec(
                name: tool.name,
                description: tool.description,
                inputSchema: tool.inputSchema,
                cacheControl: cache
            )
        }
        return specs
    }
}

/// Public tool specification used by `AnthropicChatModel`. Mirrors the wire shape but
/// without the cache-control field — caching is controlled by the `cacheTools` flag.
public struct AnthropicToolSpecInput: Sendable, Hashable {
    public let name: String
    public let description: String
    public let inputSchema: JSONValue

    public init(name: String, description: String, inputSchema: JSONValue) {
        self.name = name
        self.description = description
        self.inputSchema = inputSchema
    }
}
