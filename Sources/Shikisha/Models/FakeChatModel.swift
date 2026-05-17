import Foundation

/// A `ChatModel` that returns canned responses in order. Drives tests and offline demos.
///
/// Implemented as an actor for thread-safe queue mutation; consumers receive `AIMessage`
/// values via the standard `Runnable.invoke` async method.
public actor FakeChatModel: ChatModel {
    public nonisolated let modelName: String

    private var queue: [AIMessage]
    private var defaultResponse: AIMessage
    private(set) var receivedInvocations: [[any Message]] = []

    public init(
        modelName: String = "fake-model",
        responses: [AIMessage] = [],
        default defaultResponse: AIMessage = AIMessage(content: "")
    ) {
        self.modelName = modelName
        self.queue = responses
        self.defaultResponse = defaultResponse
    }

    public func enqueue(_ response: AIMessage) {
        queue.append(response)
    }

    public func snapshotInvocations() -> [[any Message]] { receivedInvocations }

    public func invoke(_ input: [any Message]) async throws -> AIMessage {
        receivedInvocations.append(input)
        if queue.isEmpty { return defaultResponse }
        return queue.removeFirst()
    }
}
