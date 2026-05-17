import Foundation

/// Parse an ISO 8601 date (e.g. `2025-01-15`).
public struct ISODateOutputParser: Runnable {
    public typealias Input = AIMessage
    public typealias Output = Date

    public init() {}

    public func invoke(_ input: AIMessage) async throws -> Date {
        let text = input.content.trimmingCharacters(in: .whitespacesAndNewlines)
        let formatter = DateFormatter()
        formatter.locale = Locale(identifier: "en_US_POSIX")
        formatter.timeZone = TimeZone(secondsFromGMT: 0)
        formatter.dateFormat = "yyyy-MM-dd"
        if let date = formatter.date(from: text) { return date }
        throw HTTPError.decoding(message: "could not parse ISO date: \(text)")
    }
}

/// Parse an ISO 8601 datetime / instant.
public struct ISODateTimeOutputParser: Runnable {
    public typealias Input = AIMessage
    public typealias Output = Date

    public init() {}

    public func invoke(_ input: AIMessage) async throws -> Date {
        let text = input.content.trimmingCharacters(in: .whitespacesAndNewlines)
        let iso = ISO8601DateFormatter()
        iso.formatOptions = [.withInternetDateTime, .withFractionalSeconds]
        if let date = iso.date(from: text) { return date }
        iso.formatOptions = [.withInternetDateTime]
        if let date = iso.date(from: text) { return date }
        throw HTTPError.decoding(message: "could not parse ISO datetime: \(text)")
    }
}
