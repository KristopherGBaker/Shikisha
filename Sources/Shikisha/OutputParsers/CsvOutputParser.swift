import Foundation

/// Tolerant CSV parser. Handles quoted fields, embedded commas, escaped quotes (`""`).
/// Returns rows as `[String]`. The first row is not treated specially — callers can pluck it as
/// headers if they want.
public struct CsvOutputParser: Runnable {
    public typealias Input = AIMessage
    public typealias Output = [[String]]

    public let delimiter: Character

    public init(delimiter: Character = ",") {
        self.delimiter = delimiter
    }

    public func invoke(_ input: AIMessage) async throws -> [[String]] {
        parseCSV(input.content, delimiter: delimiter)
    }
}

func parseCSV(_ text: String, delimiter: Character) -> [[String]] {
    var rows: [[String]] = []
    var current: [String] = []
    var field = ""
    var inQuotes = false
    var iterator = text.makeIterator()
    var peeked: Character?

    func nextChar() -> Character? {
        if let p = peeked { peeked = nil; return p }
        return iterator.next()
    }

    while let char = nextChar() {
        if inQuotes {
            if char == "\"" {
                if let next = nextChar() {
                    if next == "\"" {
                        field.append("\"")
                    } else {
                        inQuotes = false
                        peeked = next
                    }
                } else {
                    inQuotes = false
                }
            } else {
                field.append(char)
            }
        } else {
            switch char {
            case "\"":
                inQuotes = true
            case delimiter:
                current.append(field)
                field = ""
            case "\r":
                if let next = nextChar() {
                    if next != "\n" { peeked = next }
                }
                current.append(field)
                field = ""
                rows.append(current)
                current = []
            case "\n":
                current.append(field)
                field = ""
                rows.append(current)
                current = []
            default:
                field.append(char)
            }
        }
    }
    if !field.isEmpty || !current.isEmpty {
        current.append(field)
        rows.append(current)
    }
    return rows
}
