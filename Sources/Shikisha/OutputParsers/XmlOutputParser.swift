import Foundation

/// Minimal XML element. We do not aim to be a general-purpose XML parser — this handles
/// the small subset LLMs reliably emit: nested tags, text content, no attributes, no namespaces.
public struct XMLElement: Sendable, Hashable {
    public let name: String
    public let text: String
    public let children: [XMLElement]

    public init(name: String, text: String = "", children: [XMLElement] = []) {
        self.name = name
        self.text = text
        self.children = children
    }

    public func child(named name: String) -> XMLElement? {
        children.first { $0.name == name }
    }

    public func children(named name: String) -> [XMLElement] {
        children.filter { $0.name == name }
    }
}

public struct XmlOutputParser: Runnable {
    public typealias Input = AIMessage
    public typealias Output = XMLElement

    public init() {}

    public func invoke(_ input: AIMessage) async throws -> XMLElement {
        let text = stripCodeFence(input.content)
        var index = text.startIndex
        if let root = try parseElement(text, &index) {
            return root
        }
        throw HTTPError.decoding(message: "no XML element found in: \(text)")
    }

    private func parseElement(_ source: String, _ index: inout String.Index) throws -> XMLElement? {
        while index < source.endIndex, source[index].isWhitespace {
            index = source.index(after: index)
        }
        guard index < source.endIndex, source[index] == "<" else { return nil }
        index = source.index(after: index)
        var name = ""
        while index < source.endIndex, source[index] != ">", !source[index].isWhitespace {
            name.append(source[index])
            index = source.index(after: index)
        }
        // Skip until `>`
        while index < source.endIndex, source[index] != ">" {
            index = source.index(after: index)
        }
        guard index < source.endIndex else {
            throw HTTPError.decoding(message: "unterminated XML start tag")
        }
        index = source.index(after: index)

        var text = ""
        var children: [XMLElement] = []

        while index < source.endIndex {
            if source[index] == "<" {
                let lookahead = source.index(after: index)
                if lookahead < source.endIndex, source[lookahead] == "/" {
                    // Close tag — advance past `</name>`
                    while index < source.endIndex, source[index] != ">" {
                        index = source.index(after: index)
                    }
                    if index < source.endIndex { index = source.index(after: index) }
                    return XMLElement(
                        name: name,
                        text: text.trimmingCharacters(in: .whitespacesAndNewlines),
                        children: children
                    )
                }
                if let child = try parseElement(source, &index) {
                    children.append(child)
                }
            } else {
                text.append(source[index])
                index = source.index(after: index)
            }
        }
        return XMLElement(name: name, text: text.trimmingCharacters(in: .whitespacesAndNewlines), children: children)
    }
}
