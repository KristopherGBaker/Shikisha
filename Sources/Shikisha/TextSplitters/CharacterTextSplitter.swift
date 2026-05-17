import Foundation

/// Split on a fixed separator into fixed-size chunks with an overlap. The dumb-and-fast
/// option; for prose, prefer `RecursiveCharacterTextSplitter`.
public struct CharacterTextSplitter: TextSplitter {
    public let separator: String
    public let chunkSize: Int
    public let chunkOverlap: Int
    public let lengthFunction: @Sendable (String) -> Int

    public init(
        separator: String = "\n\n",
        chunkSize: Int,
        chunkOverlap: Int,
        lengthFunction: @Sendable @escaping (String) -> Int = { $0.count }
    ) {
        precondition(chunkSize > 0, "chunkSize must be > 0")
        precondition(chunkOverlap >= 0 && chunkOverlap < chunkSize, "chunkOverlap must be in [0, chunkSize)")
        self.separator = separator
        self.chunkSize = chunkSize
        self.chunkOverlap = chunkOverlap
        self.lengthFunction = lengthFunction
    }

    public func splitText(_ text: String) -> [String] {
        let parts = text.components(separatedBy: separator).filter { !$0.isEmpty }
        return mergeSplits(parts, separator: separator, chunkSize: chunkSize, chunkOverlap: chunkOverlap, length: lengthFunction)
    }
}

func mergeSplits(
    _ splits: [String],
    separator: String,
    chunkSize: Int,
    chunkOverlap: Int,
    length: (String) -> Int
) -> [String] {
    var documents: [String] = []
    var currentDocument: [String] = []
    var total = 0
    let separatorLength = length(separator)

    for split in splits {
        let splitLength = length(split)
        if total + splitLength + (currentDocument.isEmpty ? 0 : separatorLength) > chunkSize, !currentDocument.isEmpty {
            documents.append(currentDocument.joined(separator: separator))
            while total > chunkOverlap || (total + splitLength + (currentDocument.isEmpty ? 0 : separatorLength) > chunkSize && total > 0) {
                guard let first = currentDocument.first else { break }
                total -= length(first) + (currentDocument.count > 1 ? separatorLength : 0)
                currentDocument.removeFirst()
            }
        }
        currentDocument.append(split)
        total += splitLength + (currentDocument.count > 1 ? separatorLength : 0)
    }
    if !currentDocument.isEmpty {
        documents.append(currentDocument.joined(separator: separator))
    }
    return documents
}
