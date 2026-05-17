import Foundation

/// Newline-delimited JSON: one valid JSON value per line, terminated by `\n`. Ollama's
/// `/api/chat` and `/api/generate` streaming endpoints use this format.
public func parseNDJSON<Bytes: AsyncSequence>(
    _ bytes: Bytes
) -> AsyncThrowingStream<Data, Error> where Bytes.Element == Data, Bytes: Sendable {
    AsyncThrowingStream { continuation in
        let task = Task {
            do {
                var buffer = Data()
                for try await chunk in bytes {
                    buffer.append(chunk)
                    while let newlineIndex = buffer.firstIndex(of: 0x0A) {
                        let line = buffer[buffer.startIndex..<newlineIndex]
                        buffer.removeSubrange(buffer.startIndex...newlineIndex)
                        if !line.isEmpty {
                            continuation.yield(Data(line))
                        }
                    }
                }
                if !buffer.isEmpty {
                    continuation.yield(buffer)
                }
                continuation.finish()
            } catch {
                continuation.finish(throwing: error)
            }
        }
        continuation.onTermination = { _ in task.cancel() }
    }
}
