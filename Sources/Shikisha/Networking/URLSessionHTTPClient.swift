import Foundation

#if canImport(FoundationNetworking)
import FoundationNetworking
#endif

/// `URLSession`-backed `HTTPClient`. Default for every Shikisha provider on Apple
/// platforms; uses the session's `bytes(for:)` for streaming so backpressure works.
public struct URLSessionHTTPClient: HTTPClient {
    public let session: URLSession

    public init(session: URLSession = .shared) {
        self.session = session
    }

    public func send(_ request: HTTPRequest) async throws -> HTTPResponse {
        let urlRequest = makeURLRequest(request)
        do {
            let (data, response) = try await session.data(for: urlRequest)
            return Self.makeHTTPResponse(data: data, response: response)
        } catch {
            throw HTTPError.transport(message: error.localizedDescription)
        }
    }

    public func stream(_ request: HTTPRequest) async throws -> (HTTPResponse, AsyncThrowingStream<Data, Error>) {
        let urlRequest = makeURLRequest(request)
        let bytes: URLSession.AsyncBytes
        let response: URLResponse
        do {
            (bytes, response) = try await session.bytes(for: urlRequest)
        } catch {
            throw HTTPError.transport(message: error.localizedDescription)
        }
        let statusCode = (response as? HTTPURLResponse)?.statusCode ?? 0
        let headers = extractHeaders(response)
        let initialResponse = HTTPResponse(statusCode: statusCode, headers: headers, body: Data())

        if !(200..<300).contains(statusCode) {
            var collected = Data()
            for try await byte in bytes {
                collected.append(byte)
            }
            throw HTTPError.status(code: statusCode, body: String(data: collected, encoding: .utf8) ?? "")
        }

        let stream = AsyncThrowingStream<Data, Error> { continuation in
            let task = Task {
                do {
                    var lineBuffer = Data()
                    for try await byte in bytes {
                        lineBuffer.append(byte)
                        // Flush each chunk eagerly so downstream parsers can incrementally
                        // process. 4 KiB is a good balance for SSE/NDJSON traffic.
                        if lineBuffer.count >= 4096 {
                            continuation.yield(lineBuffer)
                            lineBuffer.removeAll(keepingCapacity: true)
                        }
                    }
                    if !lineBuffer.isEmpty {
                        continuation.yield(lineBuffer)
                    }
                    continuation.finish()
                } catch {
                    continuation.finish(throwing: error)
                }
            }
            continuation.onTermination = { _ in task.cancel() }
        }
        return (initialResponse, stream)
    }

    private func makeURLRequest(_ request: HTTPRequest) -> URLRequest {
        var urlRequest = URLRequest(url: request.url, timeoutInterval: request.timeout)
        urlRequest.httpMethod = request.method.rawValue
        for (key, value) in request.headers {
            urlRequest.setValue(value, forHTTPHeaderField: key)
        }
        urlRequest.httpBody = request.body
        return urlRequest
    }

    static func makeHTTPResponse(data: Data, response: URLResponse) -> HTTPResponse {
        let statusCode = (response as? HTTPURLResponse)?.statusCode ?? 0
        return HTTPResponse(statusCode: statusCode, headers: extractHeaders(response), body: data)
    }
}

private func extractHeaders(_ response: URLResponse) -> [String: String] {
    guard let http = response as? HTTPURLResponse else { return [:] }
    var headers: [String: String] = [:]
    for (key, value) in http.allHeaderFields {
        guard let key = key as? String, let value = value as? String else { continue }
        headers[key] = value
    }
    return headers
}

private func extractHeaders(_ response: URLResponse?) -> [String: String] {
    guard let response else { return [:] }
    return extractHeaders(response as URLResponse)
}
