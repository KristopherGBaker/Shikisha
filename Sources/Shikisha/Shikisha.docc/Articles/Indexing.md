# Indexing

Keep a vector store in sync with changing sources — without re-embedding everything.

## Overview

Your knowledge base changes: documents get added, edited, and deleted. Re-embedding and
re-inserting *everything* on each run is slow and expensive. The ``index(documents:vectorStore:recordManager:namespace:cleanup:sourceKey:)``
function does incremental indexing: it hashes each document, remembers what it has seen via a
``RecordManager``, and only writes what actually changed.

### How it works

For each document, `index` computes a content hash keyed by its *source*. Comparing against the
record manager, it decides per document:

- **added** — new source → embed and insert.
- **updated** — known source, changed content → re-embed and replace.
- **skipped** — known source, identical content → do nothing (the win).
- **deleted** — only with cleanup (see below).

It returns an ``IndexResult`` with the counts.

```swift
let recordManager = InMemoryRecordManager()

let result = try await index(
    documents: chunks,
    vectorStore: store,
    recordManager: recordManager
)
print("added \(result.added), updated \(result.updated), skipped \(result.skipped)")
```

### Cleanup modes

``IndexCleanupMode`` controls what happens to previously-indexed documents that are *absent*
from this run:

- `.none` — leave them; only add/update/skip.
- `.full` — delete documents in the namespace that weren't part of this batch (true sync —
  removals propagate).

```swift
let result = try await index(
    documents: currentChunks,
    vectorStore: store,
    recordManager: recordManager,
    cleanup: .full
)
```

### Namespaces and source keys

- `namespace` isolates independent indexes that share one store/record manager (e.g. per user
  or per collection).
- `sourceKey` tells `index` how to group chunks back to their origin document so edits and
  deletions are tracked correctly. By default it reads `metadata["source"]`, then the document
  `id`. Set `metadata["source"]` on your documents (the loaders do this) for reliable updates.

### Persisting the record manager

Use ``InMemoryRecordManager`` for tests and short-lived runs. For real apps, persist the
bookkeeping with ``JsonFileRecordManager`` so incremental indexing survives restarts:

```swift
let recordManager = try JsonFileRecordManager(file: recordsURL)
```

### A typical re-index job

```swift
let chunks = RecursiveCharacterTextSplitter().splitDocuments(
    try await loadAllSources()   // your loaders -> [Document] with metadata["source"]
)
let result = try await index(
    documents: chunks,
    vectorStore: store,
    recordManager: recordManager,
    cleanup: .full
)
```

Run it whenever sources change; only the diff is embedded.

## Topics

### Indexing

- ``index(documents:vectorStore:recordManager:namespace:cleanup:sourceKey:)``
- ``IndexResult``
- ``IndexCleanupMode``

### Record managers

- ``RecordManager``
- ``InMemoryRecordManager``
- ``JsonFileRecordManager``

## See Also

- <doc:Documents>
- <doc:EmbeddingsAndVectorStores>
- <doc:Retrievers>
