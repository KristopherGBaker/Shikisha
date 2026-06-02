import SwiftUI

/// A small universal (macOS + iOS) SwiftUI app that puts a chat interface on the coding agent
/// built in the "Build a Coding Agent" tutorial. See the "Put Your Agent in a SwiftUI App"
/// tutorial for a step-by-step walkthrough.
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
