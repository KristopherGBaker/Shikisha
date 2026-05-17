import Foundation

/// Connection settings for an OpenAI-compatible endpoint. The same struct configures
/// OpenAI proper, OpenRouter, Ollama's OpenAI-compatible shim, vLLM, and any service
/// that speaks the `/v1/chat/completions` shape.
public struct OpenAIConfig: Sendable {
    public let apiKey: String
    public let baseURL: String
    public let organization: String?
    public let extraHeaders: [String: String]

    public init(
        apiKey: String,
        baseURL: String = "https://api.openai.com/v1",
        organization: String? = nil,
        extraHeaders: [String: String] = [:]
    ) {
        self.apiKey = apiKey
        self.baseURL = baseURL
        self.organization = organization
        self.extraHeaders = extraHeaders
    }
}
