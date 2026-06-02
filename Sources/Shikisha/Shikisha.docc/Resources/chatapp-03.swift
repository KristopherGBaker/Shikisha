import SwiftUI

// A first, plain pass — get the conversation on screen with system styling. We'll restyle it
// in the next step.
struct ChatView: View {
    @State private var chat = AgentChat()

    var body: some View {
        VStack(spacing: 0) {
            ScrollViewReader { proxy in
                ScrollView {
                    LazyVStack(alignment: .leading, spacing: 10) {
                        ForEach(chat.items) { item in
                            MessageRow(item: item).id(item.id)
                        }
                    }
                    .padding()
                }
                .onChange(of: chat.items.count) {
                    if let last = chat.items.last { proxy.scrollTo(last.id, anchor: .bottom) }
                }
            }

            HStack {
                TextField("Ask the agent…", text: $chat.input, axis: .vertical)
                    .textFieldStyle(.roundedBorder)
                    .onSubmit { Task { await chat.send() } }
                Button("Send") { Task { await chat.send() } }
                    .disabled(chat.isRunning)
            }
            .padding()
        }
    }
}

private struct MessageRow: View {
    let item: ChatItem
    var body: some View {
        HStack {
            if item.kind == .user { Spacer(minLength: 40) }
            Text(item.text)
                .padding(10)
                .background(item.kind == .user ? Color.accentColor.opacity(0.15) : Color.gray.opacity(0.12))
                .clipShape(RoundedRectangle(cornerRadius: 12))
            if item.kind != .user { Spacer(minLength: 40) }
        }
    }
}
