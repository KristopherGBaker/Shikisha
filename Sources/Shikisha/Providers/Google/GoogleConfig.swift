import Foundation

/// Connection settings for Google's Gemini REST API
/// (`generativelanguage.googleapis.com/v1beta`).
public struct GoogleConfig: Sendable {
    public let apiKey: String
    public let baseURL: String

    public init(
        apiKey: String,
        baseURL: String = "https://generativelanguage.googleapis.com/v1beta"
    ) {
        self.apiKey = apiKey
        self.baseURL = baseURL
    }
}
