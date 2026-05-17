import Foundation

/// Connection settings for a local Ollama server. Defaults to `http://localhost:11434`.
public struct OllamaConfig: Sendable {
    public let baseURL: String
    public let extraHeaders: [String: String]

    public init(baseURL: String = "http://localhost:11434", extraHeaders: [String: String] = [:]) {
        self.baseURL = baseURL
        self.extraHeaders = extraHeaders
    }
}
