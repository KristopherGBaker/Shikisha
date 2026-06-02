import SwiftUI

// "Ink & Ember": one warm, dark, intentional palette — defined explicitly so the app looks the
// same on macOS and iOS regardless of the system appearance.
enum Theme {
    static let base = Color(red: 0.063, green: 0.055, blue: 0.047)
    static let raised = Color(red: 0.105, green: 0.094, blue: 0.082)
    static let ink = Color(red: 0.945, green: 0.915, blue: 0.855)
    static let ember = Color(red: 0.957, green: 0.580, blue: 0.204)
    static let emberDeep = Color(red: 0.851, green: 0.357, blue: 0.129)
    static let hairline = Color.white.opacity(0.08)

    static var ground: LinearGradient {
        LinearGradient(colors: [Color(red: 0.094, green: 0.082, blue: 0.071), base],
                       startPoint: .top, endPoint: .bottom)
    }
    static var emberStroke: LinearGradient {
        LinearGradient(colors: [ember, emberDeep], startPoint: .topLeading, endPoint: .bottomTrailing)
    }
    static func mono(_ s: Font.TextStyle, weight: Font.Weight = .regular) -> Font {
        .system(s, design: .monospaced).weight(weight)
    }
}

struct ChatView: View {
    @State private var chat = AgentChat()

    var body: some View {
        ZStack {
            Theme.ground.ignoresSafeArea()
            transcript
        }
        // Custom header & composer via safeAreaInset — no system chrome, works on both platforms.
        .safeAreaInset(edge: .top, spacing: 0) { header }
        .safeAreaInset(edge: .bottom, spacing: 0) { composer }
        .tint(Theme.ember)
        .preferredColorScheme(.dark)
    }

    private var header: some View {
        HStack(spacing: 10) {
            Text("色").font(.system(size: 22, weight: .bold)).foregroundStyle(Theme.emberStroke)
            Text("shikisha").font(Theme.mono(.headline, weight: .semibold)).foregroundStyle(Theme.ink)
            Spacer()
            if chat.isRunning { ThinkingIndicator() }   // animated dots, not a stock spinner
        }
        .padding(.horizontal, 18).padding(.vertical, 12)
        .background(.ultraThinMaterial)
        .overlay(alignment: .bottom) { Rectangle().fill(Theme.hairline).frame(height: 1) }
    }

    private var transcript: some View {
        ScrollViewReader { proxy in
            ScrollView {
                LazyVStack(alignment: .leading, spacing: 12) {
                    ForEach(chat.items) { item in
                        MessageRow(item: item).id(item.id)
                            .transition(.move(edge: .bottom).combined(with: .opacity))  // staggered reveal
                    }
                }
                .padding(18)
                .animation(.spring(response: 0.42, dampingFraction: 0.82), value: chat.items.count)
            }
            .scrollIndicators(.hidden)
            .onChange(of: chat.items.count) {
                if let last = chat.items.last {
                    withAnimation(.easeOut(duration: 0.3)) { proxy.scrollTo(last.id, anchor: .bottom) }
                }
            }
        }
    }

    // composer: a custom rounded field + an ember send button. See Examples/ChatApp for the full
    // source (SendButton, EmptyState, status banner).
    private var composer: some View { /* ... */ EmptyView() }
}

// Continuous "thinking" animation driven by TimelineView.
private struct ThinkingIndicator: View {
    var body: some View {
        TimelineView(.animation) { context in
            let t = context.date.timeIntervalSinceReferenceDate
            HStack(spacing: 5) {
                ForEach(0..<3, id: \.self) { i in
                    let wave = (sin(t * 4.4 + Double(i) * 0.8) + 1) / 2
                    Circle().fill(Theme.ember).frame(width: 6, height: 6)
                        .opacity(0.35 + 0.65 * wave).scaleEffect(0.7 + 0.4 * wave)
                }
            }
        }
    }
}

private struct MessageRow: View {
    let item: ChatItem
    var body: some View {
        switch item.kind {
        case .tool:   // a terminal-style log chip so the agent's actions are visible
            Label(item.text, systemImage: "wrench.and.screwdriver.fill")
                .font(Theme.mono(.caption2)).foregroundStyle(Theme.ink.opacity(0.62))
                .padding(.horizontal, 10).padding(.vertical, 6)
                .background(Theme.ember.opacity(0.08), in: Capsule())
                .overlay { Capsule().strokeBorder(Theme.ember.opacity(0.25), lineWidth: 1) }
        case .user:
            HStack { Spacer(minLength: 48)
                Text(item.text).foregroundStyle(Theme.ink)
                    .padding(.horizontal, 14).padding(.vertical, 10)
                    .background(Theme.ember.opacity(0.16), in: RoundedRectangle(cornerRadius: 16))
                    .overlay { RoundedRectangle(cornerRadius: 16).strokeBorder(Theme.ember.opacity(0.45), lineWidth: 1) }
            }
        case .assistant:
            HStack {
                Text(item.text).foregroundStyle(Theme.ink).textSelection(.enabled)
                    .padding(.horizontal, 14).padding(.vertical, 10)
                    .background(Theme.raised, in: RoundedRectangle(cornerRadius: 16))
                    .overlay { RoundedRectangle(cornerRadius: 16).strokeBorder(Theme.hairline, lineWidth: 1) }
                Spacer(minLength: 48)
            }
        }
    }
}
