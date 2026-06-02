# Retrievers and RAG

Find the right documents for a query, then answer with them.

## Overview

A retriever fetches the documents relevant to a query string — ``Retriever`` is
`Runnable<String, [Document]>`. Retrieval-Augmented Generation (RAG) builds on that: retrieve
the relevant chunks, put them in the prompt as context, and ask the model to answer using them.
This grounds answers in *your* data and cuts down on hallucination.

Shikisha ships many retrieval strategies — from a plain vector search to query rewriting and
result compression — all sharing the same protocol so you can swap and combine them.

### The simplest retriever

Turn a vector store into a retriever and use it:

```swift
let retriever = store.asRetriever(topK: 4)
let docs = try await retriever.retrieve("How do I stream a reply?")
```

### A full RAG chain in one line

``RagChain`` wires retriever + prompt + model into a `Runnable<String, String>`.
`defaultRagChain(retriever:model:)` supplies a sensible "answer from context" prompt:

```swift
let chain = defaultRagChain(retriever: retriever, model: model)
let answer = try await chain.invoke("What platforms does Shikisha support?")
```

Bring your own prompt (it must reference `{context}` and `{question}`):

```swift
let prompt = ChatPromptTemplate.fromTuples([
    .system("Answer using only this context. Cite sources.\n\n{context}"),
    .human("{question}")
])
let chain = RagChain(retriever: retriever, prompt: prompt, model: model)
```

### Choosing a retrieval strategy

| Retriever | What it does | Reach for it when… |
| --- | --- | --- |
| ``VectorStoreRetriever`` | semantic similarity search | the default; meaning-based matching |
| ``BM25Retriever`` | classic keyword/lexical ranking | exact terms, names, codes matter |
| ``HybridRetriever`` | fuses several retrievers (RRF) | you want keyword **and** semantic recall |
| ``MmrRetriever`` | maximal marginal relevance | results are too redundant; you want diversity |
| ``MultiQueryRetriever`` | rewrites the query N ways, then merges | one phrasing misses relevant docs |
| ``ParentDocumentRetriever`` | searches small chunks, returns their parents | precise matching but full-context answers |
| ``TimeWeightedRetriever`` | blends similarity with recency | freshness matters (notes, news) |
| ``SelfQueryingRetriever`` | infers metadata filters from the query | queries imply structured constraints |
| ``ContextualCompressionRetriever`` | post-processes hits to keep only relevant parts | long chunks dilute the prompt |

### Keyword and hybrid search

`BM25Retriever` ranks by term overlap (no embeddings). Combine it with a vector retriever via
`HybridRetriever`, which fuses rankings with Reciprocal Rank Fusion:

```swift
let bm25 = BM25Retriever(topK: 8)
await bm25.addDocuments(chunks)

let hybrid = HybridRetriever(retrievers: [store.asRetriever(topK: 8), bm25], topK: 4)
```

### Diversity and query expansion

```swift
// MMR needs an InMemoryVectorStore; it trades some relevance for variety via `lambda`.
let mmr = MmrRetriever(store: inMemoryStore, topK: 4, fetchK: 20, lambda: 0.5)

// MultiQuery uses a model to paraphrase the question, broadening recall.
let multi = MultiQueryRetriever(base: retriever, queryGenerator: model, count: 3, topK: 4)
```

### Small-to-big and recency

```swift
// Index small child chunks for precision, but return the larger parent for context.
let parent = ParentDocumentRetriever(childStore: store)
try await parent.addDocuments(parents, childSplitter:
    RecursiveCharacterTextSplitter(chunkSize: 400, chunkOverlap: 50))

// Decay older documents so recent ones surface first.
let recent = TimeWeightedRetriever(store: store, decayRate: 0.01)
```

### Self-querying

Let the model translate a natural-language query into a metadata filter plus a search string —
useful when users say things like *"Swift posts from 2025"*:

```swift
let selfQuery = SelfQueryingRetriever(
    base: retriever,
    model: model,
    attributeDescriptions: [
        .init(name: "language", type: "string", description: "Programming language"),
        .init(name: "year", type: "int", description: "Year published")
    ]
)
```

### Contextual compression

Retrieved chunks are often longer than needed. ``ContextualCompressionRetriever`` runs hits
through a ``DocumentCompressor`` before they reach the prompt — keeping tokens (and cost) down:

- ``LLMChainExtractor`` — extract only the sentences relevant to the query.
- ``LLMListFilter`` — drop irrelevant documents entirely.
- ``LLMReranker`` — reorder/trim by model-judged relevance (`topN`, `scoreThreshold`).
- ``EmbeddingsFilter`` — cheap, model-free filter by embedding similarity threshold.
- ``DocumentCompressorPipeline`` — chain several compressors together.

```swift
let compressed = ContextualCompressionRetriever(
    base: retriever,
    compressor: DocumentCompressorPipeline([
        EmbeddingsFilter(embeddings: embeddings, similarityThreshold: 0.7),
        LLMChainExtractor(model: model)
    ])
)
```

### Putting it together

A production retriever often layers strategies: hybrid search for recall → reranking/compression
for precision → `RagChain` for the answer. Because each layer is a `Retriever`, you nest them
freely, then hand the outermost one to `RagChain`.

## Topics

### Core

- ``Retriever``
- ``RagChain``
- ``VectorStoreRetriever``

### Strategies

- ``BM25Retriever``
- ``HybridRetriever``
- ``MmrRetriever``
- ``MultiQueryRetriever``
- ``ParentDocumentRetriever``
- ``TimeWeightedRetriever``
- ``SelfQueryingRetriever``

### Compression

- ``ContextualCompressionRetriever``
- ``DocumentCompressor``
- ``DocumentCompressorPipeline``
- ``LLMChainExtractor``
- ``LLMListFilter``
- ``LLMReranker``
- ``EmbeddingsFilter``

## See Also

- <doc:EmbeddingsAndVectorStores>
- <doc:Documents>
- <doc:Indexing>
