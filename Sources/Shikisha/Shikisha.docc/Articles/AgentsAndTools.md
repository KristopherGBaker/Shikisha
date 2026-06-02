# Agents and Tools

Let the model call your Swift functions and act, not just talk.

## Overview

A *tool* is a Swift function you expose to the model — look something up, do a calculation, hit
an API. An *agent* runs the loop that makes tools useful: the model decides which tool to call,
your code runs it, the result goes back to the model, and it repeats until it produces a final
answer.

- ``Tool`` — `name`, `description`, an `inputSchema`, and `execute(arguments:)`.
- ``ToolCallingAgent`` — drives the call→execute→observe loop using a model's native tool calling.
- ``ReActAgent`` — a prompt-based agent (Reason+Act) for models without native tool calling.

### Defining a tool

The quickest tool is ``SimpleTool`` (raw ``JSONValue`` arguments):

```swift
let weather = SimpleTool(
    name: "get_weather",
    description: "Current weather for a city.",
    inputSchema: JSONSchema.object(
        properties: ["city": JSONSchema.string(description: "City name")],
        required: ["city"]
    ),
    execute: { args in
        let city = args["city"]?.stringValue ?? "?"
        return "It's 22°C and sunny in \(city)."
    }
)
```

For type safety, ``TypedTool`` decodes the arguments into a `Decodable` struct for you:

```swift
struct AddArgs: Decodable { let a: Int; let b: Int }

let add = TypedTool(
    name: "add",
    description: "Add two integers.",
    inputSchema: JSONSchema.object(
        properties: ["a": JSONSchema.integer(), "b": JSONSchema.integer()],
        required: ["a", "b"]
    ),
    execute: { (args: AddArgs) in String(args.a + args.b) }
)
```

Tools return a `String` (the observation the model sees). Write clear `description`s — that's
how the model knows when to use each one.

### Running an agent

``ToolCallingAgent`` handles everything; you give it a model and the tools:

```swift
let agent = ToolCallingAgent(model: model, tools: [weather, add], maxIterations: 8)
let result = try await agent.run([HumanMessage(content: "What's the weather in Kyoto, and what's 7+5?")])

print(result.finalMessage.content)
print("took \(result.iterations) iterations")
for message in result.trace { /* full step-by-step transcript */ }
```

``AgentResult`` gives you the final message, the iteration count, and the complete `trace` —
handy for debugging or showing the user the agent's work.

`maxIterations` caps the loop so a confused model can't spin forever.

### ReAct vs. tool calling

- Use ``ToolCallingAgent`` with models that support native tool/function calling (OpenAI,
  Anthropic, Gemini, tool-capable Ollama models). It's more reliable.
- Use ``ReActAgent`` when the model has no tool-calling API; it prompts the model to emit
  Thought/Action/Observation steps as text. Call `run(question:)`.

### Running tools yourself

If you want to handle the loop manually, ``ToolExecutor`` runs a single ``ToolCall`` and returns
a ``ToolMessage`` (capturing errors as `isError`):

```swift
let executor = ToolExecutor(tools: [weather, add])
let toolMessage = await executor.run(reply.toolCalls[0])
```

### Observability

Pass a ``CallbackManager`` to the agent to trace tool starts/ends, model calls, and each
iteration — see <doc:Observability>.

## Topics

### Tools

- ``Tool``
- ``SimpleTool``
- ``TypedTool``
- ``ToolExecutor``

### Agents

- ``ToolCallingAgent``
- ``ReActAgent``
- ``AgentResult``

## See Also

- <doc:ChatModels>
- <doc:Graphs>
- <doc:Observability>
