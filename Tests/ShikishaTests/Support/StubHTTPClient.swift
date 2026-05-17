import Foundation
@testable import Shikisha

/// A test double that returns canned `HTTPResponse`s by URL path. Records each request for
/// later assertions. Mutation isn't synchronized — tests drive the stub from a single task
/// at a time, which is sufficient for our suite.
final class StubHTTPClient: HTTPClient, @unchecked Sendable {
    nonisolated(unsafe) private var responses: [String: HTTPResponse] = [:]
    nonisolated(unsafe) private var streamingResponses: [String: (HTTPResponse, [String])] = [:]
    nonisolated(unsafe) private(set) var requests: [HTTPRequest] = []

    init() {}

    func register(path: String, response: HTTPResponse) {
        responses[path] = response
    }

    func register(path: String, status: Int = 200, body: String) {
        register(path: path, response: HTTPResponse(
            statusCode: status,
            headers: ["Content-Type": "application/json"],
            body: Data(body.utf8)
        ))
    }

    func registerStreaming(path: String, status: Int = 200, lines: [String]) {
        let response = HTTPResponse(statusCode: status, headers: ["Content-Type": "text/event-stream"], body: Data())
        streamingResponses[path] = (response, lines)
    }

    func send(_ request: HTTPRequest) async throws -> HTTPResponse {
        requests.append(request)
        guard let response = responses[request.url.path] ?? responses[request.url.absoluteString] else {
            throw HTTPError.transport(message: "no stub registered for \(request.url.path)")
        }
        return response
    }

    func stream(_ request: HTTPRequest) async throws -> (HTTPResponse, AsyncThrowingStream<Data, Error>) {
        requests.append(request)
        guard let payload = streamingResponses[request.url.path] ?? streamingResponses[request.url.absoluteString] else {
            throw HTTPError.transport(message: "no stub stream registered for \(request.url.path)")
        }
        let (response, lines) = payload
        let stream = AsyncThrowingStream<Data, Error> { continuation in
            for line in lines {
                continuation.yield(Data("\(line)\n".utf8))
            }
            continuation.finish()
        }
        return (response, stream)
    }
}
