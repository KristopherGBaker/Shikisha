import Foundation

/// Extract the text content from an `AIMessage`. The simplest, most useful tail of any chain
/// that ends with a chat model.
public struct StringOutputParser: Runnable {
    public typealias Input = AIMessage
    public typealias Output = String

    public init() {}

    public func invoke(_ input: AIMessage) async throws -> String {
        input.content
    }
}

/// Parse the text content of an `AIMessage` and decode it as JSON.
public struct JSONOutputParser: Runnable {
    public typealias Input = AIMessage
    public typealias Output = JSONValue

    public init() {}

    public func invoke(_ input: AIMessage) async throws -> JSONValue {
        let stripped = stripCodeFence(input.content)
        guard let value = JSONValue.parse(stripped) else {
            throw HTTPError.decoding(message: "JSON parse failed: \(stripped)")
        }
        return value
    }
}

/// Parse the text content of an `AIMessage` and decode it as `Output`. Pair with OpenAI's
/// strict JSON Schema mode for guaranteed-shape responses.
public struct StructuredOutputParser<Output: Decodable & Sendable>: Runnable {
    public typealias Input = AIMessage

    public let decoder: JSONDecoder

    public init(decoder: JSONDecoder = JSONDecoder()) {
        self.decoder = decoder
    }

    public func invoke(_ input: AIMessage) async throws -> Output {
        let stripped = stripCodeFence(input.content)
        guard let data = stripped.data(using: .utf8) else {
            throw HTTPError.decoding(message: "content was not valid UTF-8")
        }
        do {
            return try decoder.decode(Output.self, from: data)
        } catch {
            throw HTTPError.decoding(message: "structured output decode failed: \(error)")
        }
    }
}
