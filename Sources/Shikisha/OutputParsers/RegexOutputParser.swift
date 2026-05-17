import Foundation

/// Apply an `NSRegularExpression` to model output and return named capture groups as
/// `[String: String]`. If no match is found, throws.
public struct RegexOutputParser: Runnable {
    public typealias Input = AIMessage
    public typealias Output = [String: String]

    public let pattern: NSRegularExpression
    public let groupNames: [String]

    public init(pattern: String, groupNames: [String]) throws {
        self.pattern = try NSRegularExpression(pattern: pattern)
        self.groupNames = groupNames
    }

    public func invoke(_ input: AIMessage) async throws -> [String: String] {
        let text = input.content
        let range = NSRange(text.startIndex..<text.endIndex, in: text)
        guard let match = pattern.firstMatch(in: text, range: range) else {
            throw HTTPError.decoding(message: "regex did not match: \(pattern.pattern)")
        }
        var result: [String: String] = [:]
        for name in groupNames {
            let groupRange = match.range(withName: name)
            if groupRange.location != NSNotFound, let swiftRange = Range(groupRange, in: text) {
                result[name] = String(text[swiftRange])
            }
        }
        return result
    }
}
