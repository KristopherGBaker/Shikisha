# Structured Output

Get typed Swift values back from a model — reliably.

## Overview

Free-form text is hard to act on programmatically. *Structured output* asks the model for JSON
matching a schema, then decodes it into a `Decodable` Swift type. Use it whenever the model's
answer feeds back into code: extraction, classification, form filling, function arguments.

There are two pieces:

1. Describe the desired shape with ``JSONSchema`` and tell the provider to honor it.
2. Decode the reply into your type with ``StructuredOutputParser`` (or the
   `asStructuredOutput(_:)` convenience).

### Describe the shape

``JSONSchema`` builds JSON-Schema values from Swift:

```swift
let schema = JSONSchema.object(
    properties: [
        "title": JSONSchema.string(description: "Name of the dish"),
        "ingredients": JSONSchema.array(items: JSONSchema.string()),
        "minutes": JSONSchema.integer(description: "Total time in minutes"),
        "vegetarian": JSONSchema.boolean()
    ],
    required: ["title", "ingredients", "minutes"]
)
```

### Constrain the model

Pass the schema through the provider's response-format option so the model is *forced* to emit
matching JSON. For OpenAI:

```swift
let model = OpenAIChatModel(
    config: cfg,
    model: "gpt-4o-mini",
    responseFormat: OpenAIResponseFormat.jsonSchema(name: "recipe", schema: schema)
)
```

``OpenAIResponseFormat`` also offers `jsonObject()` for "any valid JSON". Ollama accepts a
`format:` schema, and Google/Anthropic support similar constraints.

### Decode into a type

```swift
struct Recipe: Decodable {
    let title: String
    let ingredients: [String]
    let minutes: Int
    let vegetarian: Bool?
}

let recipe = try await (model |> StructuredOutputParser<Recipe>()).invoke([
    HumanMessage(content: "Give me a quick miso soup recipe.")
])
```

### One-step convenience

``ChatModel/asStructuredOutput(_:decoder:)`` bundles "invoke the model, decode the reply" into a
single `Runnable<[any Message], Output>`:

```swift
let structured = model.asStructuredOutput(Recipe.self)
let recipe = try await structured.invoke([HumanMessage(content: "A quick ramen recipe.")])
```

### Tips

- Make optional fields `Optional` in your Swift type; models occasionally omit them.
- Combine with ``OutputFixingParser`` (see <doc:OutputParsers>) when using a model that can't be
  strictly constrained, so malformed JSON gets repaired and retried.
- For streaming a structured value into a live UI, use ``PartialJSON`` to decode the partial
  buffer as it arrives.

## Topics

### Schema

- ``JSONSchema``
- ``JSONValue``

### Decoding

- ``StructuredOutputParser``
- ``StructuredOutputRunnable``

## See Also

- <doc:OutputParsers>
- <doc:ChatModels>
