import Foundation

/// Unbounded message buffer. The simplest possible memory — replay everything.
public actor BufferMemory: ChatMemory {
    private var buffer: [any Message] = []

    public init() {}

    public func addMessage(_ message: any Message) async throws {
        buffer.append(message)
    }

    public func messages() async throws -> [any Message] {
        buffer
    }

    public func clear() async throws {
        buffer.removeAll()
    }
}

/// Keep at most the last `windowSize` messages. Pinned system messages survive eviction.
public actor BufferWindowMemory: ChatMemory {
    public let windowSize: Int
    private var buffer: [any Message] = []

    public init(windowSize: Int) {
        precondition(windowSize > 0, "windowSize must be > 0")
        self.windowSize = windowSize
    }

    public func addMessage(_ message: any Message) async throws {
        buffer.append(message)
        trim()
    }

    public func messages() async throws -> [any Message] {
        buffer
    }

    public func clear() async throws {
        buffer.removeAll()
    }

    private func trim() {
        let systemMessages = buffer.filter { $0 is SystemMessage }
        let nonSystem = buffer.filter { !($0 is SystemMessage) }
        let trimmed = Array(nonSystem.suffix(windowSize))
        buffer = systemMessages + trimmed
    }
}

/// Keep all messages whose combined token budget fits in `maxTokens`.
public actor TokenBufferMemory: ChatMemory {
    public let maxTokens: Int
    public let counter: any TokenCounter
    private var buffer: [any Message] = []

    public init(maxTokens: Int, counter: any TokenCounter = ApproximateTokenCounter()) {
        precondition(maxTokens > 0, "maxTokens must be > 0")
        self.maxTokens = maxTokens
        self.counter = counter
    }

    public func addMessage(_ message: any Message) async throws {
        buffer.append(message)
        buffer = trimMessages(buffer, maxTokens: maxTokens, counter: counter, strategy: .last)
    }

    public func messages() async throws -> [any Message] {
        buffer
    }

    public func clear() async throws {
        buffer.removeAll()
    }
}
