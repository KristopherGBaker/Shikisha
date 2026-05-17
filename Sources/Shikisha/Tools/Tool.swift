import Foundation

/// A tool the model can request. `inputSchema` is a JSON Schema describing the expected
/// arguments object; the runtime parses tool-call arguments against it before invoking `execute`.
public protocol Tool: Sendable {
    var name: String { get }
    var description: String { get }
    var inputSchema: JSONValue { get }

    /// Run the tool. Arguments arrive as parsed JSON; results are returned as a single
    /// string that the model will read back via `ToolMessage`.
    func execute(arguments: JSONValue) async throws -> String
}

/// Wrap a plain closure as a `Tool`.
public struct SimpleTool: Tool {
    public let name: String
    public let description: String
    public let inputSchema: JSONValue
    private let body: @Sendable (JSONValue) async throws -> String

    public init(
        name: String,
        description: String,
        inputSchema: JSONValue,
        execute: @Sendable @escaping (JSONValue) async throws -> String
    ) {
        self.name = name
        self.description = description
        self.inputSchema = inputSchema
        self.body = execute
    }

    public func execute(arguments: JSONValue) async throws -> String {
        try await body(arguments)
    }
}

/// Type-safe tool with a `Decodable` argument struct. The runtime decodes once and hands you a
/// typed value — no `JSONValue` switch / cast dance.
public struct TypedTool<Arguments: Decodable & Sendable>: Tool {
    public let name: String
    public let description: String
    public let inputSchema: JSONValue
    private let body: @Sendable (Arguments) async throws -> String

    public init(
        name: String,
        description: String,
        inputSchema: JSONValue,
        execute: @Sendable @escaping (Arguments) async throws -> String
    ) {
        self.name = name
        self.description = description
        self.inputSchema = inputSchema
        self.body = execute
    }

    public func execute(arguments: JSONValue) async throws -> String {
        let data = arguments.serialized().data(using: .utf8) ?? Data()
        let decoded = try JSONDecoder().decode(Arguments.self, from: data)
        return try await body(decoded)
    }
}

/// Locate and dispatch tools by name.
public struct ToolExecutor: Sendable {
    public let tools: [String: any Tool]

    public init(tools: [any Tool]) {
        self.tools = Dictionary(uniqueKeysWithValues: tools.map { ($0.name, $0) })
    }

    /// Run a `ToolCall` against the registered tools. Returns a `ToolMessage` wrapping the
    /// result string (or an error string with `isError: true`).
    public func run(_ call: ToolCall, callbacks: CallbackManager = .empty) async -> ToolMessage {
        guard let tool = tools[call.name] else {
            return ToolMessage(content: "Tool not found: \(call.name)", toolCallId: call.id, isError: true)
        }
        await callbacks.onToolStart(name: call.name, arguments: call.arguments)
        do {
            let result = try await tool.execute(arguments: call.arguments)
            await callbacks.onToolEnd(name: call.name, result: result)
            return ToolMessage(content: result, toolCallId: call.id, name: call.name)
        } catch {
            await callbacks.onToolError(name: call.name, error: error)
            return ToolMessage(content: "\(error)", toolCallId: call.id, name: call.name, isError: true)
        }
    }
}

public extension Tool {
    /// Render this tool as an OpenAI-style `{type: "function", function: {...}}` spec.
    func toOpenAISpec() -> JSONValue {
        .object([
            "type": .string("function"),
            "function": .object([
                "name": .string(name),
                "description": .string(description),
                "parameters": inputSchema
            ])
        ])
    }

    /// Render this tool as an Anthropic `{name, description, input_schema}` spec.
    func toAnthropicSpec() -> AnthropicToolSpecInput {
        AnthropicToolSpecInput(name: name, description: description, inputSchema: inputSchema)
    }

    /// Render this tool as a Google Gemini `FunctionDeclaration`.
    func toGoogleSpec() -> GoogleToolSpec {
        GoogleToolSpec(name: name, description: description, parameters: inputSchema)
    }
}
