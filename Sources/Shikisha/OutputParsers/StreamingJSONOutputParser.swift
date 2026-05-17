import Foundation

/// Best-effort JSON parsing of an in-flight streaming response. Closes any open
/// strings/objects/arrays and trims trailing commas so partial JSON can decode. Useful when
/// you want to render a structured response token-by-token.
public enum PartialJSON {
    public static func parse(_ partial: String) -> JSONValue? {
        let trimmed = partial.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return nil }
        let closed = closePartial(trimmed)
        return JSONValue.parse(closed)
    }

    /// Decode partial JSON into `Output`. Returns nil if the buffer can't (yet) form a valid
    /// instance of `Output`.
    public static func decode<Output: Decodable>(_ type: Output.Type, _ partial: String) -> Output? {
        guard let value = parse(partial) else { return nil }
        guard let data = try? JSONEncoder().encode(value) else { return nil }
        return try? JSONDecoder().decode(Output.self, from: data)
    }
}

private func closePartial(_ raw: String) -> String {
    var stack: [Character] = []
    var inString = false
    var escape = false
    var lastNonWhitespace: Character?
    var trimmed = ""
    trimmed.reserveCapacity(raw.count)

    for char in raw {
        trimmed.append(char)
        if !char.isWhitespace { lastNonWhitespace = char }
        if escape { escape = false; continue }
        if char == "\\" { escape = true; continue }
        if char == "\"" { inString.toggle(); continue }
        if inString { continue }
        switch char {
        case "{", "[": stack.append(char)
        case "}":
            if stack.last == "{" { stack.removeLast() }
        case "]":
            if stack.last == "[" { stack.removeLast() }
        default: break
        }
    }

    // Trim trailing comma if present (`{"a":1,` -> `{"a":1`).
    if lastNonWhitespace == "," {
        while !trimmed.isEmpty, trimmed.removeLast() != "," { }
    }

    // Close any open string.
    if inString { trimmed.append("\"") }

    // Close any open containers, innermost first.
    for opener in stack.reversed() {
        trimmed.append(opener == "{" ? "}" : "]")
    }
    return trimmed
}
