import Foundation

/// Split a Markdown document at heading boundaries and stash the cumulative header path in
/// metadata. Each output `Document` has `h1`, `h2`, … keys for the headers it lives under.
public struct MarkdownHeaderTextSplitter: Sendable {
    public let headersToSplitOn: [(prefix: String, key: String)]

    public init(headersToSplitOn: [(prefix: String, key: String)] = [
        (prefix: "#", key: "h1"),
        (prefix: "##", key: "h2"),
        (prefix: "###", key: "h3")
    ]) {
        // Sort longest-prefix first so `##` doesn't get matched as `#`.
        self.headersToSplitOn = headersToSplitOn.sorted { $0.prefix.count > $1.prefix.count }
    }

    public func splitText(_ text: String) -> [Document] {
        var currentMetadata: [String: JSONValue] = [:]
        var currentChunk: [String] = []
        var documents: [Document] = []
        var openHeaderStack: [(level: Int, key: String)] = []

        func flush() {
            let joined = currentChunk.joined(separator: "\n").trimmingCharacters(in: .whitespacesAndNewlines)
            guard !joined.isEmpty else { currentChunk = []; return }
            documents.append(Document(pageContent: joined, metadata: currentMetadata))
            currentChunk = []
        }

        for line in text.split(separator: "\n", omittingEmptySubsequences: false).map(String.init) {
            let trimmed = line.trimmingCharacters(in: .whitespaces)
            if let header = matchHeader(line: trimmed) {
                flush()
                // Pop any headers at this or deeper level out of the cumulative metadata.
                while let last = openHeaderStack.last, last.level >= header.level {
                    currentMetadata.removeValue(forKey: last.key)
                    openHeaderStack.removeLast()
                }
                currentMetadata[header.key] = .string(header.text)
                openHeaderStack.append((level: header.level, key: header.key))
            } else {
                currentChunk.append(line)
            }
        }
        flush()
        return documents
    }

    private func matchHeader(line: String) -> (level: Int, key: String, text: String)? {
        for (index, candidate) in headersToSplitOn.enumerated() {
            let prefix = candidate.prefix + " "
            if line.hasPrefix(prefix) {
                let text = String(line.dropFirst(prefix.count)).trimmingCharacters(in: .whitespaces)
                let level = headersToSplitOn.count - index
                return (level: level, key: candidate.key, text: text)
            }
        }
        return nil
    }
}
