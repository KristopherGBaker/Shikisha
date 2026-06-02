# Documents: Loading and Splitting

Get your content into the pipeline and chop it into model-sized chunks.

## Overview

Before you can search or reason over your data, you need it as ``Document`` values — text plus
metadata. Two kinds of helper do this:

- **Loaders** read a source (file, web page, JSON, CSV, PDF) into `[Document]`.
- **Text splitters** break long documents into smaller, overlapping chunks that fit a model's
  context window and make retrieval precise.

This is the first half of a RAG pipeline (see <doc:Retrievers>).

### The Document type

```swift
let doc = Document(
    pageContent: "Shikisha is a Swift port of LangChain.",
    metadata: ["source": "readme.md", "section": "intro"]
)
```

Metadata is `[String: JSONValue]` and travels with the chunk through embedding, storage, and
retrieval — so you can filter and cite by it later.

### Loaders

All loaders conform to ``DocumentLoader`` and expose `async func load() -> [Document]`:

```swift
let text = try await TextDocumentLoader(url: fileURL).load()
let md   = try await MarkdownDocumentLoader(url: fileURL).load()   // splits on headers
let html = try await HTMLDocumentLoader(url: fileURL).load()       // strips tags to text
let pdf  = try await PDFDocumentLoader(url: fileURL).load()        // page-by-page (PDFKit)

// JSON: pull text from a field, optionally over an array, and copy fields into metadata.
let json = try await JSONDocumentLoader(
    url: fileURL,
    arrayPath: "items",
    textFieldPath: "body",
    metadataFields: ["author", "createdAt"]
).load()

// CSV: one document per row; choose which column is the content.
let csv = try await CsvDocumentLoader(url: fileURL, contentColumn: "review").load()
```

`CsvDocumentLoader` also has a `from(string:)` helper for in-memory CSV.

**Pick a loader by source format.** Markdown and PDF loaders preserve useful structure
(headers, pages) in metadata.

### Text splitters

Embeddings and prompts work best on focused chunks, not whole documents. Splitters conform to
``TextSplitter`` and provide `splitText` and `splitDocuments`:

```swift
// Recommended general-purpose splitter: respects paragraph/sentence/word boundaries.
let splitter = RecursiveCharacterTextSplitter(chunkSize: 1000, chunkOverlap: 200)
let chunks = splitter.splitDocuments(documents)
```

`chunkOverlap` repeats a little text between adjacent chunks so a sentence split across a
boundary still appears whole somewhere — which improves retrieval recall.

Other options:

- ``CharacterTextSplitter`` — split on a single separator; simplest, least structure-aware.
- ``RecursiveCharacterTextSplitter/markdown(chunkSize:chunkOverlap:)`` and `.code(...)` — presets
  with separators tuned for Markdown and source code.
- ``MarkdownHeaderTextSplitter`` — split by header level and record the heading path in metadata
  (e.g. `h1`, `h2`), so each chunk knows where it came from.

### A typical load-and-split

```swift
let raw = try await MarkdownDocumentLoader(url: docURL).load()
let chunks = RecursiveCharacterTextSplitter.markdown(chunkSize: 800, chunkOverlap: 100)
    .splitDocuments(raw)
// chunks are now ready to embed and store — see EmbeddingsAndVectorStores.
```

## Topics

### Documents

- ``Document``
- ``DocumentLoader``

### Loaders

- ``TextDocumentLoader``
- ``MarkdownDocumentLoader``
- ``HTMLDocumentLoader``
- ``JSONDocumentLoader``
- ``CsvDocumentLoader``
- ``PDFDocumentLoader``

### Splitters

- ``TextSplitter``
- ``RecursiveCharacterTextSplitter``
- ``CharacterTextSplitter``
- ``MarkdownHeaderTextSplitter``

## See Also

- <doc:EmbeddingsAndVectorStores>
- <doc:Retrievers>
- <doc:Indexing>
