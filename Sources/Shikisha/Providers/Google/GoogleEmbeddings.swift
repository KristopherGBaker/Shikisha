import Foundation

/// Embeddings via Google Gemini's `:batchEmbedContents` endpoint. Default model is
/// `text-embedding-004` (768-dim vectors). The endpoint accepts up to 100 inputs per
/// request — callers passing larger batches should chunk themselves.
public struct GoogleEmbeddings: Embeddings {
    public let modelName: String
    public let config: GoogleConfig
    public let httpClient: any HTTPClient

    public init(
        config: GoogleConfig,
        model: String = "text-embedding-004",
        httpClient: any HTTPClient = URLSessionHTTPClient()
    ) {
        self.config = config
        self.modelName = model
        self.httpClient = httpClient
    }

    public func embedDocuments(_ texts: [String]) async throws -> [[Float]] {
        guard !texts.isEmpty else { return [] }
        let request = BatchEmbedRequest(
            requests: texts.map { text in
                EmbedRequest(
                    model: "models/\(modelName)",
                    content: EmbedContent(parts: [EmbedPart(text: text)])
                )
            }
        )
        let body = try JSONEncoder().encode(request)
        let url = URL(string: "\(config.baseURL)/models/\(modelName):batchEmbedContents?key=\(config.apiKey)")!
        let httpRequest = HTTPRequest(
            method: .post,
            url: url,
            headers: ["Content-Type": "application/json"],
            body: body
        )
        let response = try await httpClient.send(httpRequest)
        guard response.isSuccess else {
            throw HTTPError.status(code: response.statusCode, body: response.bodyString())
        }
        let decoded = try JSONDecoder().decode(BatchEmbedResponse.self, from: response.body)
        return decoded.embeddings.map { $0.values.map(Float.init) }
    }

    private struct BatchEmbedRequest: Encodable {
        let requests: [EmbedRequest]
    }

    private struct EmbedRequest: Encodable {
        let model: String
        let content: EmbedContent
    }

    private struct EmbedContent: Encodable {
        let parts: [EmbedPart]
    }

    private struct EmbedPart: Encodable {
        let text: String
    }

    private struct BatchEmbedResponse: Decodable {
        let embeddings: [EmbeddingValues]
    }

    private struct EmbeddingValues: Decodable {
        let values: [Double]
    }
}
