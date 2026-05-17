import Foundation

/// One Server-Sent Events frame. `data` is the concatenation of every `data:` line
/// in the frame (joined by `\n`, with the trailing `\n` trimmed per the spec).
public struct SSEEvent: Sendable, Equatable {
    public let event: String?
    public let data: String
    public let id: String?

    public init(event: String? = nil, data: String, id: String? = nil) {
        self.event = event
        self.data = data
        self.id = id
    }
}

/// Parse a raw byte stream as Server-Sent Events. Emits one `SSEEvent` per blank-line
/// terminated frame. Used by every chat-model provider that streams via SSE
/// (OpenAI, Anthropic, Google).
public func parseSSE<Bytes: AsyncSequence>(
    _ bytes: Bytes
) -> AsyncThrowingStream<SSEEvent, Error> where Bytes.Element == Data, Bytes: Sendable {
    AsyncThrowingStream { continuation in
        let task = Task {
            do {
                var buffer = Data()
                var dataLines: [String] = []
                var event: String?
                var lastID: String?
                for try await chunk in bytes {
                    buffer.append(chunk)
                    while let lineRange = nextLineRange(in: buffer) {
                        let lineData = buffer[lineRange.lineStart..<lineRange.lineEnd]
                        let line = String(data: lineData, encoding: .utf8) ?? ""
                        buffer.removeSubrange(buffer.startIndex..<lineRange.advanceTo)

                        if line.isEmpty {
                            if !dataLines.isEmpty || event != nil {
                                continuation.yield(SSEEvent(
                                    event: event,
                                    data: dataLines.joined(separator: "\n"),
                                    id: lastID
                                ))
                            }
                            dataLines.removeAll(keepingCapacity: true)
                            event = nil
                            continue
                        }
                        if line.hasPrefix(":") { continue }  // comment

                        if let colon = line.firstIndex(of: ":") {
                            let field = String(line[..<colon])
                            var valueStart = line.index(after: colon)
                            if valueStart < line.endIndex, line[valueStart] == " " {
                                valueStart = line.index(after: valueStart)
                            }
                            let value = String(line[valueStart...])
                            switch field {
                            case "data": dataLines.append(value)
                            case "event": event = value
                            case "id": lastID = value
                            default: break
                            }
                        } else {
                            // Field with no value
                            if line == "data" { dataLines.append("") }
                        }
                    }
                }
                // Flush trailing frame without terminator
                if !dataLines.isEmpty || event != nil {
                    continuation.yield(SSEEvent(
                        event: event,
                        data: dataLines.joined(separator: "\n"),
                        id: lastID
                    ))
                }
                continuation.finish()
            } catch {
                continuation.finish(throwing: error)
            }
        }
        continuation.onTermination = { _ in task.cancel() }
    }
}

private struct LineRange {
    let lineStart: Data.Index
    let lineEnd: Data.Index
    let advanceTo: Data.Index
}

/// Find the next \n- or \r\n-terminated line in the buffer.
/// Returns the slice excluding the terminator and where to advance the start.
private func nextLineRange(in buffer: Data) -> LineRange? {
    guard let newlineIndex = buffer.firstIndex(of: 0x0A) else { return nil }
    let advance = buffer.index(after: newlineIndex)
    let isCRLF = newlineIndex > buffer.startIndex && buffer[buffer.index(before: newlineIndex)] == 0x0D
    let lineEnd = isCRLF ? buffer.index(before: newlineIndex) : newlineIndex
    return LineRange(lineStart: buffer.startIndex, lineEnd: lineEnd, advanceTo: advance)
}
