import Foundation

/// Wrap any parser with an LLM-driven retry. If the first parse throws, ask a model to fix the
/// raw output and parse again. Bounded by `maxRetries`.
public struct OutputFixingParser<Parser: Runnable, Fixer: ChatModel>: Runnable
where Parser.Input == AIMessage {
    public typealias Input = AIMessage
    public typealias Output = Parser.Output

    public let parser: Parser
    public let fixer: Fixer
    public let maxRetries: Int

    public init(parser: Parser, fixer: Fixer, maxRetries: Int = 1) {
        self.parser = parser
        self.fixer = fixer
        self.maxRetries = max(0, maxRetries)
    }

    public func invoke(_ input: AIMessage) async throws -> Output {
        var current = input
        var attempt = 0
        while true {
            do {
                return try await parser.invoke(current)
            } catch {
                if attempt >= maxRetries { throw error }
                attempt += 1
                let fixed = try await askFixer(current.content, error: error)
                current = fixed
            }
        }
    }

    private func askFixer(_ rawOutput: String, error: any Error) async throws -> AIMessage {
        let messages: [any Message] = [
            SystemMessage(content: """
                You are a strict JSON / structured-output repair tool. The user will give you a
                malformed response and the parser error. Return only the corrected output —
                no commentary, no code fences.
                """),
            HumanMessage(content: """
                Parser error: \(error)

                Original output:
                \(rawOutput)

                Return the corrected output:
                """)
        ]
        return try await fixer.invoke(messages)
    }
}
