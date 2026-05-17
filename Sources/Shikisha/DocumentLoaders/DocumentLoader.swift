import Foundation

/// Async source of `Document`s. Implementations cover text, markdown, JSON, CSV, HTML, PDF.
public protocol DocumentLoader: Sendable {
    func load() async throws -> [Document]
}
