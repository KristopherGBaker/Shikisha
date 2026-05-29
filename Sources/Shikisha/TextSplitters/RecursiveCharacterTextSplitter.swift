import Foundation

/// Try each separator in turn; if any chunk is still too big, recurse into it with the next
/// separator down. Prose-friendly defaults: paragraph -> line -> word -> character.
public struct RecursiveCharacterTextSplitter: TextSplitter {
    public let separators: [String]
    public let keepSeparator: Bool
    public let chunkSize: Int
    public let chunkOverlap: Int
    public let lengthFunction: @Sendable (String) -> Int

    public init(
        separators: [String] = ["\n\n", "\n", " ", ""],
        keepSeparator: Bool = true,
        chunkSize: Int = 1000,
        chunkOverlap: Int = 200,
        lengthFunction: @Sendable @escaping (String) -> Int = { $0.count }
    ) {
        precondition(chunkSize > 0, "chunkSize must be > 0")
        precondition(chunkOverlap >= 0 && chunkOverlap < chunkSize, "chunkOverlap must be in [0, chunkSize)")
        self.separators = separators
        self.keepSeparator = keepSeparator
        self.chunkSize = chunkSize
        self.chunkOverlap = chunkOverlap
        self.lengthFunction = lengthFunction
    }

    /// Markdown preset — splits on heading levels, then paragraphs, then lines.
    public static func markdown(chunkSize: Int = 1000, chunkOverlap: Int = 200) -> RecursiveCharacterTextSplitter {
        RecursiveCharacterTextSplitter(
            separators: ["\n# ", "\n## ", "\n### ", "\n#### ", "\n##### ", "\n###### ", "\n\n", "\n", " ", ""],
            chunkSize: chunkSize,
            chunkOverlap: chunkOverlap
        )
    }

    /// Swift / Kotlin / TypeScript source preset — splits on top-level declarations.
    public static func code(chunkSize: Int = 1000, chunkOverlap: Int = 200) -> RecursiveCharacterTextSplitter {
        RecursiveCharacterTextSplitter(
            separators: [
                "\nclass ", "\nstruct ", "\nenum ", "\nactor ", "\nprotocol ", "\nextension ",
                "\nfunc ", "\nfun ", "\nfunction ", "\nlet ", "\nvar ", "\nval ",
                "\n\n", "\n", " ", ""
            ],
            chunkSize: chunkSize,
            chunkOverlap: chunkOverlap
        )
    }

    public func splitText(_ text: String) -> [String] {
        split(text, separators: separators)
    }

    private func split(_ text: String, separators: [String]) -> [String] {
        let (separator, remainingSeparators) = pickSeparator(text: text, candidates: separators)
        let splits: [String]
        if separator.isEmpty {
            splits = text.map { String($0) }
        } else {
            splits = splitWithSeparator(text: text, separator: separator, keepSeparator: keepSeparator)
        }

        var goodSplits: [String] = []
        var finalChunks: [String] = []
        for split in splits {
            if lengthFunction(split) < chunkSize {
                goodSplits.append(split)
            } else {
                if !goodSplits.isEmpty {
                    finalChunks.append(contentsOf: mergeSplits(
                        goodSplits,
                        separator: separator.isEmpty ? "" : separator,
                        chunkSize: chunkSize,
                        chunkOverlap: chunkOverlap,
                        length: lengthFunction
                    ))
                    goodSplits = []
                }
                if remainingSeparators.isEmpty {
                    finalChunks.append(split)
                } else {
                    finalChunks.append(contentsOf: self.split(split, separators: remainingSeparators))
                }
            }
        }
        if !goodSplits.isEmpty {
            finalChunks.append(contentsOf: mergeSplits(
                goodSplits,
                separator: separator.isEmpty ? "" : separator,
                chunkSize: chunkSize,
                chunkOverlap: chunkOverlap,
                length: lengthFunction
            ))
        }
        return finalChunks
    }
}

private func pickSeparator(text: String, candidates: [String]) -> (chosen: String, remaining: [String]) {
    var chosen = candidates.last ?? ""
    var remaining: [String] = []
    for (index, candidate) in candidates.enumerated() {
        if candidate.isEmpty {
            chosen = candidate
            break
        }
        if text.contains(candidate) {
            chosen = candidate
            remaining = Array(candidates.suffix(from: index + 1))
            break
        }
    }
    return (chosen, remaining)
}

private func splitWithSeparator(text: String, separator: String, keepSeparator: Bool) -> [String] {
    guard !separator.isEmpty else { return [text] }
    let parts = text.components(separatedBy: separator)
    guard keepSeparator else { return parts.filter { !$0.isEmpty } }
    var result: [String] = []
    for (index, part) in parts.enumerated() {
        if index == 0 {
            if !part.isEmpty { result.append(part) }
        } else {
            result.append(separator + part)
        }
    }
    return result.filter { !$0.isEmpty }
}
