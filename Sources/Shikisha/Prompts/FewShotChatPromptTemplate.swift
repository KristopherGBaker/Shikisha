import Foundation

/// Few-shot chat prompt. Renders `prefix` (instructions), then a sequence of example
/// messages selected from `examples` via `selector`, then `suffix` (the actual query template).
public struct FewShotChatPromptTemplate<Example: Sendable, Selector: ExampleSelector>: Sendable, Runnable
where Selector.Example == Example {
    public typealias Input = [String: any Sendable]
    public typealias Output = [any Message]

    public let prefix: ChatPromptTemplate?
    public let exampleTemplate: any ChatMessageTemplate
    public let exampleToVariables: @Sendable (Example) -> [String: any Sendable]
    public let examples: [Example]
    public let selector: Selector
    public let suffix: ChatPromptTemplate

    public init(
        prefix: ChatPromptTemplate? = nil,
        exampleTemplate: any ChatMessageTemplate,
        exampleToVariables: @Sendable @escaping (Example) -> [String: any Sendable],
        examples: [Example],
        selector: Selector,
        suffix: ChatPromptTemplate
    ) {
        self.prefix = prefix
        self.exampleTemplate = exampleTemplate
        self.exampleToVariables = exampleToVariables
        self.examples = examples
        self.selector = selector
        self.suffix = suffix
    }

    public func invoke(_ input: [String: any Sendable]) async throws -> [any Message] {
        var messages: [any Message] = []
        if let prefix {
            messages.append(contentsOf: try prefix.formatMessages(input))
        }
        let selected = try await selector.select(for: input, examples: examples)
        for example in selected {
            let variables = exampleToVariables(example)
            messages.append(contentsOf: try exampleTemplate.format(variables))
        }
        messages.append(contentsOf: try suffix.formatMessages(input))
        return messages
    }
}
