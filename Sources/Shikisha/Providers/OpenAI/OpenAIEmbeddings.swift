import Foundation

/// Embedding model targeting OpenAI's `/embeddings` endpoint (and any OpenAI-compatible
/// shim — Ollama's `/v1/embeddings`, OpenRouter, …).
public struct OpenAIEmbeddings: Embeddings {
    public let modelName: String
    public let dimensions: Int?
    public let config: OpenAIConfig
    public let httpClient: any HTTPClient

    public init(
        config: OpenAIConfig,
        model: String,
        dimensions: Int? = nil,
        httpClient: any HTTPClient = URLSessionHTTPClient()
    ) {
        self.config = config
        self.modelName = model
        self.dimensions = dimensions
        self.httpClient = httpClient
    }

    public func embedDocuments(_ texts: [String]) async throws -> [[Float]] {
        guard !texts.isEmpty else { return [] }
        let request = try makeRequest(texts: texts)
        let response = try await httpClient.send(request)
        guard response.isSuccess else {
            throw HTTPError.status(code: response.statusCode, body: response.bodyString())
        }
        let decoded = try JSONDecoder().decode(EmbeddingResponse.self, from: response.body)
        return decoded.data
            .sorted { $0.index < $1.index }
            .map { $0.embedding.map(Float.init) }
    }

    private func makeRequest(texts: [String]) throws -> HTTPRequest {
        let body: Data
        if let dimensions {
            body = try JSONEncoder().encode(RequestWithDimensions(
                model: modelName,
                input: texts,
                dimensions: dimensions
            ))
        } else {
            body = try JSONEncoder().encode(RequestPayload(model: modelName, input: texts))
        }
        var headers = config.extraHeaders
        headers["Authorization"] = "Bearer \(config.apiKey)"
        headers["Content-Type"] = "application/json"
        if let organization = config.organization {
            headers["OpenAI-Organization"] = organization
        }
        let url = URL(string: "\(config.baseURL)/embeddings")!
        return HTTPRequest(method: .post, url: url, headers: headers, body: body)
    }

    private struct RequestPayload: Encodable {
        let model: String
        let input: [String]
    }

    private struct RequestWithDimensions: Encodable {
        let model: String
        let input: [String]
        let dimensions: Int
    }

    private struct EmbeddingResponse: Decodable {
        let data: [Item]

        struct Item: Decodable {
            let index: Int
            let embedding: [Double]
        }
    }
}
