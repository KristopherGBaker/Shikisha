import SwiftUI

// One universal app entry point — the same code runs on macOS and iOS.
@main
struct ShikishaChatApp: App {
    var body: some Scene {
        WindowGroup {
            ChatView()
            #if os(macOS)
                .frame(minWidth: 480, minHeight: 600)
            #endif
        }
    }
}

// One row in the transcript. The engine produces these; the views render them.
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
