import Foundation

/// Connection settings for Anthropic's `/v1/messages` endpoint. `version` is the value
/// of the `anthropic-version` header; update if you need a newer behavior.
public struct AnthropicConfig: Sendable {
    public let apiKey: String
    public let baseURL: String
    public let version: String
    public let extraHeaders: [String: String]

    public init(
        apiKey: String,
        baseURL: String = "https://api.anthropic.com/v1",
        version: String = "2023-06-01",
        extraHeaders: [String: String] = [:]
    ) {
        self.apiKey = apiKey
        self.baseURL = baseURL
        self.version = version
        self.extraHeaders = extraHeaders
    }
}
