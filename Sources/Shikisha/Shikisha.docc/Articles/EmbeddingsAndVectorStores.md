# Embeddings and Vector Stores

Turn text into vectors and search it by meaning.

## Overview

An *embedding* maps text to a vector of `Float` so that similar meanings land near each other.
A *vector store* holds those vectors and lets you query by similarity — "find the chunks most
like this question" — instead of by exact keywords. Together they power semantic search and the
retrieval half of RAG.

- ``Embeddings`` — `embedDocuments`/`embedQuery`, implemented by each provider.
- ``VectorStore`` — add documents, delete by id, and `similaritySearch`.

### Embeddings

```swift
let embeddings = OpenAIEmbeddings(config: cfg, model: "text-embedding-3-small")
let vectors = try await embeddings.embedDocuments(["a fast car", "a quick automobile"])
let query   = try await embeddings.embedQuery("speedy vehicle")
```

Providers: ``OpenAIEmbeddings``, ``GoogleEmbeddings``, ``OllamaEmbeddings`` (local). You rarely
call these directly — you hand an `Embeddings` to a vector store and it embeds for you.

#### Caching embeddings

Embedding the same text repeatedly wastes calls and money. ``CachingEmbeddings`` wraps any
provider and remembers vectors it has already computed, optionally persisting them:

```swift
let cached = CachingEmbeddings(
    embeddings,
    storage: try FileEmbeddingsCacheStorage(file: cacheURL)
)
```

### Vector stores

All stores share one API and an embeddings model. Add documents, then search:

```swift
let store = InMemoryVectorStore(embeddings: cached)
_ = try await store.addDocuments(chunks)

let hits = try await store.similaritySearch(query: "How do I stream a reply?", topK: 4)
for hit in hits {
    print(hit.score, hit.document.pageContent)
}
```

Pick the store by how long the data must live:

- ``InMemoryVectorStore`` — fastest; great for tests and ephemeral indexes. Required for
  ``MmrRetriever``.
- ``JsonFileVectorStore`` — persists to a JSON file; simple and inspectable.
- ``SqliteVectorStore`` — persists to SQLite; best for larger, longer-lived indexes.

### Metadata filtering

Combine semantic search with structured constraints using ``MetadataFilter`` — only consider
documents whose metadata matches:

```swift
let filter: MetadataFilter = .and([
    .equal(field: "language", value: "swift"),
    .greaterThanOrEqual(field: "year", value: 2024)
])
let hits = try await store.similaritySearch(query: "actors", topK: 5, filter: filter)
```

Filters support `equal`/`notEqual`, the comparisons, `in`, and boolean `and`/`or`/`not`.

### From store to retriever

A vector store becomes a ``Retriever`` (and thus a `Runnable<String, [Document]>`) with one
call, ready to drop into a chain:

```swift
let retriever = store.asRetriever(topK: 4, filter: filter)
```

See <doc:Retrievers> for everything you can do once you have one.

## Topics

### Embeddings

- ``Embeddings``
- ``OpenAIEmbeddings``
- ``GoogleEmbeddings``
- ``OllamaEmbeddings``
- ``CachingEmbeddings``
- ``EmbeddingsCacheStorage``
- ``FileEmbeddingsCacheStorage``

### Vector stores

- ``VectorStore``
- ``VectorSearchResult``
- ``InMemoryVectorStore``
- ``JsonFileVectorStore``
- ``SqliteVectorStore``
- ``MetadataFilter``

## See Also

- <doc:Documents>
- <doc:Retrievers>
- <doc:Indexing>
