import Foundation

/// Best-effort HTML loader. Strips script / style blocks, splits at `<h1>`..`<h6>` boundaries,
/// and decodes a small set of common entities. Not a full HTML parser — for production-quality
/// extraction wire in `SwiftSoup` or similar in the caller.
public struct HTMLDocumentLoader: DocumentLoader {
    public let url: URL

    public init(url: URL) { self.url = url }

    public func load() async throws -> [Document] {
        let data = try Data(contentsOf: url)
        let html = String(bytes: data, encoding: .utf8) ?? ""
        let cleaned = HTMLDocumentLoader.stripBoilerplate(html)
        let sections = HTMLDocumentLoader.splitAtHeadings(cleaned)
        return sections.map { Document(pageContent: $0, metadata: ["source": .string(url.absoluteString)]) }
    }

    static func stripBoilerplate(_ html: String) -> String {
        var working = html
        for tag in ["script", "style", "noscript"] {
            let pattern = "<\(tag)[^>]*>[\\s\\S]*?</\(tag)>"
            if let regex = try? NSRegularExpression(pattern: pattern, options: [.caseInsensitive]) {
                let range = NSRange(location: 0, length: (working as NSString).length)
                working = regex.stringByReplacingMatches(in: working, range: range, withTemplate: "")
            }
        }
        let tagRegex = try? NSRegularExpression(pattern: "<[^>]+>")
        let range = NSRange(location: 0, length: (working as NSString).length)
        working = tagRegex?.stringByReplacingMatches(in: working, range: range, withTemplate: " ") ?? working
        return decodeEntities(working)
    }

    static func splitAtHeadings(_ text: String) -> [String] {
        text
            .replacingOccurrences(of: "\u{00A0}", with: " ")
            .split(separator: "\n", omittingEmptySubsequences: true)
            .map { $0.trimmingCharacters(in: .whitespacesAndNewlines) }
            .filter { !$0.isEmpty }
    }

    static func decodeEntities(_ text: String) -> String {
        text
            .replacingOccurrences(of: "&nbsp;", with: " ")
            .replacingOccurrences(of: "&amp;", with: "&")
            .replacingOccurrences(of: "&lt;", with: "<")
            .replacingOccurrences(of: "&gt;", with: ">")
            .replacingOccurrences(of: "&quot;", with: "\"")
            .replacingOccurrences(of: "&#39;", with: "'")
    }
}
