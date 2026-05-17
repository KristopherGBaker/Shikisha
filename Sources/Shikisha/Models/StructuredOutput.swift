import Foundation

/// A Runnable that invokes a chat model and decodes the JSON response into `Output`.
/// Pair with OpenAI's `response_format: json_schema` for byte-perfect structured output;
/// otherwise the model must reliably emit JSON for the decode to succeed.
public struct StructuredOutputRunnable<Model: ChatModel, Output: Decodable & Sendable>: Runnable {
    public typealias Input = [any Message]

    private let model: Model
    private let decoder: JSONDecoder

    public init(model: Model, decoder: JSONDecoder = JSONDecoder()) {
        self.model = model
        self.decoder = decoder
    }

    public func invoke(_ input: Input) async throws -> Output {
        let response = try await model.invoke(input)
        let trimmed = stripCodeFence(response.content)
        guard let data = trimmed.data(using: .utf8) else {
            throw HTTPError.decoding(message: "response was not valid UTF-8")
        }
        do {
            return try decoder.decode(Output.self, from: data)
        } catch {
            throw HTTPError.decoding(message: "structured output decode failed: \(error)")
        }
    }
}

public extension ChatModel {
    /// Build a `Runnable<[any Message], T>` that decodes the model's response as `T`.
    func asStructuredOutput<T: Decodable & Sendable>(
        _ type: T.Type = T.self,
        decoder: JSONDecoder = JSONDecoder()
    ) -> StructuredOutputRunnable<Self, T> {
        StructuredOutputRunnable(model: self, decoder: decoder)
    }
}

/// Trim ```json fences and leading/trailing whitespace. Some models wrap structured
/// output in code fences even when asked not to.
func stripCodeFence(_ raw: String) -> String {
    let trimmed = raw.trimmingCharacters(in: .whitespacesAndNewlines)
    guard trimmed.hasPrefix("```") else { return trimmed }
    var lines = trimmed.split(separator: "\n", omittingEmptySubsequences: false).map(String.init)
    if !lines.isEmpty { lines.removeFirst() }
    if lines.last?.trimmingCharacters(in: .whitespaces).hasPrefix("```") == true {
        lines.removeLast()
    }
    return lines.joined(separator: "\n").trimmingCharacters(in: .whitespacesAndNewlines)
}
