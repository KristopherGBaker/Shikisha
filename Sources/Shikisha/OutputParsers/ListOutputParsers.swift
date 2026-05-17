import Foundation

/// Comma-separated list. Splits on `,`, trims, drops empty entries.
public struct CommaSeparatedListOutputParser: Runnable {
    public typealias Input = AIMessage
    public typealias Output = [String]

    public init() {}

    public func invoke(_ input: AIMessage) async throws -> [String] {
        input.content
            .split(separator: ",", omittingEmptySubsequences: false)
            .map { $0.trimmingCharacters(in: .whitespacesAndNewlines) }
            .filter { !$0.isEmpty }
    }
}

/// Newline-separated list. Trims, drops empty lines.
public struct LineSeparatedListOutputParser: Runnable {
    public typealias Input = AIMessage
    public typealias Output = [String]

    public init() {}

    public func invoke(_ input: AIMessage) async throws -> [String] {
        input.content
            .split(separator: "\n", omittingEmptySubsequences: false)
            .map { $0.trimmingCharacters(in: .whitespacesAndNewlines) }
            .filter { !$0.isEmpty }
    }
}

/// Numbered list — strips leading `\d+[.)]\s*` from each line.
public struct NumberedListOutputParser: Runnable {
    public typealias Input = AIMessage
    public typealias Output = [String]

    public init() {}

    public func invoke(_ input: AIMessage) async throws -> [String] {
        let prefixRegex = try NSRegularExpression(pattern: #"^\s*\d+[.)]\s*(.*)$"#)
        return input.content
            .split(separator: "\n")
            .compactMap { line in
                let text = String(line)
                let nsText = text as NSString
                let range = NSRange(location: 0, length: nsText.length)
                if let match = prefixRegex.firstMatch(in: text, range: range), match.numberOfRanges > 1 {
                    return nsText.substring(with: match.range(at: 1)).trimmingCharacters(in: .whitespacesAndNewlines)
                }
                let trimmed = text.trimmingCharacters(in: .whitespacesAndNewlines)
                return trimmed.isEmpty ? nil : trimmed
            }
    }
}
