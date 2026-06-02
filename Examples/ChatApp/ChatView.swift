import SwiftUI

/// The chat UI. One cross-platform layout for macOS and iOS — no `#if os(...)` in the views.
/// Custom header and composer (via `safeAreaInset`) replace system chrome so the "Ink & Ember"
/// aesthetic carries through end to end.
struct ChatView: View {
    @State private var chat = AgentChat()

    var body: some View {
        ZStack {
            Theme.ground.ignoresSafeArea()
            transcript
        }
        .safeAreaInset(edge: .top, spacing: 0) { header }
        .safeAreaInset(edge: .bottom, spacing: 0) { composer }
        .tint(Theme.ember)
        .preferredColorScheme(.dark)
    }

    // MARK: Header

    private var header: some View {
        HStack(spacing: 10) {
            Text("色")
                .font(.system(size: 22, weight: .bold))
                .foregroundStyle(Theme.emberStroke)
            VStack(alignment: .leading, spacing: 1) {
                Text("shikisha")
                    .font(Theme.mono(.headline, weight: .semibold))
                    .foregroundStyle(Theme.ink)
                Text("coding agent")
                    .font(Theme.mono(.caption2))
                    .foregroundStyle(Theme.inkSoft)
                    .tracking(2)
                    .textCase(.uppercase)
            }
            Spacer()
            if chat.isRunning { ThinkingIndicator() }
        }
        .padding(.horizontal, 18)
        .padding(.vertical, 12)
        .background(.ultraThinMaterial)
        .overlay(alignment: .bottom) { Rectangle().fill(Theme.hairline).frame(height: 1) }
    }

    // MARK: Transcript

    private var transcript: some View {
        ScrollViewReader { proxy in
            ScrollView {
                if chat.items.isEmpty {
                    EmptyState()
                        .padding(.top, 64)
                        .frame(maxWidth: .infinity)
                } else {
                    LazyVStack(alignment: .leading, spacing: 12) {
                        ForEach(chat.items) { item in
                            MessageRow(item: item)
                                .id(item.id)
                                .transition(.move(edge: .bottom).combined(with: .opacity))
                        }
                    }
                    .padding(18)
                    .animation(.spring(response: 0.42, dampingFraction: 0.82), value: chat.items.count)
                }
            }
            .scrollIndicators(.hidden)
            .onChange(of: chat.items.count) {
                if let last = chat.items.last {
                    withAnimation(.easeOut(duration: 0.3)) { proxy.scrollTo(last.id, anchor: .bottom) }
                }
            }
        }
    }

    // MARK: Composer

    private var composer: some View {
        VStack(spacing: 0) {
            if let note = chat.statusNote {
                HStack(spacing: 6) {
                    Image(systemName: "info.circle")
                    Text(note)
                }
                .font(Theme.mono(.caption2))
                .foregroundStyle(Theme.ember)
                .padding(.horizontal, 18)
                .padding(.vertical, 8)
                .frame(maxWidth: .infinity, alignment: .leading)
                .background(Theme.ember.opacity(0.08))
            }

            HStack(alignment: .bottom, spacing: 10) {
                TextField("", text: $chat.input, prompt: prompt, axis: .vertical)
                    .textFieldStyle(.plain)
                    .font(.system(.body))
                    .foregroundStyle(Theme.ink)
                    .lineLimit(1...5)
                    .padding(.horizontal, 14)
                    .padding(.vertical, 10)
                    .background(Theme.raised, in: RoundedRectangle(cornerRadius: 14))
                    .overlay {
                        RoundedRectangle(cornerRadius: 14).strokeBorder(Theme.hairline, lineWidth: 1)
                    }
                    .onSubmit(send)

                SendButton(isRunning: chat.isRunning, isEnabled: canSend, action: send)
            }
            .padding(.horizontal, 16)
            .padding(.vertical, 12)
        }
        .background(.ultraThinMaterial)
        .overlay(alignment: .top) { Rectangle().fill(Theme.hairline).frame(height: 1) }
    }

    private var prompt: Text {
        Text("ask the agent to read, list, or edit a file…").foregroundStyle(Theme.inkFaint)
    }

    private var canSend: Bool {
        !chat.isRunning && !chat.input.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
    }

    private func send() { Task { await chat.send() } }
}

// MARK: - Send button

private struct SendButton: View {
    let isRunning: Bool
    let isEnabled: Bool
    let action: () -> Void
    @State private var pressed = false

    var body: some View {
        Button(action: action) {
            ZStack {
                Circle()
                    .fill(isEnabled ? AnyShapeStyle(Theme.emberStroke) : AnyShapeStyle(Theme.raised))
                    .frame(width: 38, height: 38)
                    .overlay { if !isEnabled { Circle().strokeBorder(Theme.hairline, lineWidth: 1) } }
                if isRunning {
                    ProgressView().controlSize(.small).tint(Theme.base)
                } else {
                    Image(systemName: "arrow.up")
                        .font(.system(size: 16, weight: .bold))
                        .foregroundStyle(isEnabled ? Theme.base : Theme.inkFaint)
                }
            }
            .scaleEffect(pressed ? 0.88 : 1)
            .shadow(color: isEnabled ? Theme.ember.opacity(0.4) : .clear, radius: 8, y: 2)
        }
        .buttonStyle(.plain)
        .disabled(!isEnabled)
        .animation(.spring(response: 0.3, dampingFraction: 0.6), value: pressed)
        .onLongPressGesture(minimumDuration: 0, pressing: { pressed = $0 }, perform: {})
    }
}

// MARK: - Animated "thinking" indicator

private struct ThinkingIndicator: View {
    var body: some View {
        TimelineView(.animation) { context in
            let t = context.date.timeIntervalSinceReferenceDate
            HStack(spacing: 5) {
                ForEach(0..<3, id: \.self) { index in
                    let wave = (sin(t * 4.4 + Double(index) * 0.8) + 1) / 2
                    Circle()
                        .fill(Theme.ember)
                        .frame(width: 6, height: 6)
                        .opacity(0.35 + 0.65 * wave)
                        .scaleEffect(0.7 + 0.4 * wave)
                }
            }
        }
        .frame(height: 10)
    }
}

// MARK: - Empty state

private struct EmptyState: View {
    private let prompts = [
        "List the files in the sandbox.",
        "Read README.md and summarize it.",
        "Create hello.swift with a greeting function."
    ]

    var body: some View {
        VStack(spacing: 22) {
            Text("色")
                .font(.system(size: 92, weight: .bold))
                .foregroundStyle(Theme.emberStroke)
                .opacity(0.16)
            VStack(spacing: 6) {
                Text("a coding agent, in your pocket")
                    .font(Theme.mono(.subheadline, weight: .medium))
                    .foregroundStyle(Theme.ink)
                Text("it can read, list, and edit files in a sandbox")
                    .font(Theme.mono(.caption2))
                    .foregroundStyle(Theme.inkSoft)
            }
            VStack(spacing: 8) {
                ForEach(prompts, id: \.self) { suggestion in
                    Text(suggestion)
                        .font(.system(.footnote))
                        .foregroundStyle(Theme.inkSoft)
                        .padding(.horizontal, 14)
                        .padding(.vertical, 9)
                        .frame(maxWidth: 320, alignment: .leading)
                        .background(Theme.raised.opacity(0.7), in: Capsule())
                        .overlay { Capsule().strokeBorder(Theme.hairline, lineWidth: 1) }
                }
            }
        }
        .padding(.horizontal, 24)
    }
}

// MARK: - Message row

private struct MessageRow: View {
    let item: ChatItem

    var body: some View {
        switch item.kind {
        case .tool:
            Label(item.text, systemImage: "wrench.and.screwdriver.fill")
                .font(Theme.mono(.caption2))
                .foregroundStyle(Theme.inkSoft)
                .lineLimit(1)
                .padding(.horizontal, 10)
                .padding(.vertical, 6)
                .background(Theme.ember.opacity(0.08), in: Capsule())
                .overlay { Capsule().strokeBorder(Theme.ember.opacity(0.25), lineWidth: 1) }
                .frame(maxWidth: .infinity, alignment: .leading)
        case .user:
            bubble(alignment: .trailing) {
                Text(item.text)
                    .foregroundStyle(Theme.ink)
                    .padding(.horizontal, 14).padding(.vertical, 10)
                    .background(Theme.ember.opacity(0.16), in: RoundedRectangle(cornerRadius: 16))
                    .overlay {
                        RoundedRectangle(cornerRadius: 16).strokeBorder(Theme.ember.opacity(0.45), lineWidth: 1)
                    }
            }
        case .assistant:
            bubble(alignment: .leading) {
                Text(item.text)
                    .foregroundStyle(Theme.ink)
                    .textSelection(.enabled)
                    .padding(.horizontal, 14).padding(.vertical, 10)
                    .background(Theme.raised, in: RoundedRectangle(cornerRadius: 16))
                    .overlay {
                        RoundedRectangle(cornerRadius: 16).strokeBorder(Theme.hairline, lineWidth: 1)
                    }
            }
        }
    }

    @ViewBuilder
    private func bubble<Content: View>(alignment: HorizontalAlignment, @ViewBuilder _ content: () -> Content) -> some View {
        HStack {
            if alignment == .trailing { Spacer(minLength: 48) }
            content()
            if alignment == .leading { Spacer(minLength: 48) }
        }
    }
}

#Preview {
    ChatView()
}
