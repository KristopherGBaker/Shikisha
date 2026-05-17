import Foundation

/// An HTTP request as Shikisha's providers express it. Method + URL + headers + body;
/// the client is responsible for actually performing it.
public struct HTTPRequest: Sendable {
    public enum Method: String, Sendable {
        case get = "GET"
        case post = "POST"
        case put = "PUT"
        case delete = "DELETE"
        case patch = "PATCH"
    }

    public var method: Method
    public var url: URL
    public var headers: [String: String]
    public var body: Data?
    public var timeout: TimeInterval

    public init(
        method: Method,
        url: URL,
        headers: [String: String] = [:],
        body: Data? = nil,
        timeout: TimeInterval = 60
    ) {
        self.method = method
        self.url = url
        self.headers = headers
        self.body = body
        self.timeout = timeout
    }
}

/// The response to a unary (non-streaming) HTTP call.
public struct HTTPResponse: Sendable {
    public let statusCode: Int
    public let headers: [String: String]
    public let body: Data

    public init(statusCode: Int, headers: [String: String], body: Data) {
        self.statusCode = statusCode
        self.headers = headers
        self.body = body
    }

    public var isSuccess: Bool { (200..<300).contains(statusCode) }

    public func bodyString() -> String { String(data: body, encoding: .utf8) ?? "" }
}

/// Errors raised by `HTTPClient` and provider adapters.
public enum HTTPError: Error, Sendable, Equatable, CustomStringConvertible {
    case transport(message: String)
    case status(code: Int, body: String)
    case decoding(message: String)

    public var description: String {
        switch self {
        case .transport(let message): return "transport error: \(message)"
        case .status(let code, let body): return "HTTP \(code): \(body)"
        case .decoding(let message): return "decoding error: \(message)"
        }
    }
}

/// Pluggable HTTP transport. Provider adapters depend on this protocol rather than
/// `URLSession` directly so tests can inject a stub.
public protocol HTTPClient: Sendable {
    func send(_ request: HTTPRequest) async throws -> HTTPResponse
    func stream(_ request: HTTPRequest) async throws -> (HTTPResponse, AsyncThrowingStream<Data, Error>)
}
