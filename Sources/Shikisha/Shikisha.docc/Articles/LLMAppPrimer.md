# A Swift Developer's Primer on LLM Apps

The vocabulary of AI tooling, explained in terms you already know.

## Overview

If you've built apps but never worked with large language models (LLMs), the ecosystem can
feel like a wall of jargon — embeddings, RAG, agents, tokens, vector stores. None of it is
magic. This article maps each concept to ideas you already use as a Swift developer, and
points you at the Shikisha type that implements it.

You don't need any of this memorized to start. Skim it once, build something, and come back
when a term shows up.

### What a language model actually is

A chat model is, mechanically, a function: you give it a list of messages, it gives you back
one message. That's the whole interface — ``ChatModel`` is literally
`Runnable<[any Message], AIMessage>`.

```swift
let reply: AIMessage = try await model.invoke([
    SystemMessage(content: "You are a helpful assistant."),
    HumanMessage(content: "Summarize this in one line: ...")
])
```

The model has no memory of previous calls and no access to your data. Everything it "knows"
for a given call is whatever you put in those messages. Most of what frameworks like Shikisha
do is help you *assemble the right messages* and *do something useful with the reply*.

### Messages and roles

A conversation is an array of messages, each with a role:

- ``SystemMessage`` — instructions and persona ("you are a terse code reviewer").
- ``HumanMessage`` — input from the user (and optionally images, via attachments).
- ``AIMessage`` — the model's reply (may include tool calls and token usage).
- ``ToolMessage`` — the result of running a tool, fed back to the model.

See <doc:ChatModels> for how messages flow through a model.

### Tokens

Models don't see characters or words; they see *tokens* — chunks of text roughly ¾ of a word
each. Two things make tokens matter in practice:

- **Context window**: a model can only consider so many tokens at once. Long histories must be
  trimmed or summarized (see <doc:Memory> and ``trimMessages(_:maxTokens:counter:strategy:pinSystemMessages:)``).
- **Cost**: providers bill per token. Shikisha can count tokens (``TokenCounter``) and track
  spend (<doc:Observability>).

### Prompts and prompt templates

A *prompt* is just the text/messages you send. A *prompt template* is a reusable message with
named holes you fill in at runtime — like a format string, but for chat:

```swift
let prompt = ChatPromptTemplate.fromTuples([
    .system("You translate English to {language}."),
    .human("{text}")
])
let messages = try prompt.formatMessages(["language": "Japanese", "text": "Good morning"])
```

See <doc:Prompts>.

### Output parsers

The model returns text. An *output parser* turns that text into something your code can use —
a `String`, a `[String]`, a JSON object, or a typed `Decodable` value. Parsers are just
runnables you pipe onto the end of a chain. See <doc:OutputParsers> and <doc:StructuredOutput>.

### Embeddings

An *embedding* is a vector (an array of `Float`) that represents the meaning of a piece of
text. Similar meanings produce vectors that are close together, so you can measure "how
related are these two texts?" with simple math instead of keyword matching.

```swift
let vectors = try await embeddings.embedDocuments(["a fast car", "a quick automobile"])
// the two vectors will be close, despite sharing no words
```

This is the foundation of semantic search. See <doc:EmbeddingsAndVectorStores>.

### Vector stores

A *vector store* is a database for embeddings. You add documents (it embeds and stores them),
then query by *meaning*: "give me the chunks most similar to this question." Shikisha ships
in-memory, JSON-file, and SQLite stores (``VectorStore``).

### Retrievers and RAG

A *retriever* fetches the documents relevant to a query (``Retriever`` is
`Runnable<String, [Document]>`). **Retrieval-Augmented Generation (RAG)** is the dominant
pattern for "chat with my data": retrieve the relevant chunks, stuff them into the prompt as
context, and ask the model to answer using them. This grounds answers in your data and reduces
made-up facts. See <doc:Retrievers> and the <doc:tutorials/Shikisha> RAG tutorial.

### Tools and agents

A *tool* is a Swift function you expose to the model (``Tool``) — "look up the weather",
"search the database", "add two numbers". An *agent* is a loop: the model decides which tool to
call, your code runs it, the result goes back to the model, and it repeats until it has a final
answer (``ToolCallingAgent``). This is how a model takes actions in the world rather than just
producing text. See <doc:AgentsAndTools>.

### Streaming

Instead of waiting for the whole reply, *streaming* delivers it incrementally so you can render
tokens as they arrive — the "typing" effect. Every ``ChatModel`` exposes `stream(_:)`, which
returns an `AsyncThrowingStream` of ``AIMessageChunk`` values. See <doc:ChatModels>.

### Memory

Because models are stateless, you store the conversation yourself and replay the relevant part
each turn. That store is *memory* (``ChatMemory``) — buffered, windowed, token-bounded, or
summarized. See <doc:Memory>.

### Graphs

Real apps aren't always a straight line — they loop, branch, and retry (plan → act → reflect,
or "retry until the output validates"). A ``StateGraph`` models that as nodes operating on a
shared state with conditional edges. See <doc:Graphs>.

## Where to go next

- <doc:CoreConcepts> — how all of this composes through one protocol.
- <doc:GettingStarted> — install and run your first chain.
- <doc:tutorials/Shikisha> — build a chatbot, a RAG app, and an agent step by step.
