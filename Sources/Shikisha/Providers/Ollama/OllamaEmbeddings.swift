import Foundation

/// Embeddings via Ollama's native `/api/embed` endpoint. Pull a local model first:
///
/// ```sh
/// ollama pull nomic-embed-text
/// ```
public struct OllamaEmbeddings: Embeddings {
    public let modelName: String
    public let config: OllamaConfig
    public let httpClient: any HTTPClient

    public init(
        config: OllamaConfig = OllamaConfig(),
        model: String = "nomic-embed-text",
        httpClient: any HTTPClient = URLSessionHTTPClient()
    ) {
        self.config = config
        self.modelName = model
        self.httpClient = httpClient
    }

    public func embedDocuments(_ texts: [String]) async throws -> [[Float]] {
        guard !texts.isEmpty else { return [] }
        let body = try JSONEncoder().encode(EmbedRequest(model: modelName, input: texts))
        var headers = config.extraHeaders
        headers["Content-Type"] = "application/json"
        let request = HTTPRequest(
            method: .post,
            url: URL(string: "\(config.baseURL)/api/embed")!,
            headers: headers,
            body: body
        )
        let response = try await httpClient.send(request)
        guard response.isSuccess else {
            throw HTTPError.status(code: response.statusCode, body: response.bodyString())
        }
        let decoded = try JSONDecoder().decode(EmbedResponse.self, from: response.body)
        return decoded.embeddings
    }

    private struct EmbedRequest: Encodable {
        let model: String
        let input: [String]
    }

    private struct EmbedResponse: Decodable {
        let model: String?
        let embeddings: [[Float]]
    }
}
