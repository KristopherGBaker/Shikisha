import Foundation

/// `ChatModel` for Google Gemini via `:generateContent` / `:streamGenerateContent`.
///
/// Differences from OpenAI handled here:
/// - Assistant role is `model`, not `assistant`.
/// - System prompts live in top-level `systemInstruction`.
/// - Tool calls are `functionCall` parts; tool results round-trip as `functionResponse`.
public struct GoogleChatModel: ChatModel {
    public let modelName: String
    public let config: GoogleConfig
    public let temperature: Double?
    public let maxOutputTokens: Int?
    public let tools: [GoogleToolSpec]?
    public let httpClient: any HTTPClient
    public let callbacks: CallbackManager

    public init(
        config: GoogleConfig,
        model: String,
        temperature: Double? = nil,
        maxOutputTokens: Int? = nil,
        tools: [GoogleToolSpec]? = nil,
        httpClient: any HTTPClient = URLSessionHTTPClient(),
        callbacks: CallbackManager = .empty
    ) {
        self.config = config
        self.modelName = model
        self.temperature = temperature
        self.maxOutputTokens = maxOutputTokens
        self.tools = tools
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
            let decoded = try JSONDecoder().decode(GoogleGenerateContentResponse.self, from: response.body)
            let result = decoded.toAIMessage()
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
                        guard let data = event.data.data(using: .utf8),
                              let decoded = try? JSONDecoder().decode(GoogleGenerateContentResponse.self, from: data) else {
                            continue
                        }
                        let chunk = decoded.toAIMessageChunk()
                        accumulator = accumulator + chunk
                        continuation.yield(chunk)
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
        let systemText = messages
            .compactMap { ($0 as? SystemMessage)?.content }
            .joined(separator: "\n\n")
        var contents: [GoogleRequestContent] = []
        for message in messages where !(message is SystemMessage) {
            switch message {
            case let m as HumanMessage:
                contents.append(GoogleRequestContent(role: "user", parts: [.text(m.content)]))
            case let m as AIMessage:
                var parts: [GoogleRequestPart] = []
                if !m.content.isEmpty { parts.append(.text(m.content)) }
                for call in m.toolCalls {
                    parts.append(.functionCall(name: call.name, args: call.arguments))
                }
                if !parts.isEmpty {
                    contents.append(GoogleRequestContent(role: "model", parts: parts))
                }
            case let m as ToolMessage:
                contents.append(GoogleRequestContent(role: "user", parts: [
                    .functionResponse(name: m.name ?? m.toolCallId, response: .object(["result": .string(m.content)]))
                ]))
            default: break
            }
        }
        let request = GoogleGenerateContentRequest(
            contents: contents,
            systemInstruction: systemText.isEmpty ? nil : GoogleRequestContent(role: "system", parts: [.text(systemText)]),
            generationConfig: (temperature == nil && maxOutputTokens == nil)
                ? nil
                : GoogleGenerationConfig(temperature: temperature, maxOutputTokens: maxOutputTokens),
            tools: tools.map { [GoogleToolsBlock(functionDeclarations: $0.map(\.declaration))] }
        )
        let body = try JSONEncoder().encode(request)
        let path = stream ? ":streamGenerateContent?alt=sse&key=" : ":generateContent?key="
        let url = URL(string: "\(config.baseURL)/models/\(modelName)\(path)\(config.apiKey)")!
        let headers = [
            "Content-Type": "application/json",
            "Accept": stream ? "text/event-stream" : "application/json"
        ]
        return HTTPRequest(method: .post, url: url, headers: headers, body: body)
    }
}

/// Tool exposed to Gemini. The model lifts `name` / `description` / `parameters` from each
/// declaration verbatim.
public struct GoogleToolSpec: Sendable, Hashable {
    public let name: String
    public let description: String
    public let parameters: JSONValue

    public init(name: String, description: String, parameters: JSONValue) {
        self.name = name
        self.description = description
        self.parameters = parameters
    }

    var declaration: GoogleFunctionDeclaration {
        GoogleFunctionDeclaration(name: name, description: description, parameters: parameters)
    }
}

// MARK: - Wire DTOs

struct GoogleGenerateContentRequest: Encodable {
    let contents: [GoogleRequestContent]
    let systemInstruction: GoogleRequestContent?
    let generationConfig: GoogleGenerationConfig?
    let tools: [GoogleToolsBlock]?
}

struct GoogleGenerationConfig: Encodable {
    let temperature: Double?
    let maxOutputTokens: Int?
}

struct GoogleToolsBlock: Encodable {
    let functionDeclarations: [GoogleFunctionDeclaration]
}

struct GoogleFunctionDeclaration: Encodable {
    let name: String
    let description: String
    let parameters: JSONValue
}

struct GoogleRequestContent: Encodable {
    let role: String
    let parts: [GoogleRequestPart]
}

enum GoogleRequestPart: Encodable {
    case text(String)
    case functionCall(name: String, args: JSONValue)
    case functionResponse(name: String, response: JSONValue)

    private enum CodingKeys: String, CodingKey {
        case text
        case functionCall
        case functionResponse
    }

    func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        switch self {
        case .text(let value):
            try container.encode(value, forKey: .text)
        case .functionCall(let name, let args):
            try container.encode(GoogleFunctionCall(name: name, args: args), forKey: .functionCall)
        case .functionResponse(let name, let response):
            try container.encode(GoogleFunctionResponse(name: name, response: response), forKey: .functionResponse)
        }
    }
}

struct GoogleFunctionCall: Encodable, Decodable {
    let name: String
    let args: JSONValue
}

struct GoogleFunctionResponse: Encodable {
    let name: String
    let response: JSONValue
}

struct GoogleGenerateContentResponse: Decodable {
    let candidates: [Candidate]?
    let usageMetadata: GoogleUsageMetadata?

    struct Candidate: Decodable {
        let content: Content?
    }

    struct Content: Decodable {
        let role: String?
        let parts: [Part]?
    }

    struct Part: Decodable {
        let text: String?
        let functionCall: GoogleFunctionCall?
    }

    func toAIMessage() -> AIMessage {
        let parts = candidates?.first?.content?.parts ?? []
        var content = ""
        var toolCalls: [ToolCall] = []
        for (index, part) in parts.enumerated() {
            if let text = part.text { content += text }
            if let call = part.functionCall {
                toolCalls.append(ToolCall(id: "call-\(index)", name: call.name, arguments: call.args))
            }
        }
        return AIMessage(
            content: content,
            toolCalls: toolCalls,
            usageMetadata: usageMetadata.map(UsageMetadata.init(from:))
        )
    }

    func toAIMessageChunk() -> AIMessageChunk {
        let parts = candidates?.first?.content?.parts ?? []
        let content = parts.compactMap(\.text).joined()
        return AIMessageChunk(
            content: content,
            usageMetadata: usageMetadata.map(UsageMetadata.init(from:))
        )
    }
}

struct GoogleUsageMetadata: Decodable {
    let promptTokenCount: Int?
    let candidatesTokenCount: Int?
    let totalTokenCount: Int?
}

extension UsageMetadata {
    init(from usage: GoogleUsageMetadata) {
        self.init(
            inputTokens: usage.promptTokenCount ?? 0,
            outputTokens: usage.candidatesTokenCount ?? 0,
            totalTokens: usage.totalTokenCount
        )
    }
}
