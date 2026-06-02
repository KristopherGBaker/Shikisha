# Prompts

Reusable, parameterized instructions for the model.

## Overview

A prompt template is a message (or set of messages) with named placeholders you fill in at
runtime — a format string for LLMs. Keeping prompts as templates separates *what you ask* from
*the values you ask about*, so you can reuse, test, and tune them independently.

- ``PromptTemplate`` — a single string template (`[String: any Sendable] -> String`).
- ``ChatPromptTemplate`` — multiple role-tagged messages
  (`[String: any Sendable] -> [any Message]`).

Both are `Runnable`, so they sit at the front of a chain.

### String templates

```swift
let prompt = PromptTemplate.fromTemplate("Translate to {language}: {text}")
let text = try prompt.format(["language": "French", "text": "Good evening"])
```

Pre-fill some variables now and the rest later with `partial(_:)`:

```swift
let french = prompt.partial(["language": "French"])
let text = try french.format(["text": "Good evening"])
```

### Chat templates

`fromTuples` is the quickest way to build a multi-message prompt:

```swift
let prompt = ChatPromptTemplate.fromTuples([
    .system("You are a {role}."),
    .human("{question}")
])
let messages = try prompt.formatMessages(["role": "tutor", "question": "What is a monad?"])
```

The tuple cases are `.system`, `.human`, `.ai`, and `.placeholder` (see below). Pipe the
template straight into a model:

```swift
let chain = prompt |> model |> StringOutputParser()
```

### Injecting prior messages with a placeholder

Use `.placeholder` (or ``MessagesPlaceholder``) to splice in a list of messages — typically
conversation history from <doc:Memory>:

```swift
let prompt = ChatPromptTemplate.fromTuples([
    .system("You are a helpful assistant."),
    .placeholder("history"),
    .human("{question}")
])
let messages = try prompt.formatMessages([
    "history": previousMessages,   // [any Message]
    "question": "And what about Kyoto?"
])
```

Mark a placeholder `optional: true` if the variable may be absent.

### Few-shot prompting

Give the model worked examples to steer its format and behavior. ``FewShotChatPromptTemplate``
formats a set of examples and inserts them before your final question. Pair it with an
*example selector* to choose which examples to include:

- ``FixedExampleSelector`` — always use the same top *K* examples.
- ``SemanticSimilarityExampleSelector`` — pick the examples most similar to the current input
  (uses an ``Embeddings`` model), so the demonstrations are relevant to each query.

```swift
let fewShot = FewShotChatPromptTemplate(
    exampleTemplate: HumanMessageTemplate("Q: {input}\nA: {output}"),
    exampleToVariables: { (pair: (q: String, a: String)) in ["input": pair.q, "output": pair.a] },
    examples: [("2+2", "4"), ("3*3", "9")],
    selector: FixedExampleSelector(topK: 2),
    suffix: ChatPromptTemplate.fromTuples([.human("Q: {input}\nA:")])
)
let messages = try await fewShot.invoke(["input": "10-4"])
```

**Use few-shot when** zero-shot instructions aren't enough to lock in a tricky output format or
a domain-specific style. Use semantic selection when you have a large example bank and only want
the handful relevant to each query.

## Topics

### Templates

- ``PromptTemplate``
- ``ChatPromptTemplate``
- ``SystemMessageTemplate``
- ``HumanMessageTemplate``
- ``AIMessageTemplate``
- ``MessagesPlaceholder``

### Few-shot

- ``FewShotChatPromptTemplate``
- ``ExampleSelector``
- ``FixedExampleSelector``
- ``SemanticSimilarityExampleSelector``

## See Also

- <doc:ChatModels>
- <doc:Memory>
- <doc:OutputParsers>
