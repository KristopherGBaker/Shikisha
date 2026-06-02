import Foundation

/// One row in the chat transcript. The view model produces these; the UI renders them.
struct ChatItem: Identifiable, Sendable {
    enum Kind: Sendable {
        case user        // something you typed
        case assistant   // the model's reply
        case tool        // a tool the agent invoked (shown so you can see its actions)
    }

    let id = UUID()
    let kind: Kind
    let text: String
}
