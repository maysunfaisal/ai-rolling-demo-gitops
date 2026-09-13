# BYOK Sample Vector DB

Sample BYOK (Bring Your Own Knowledge) vector database for the AI Rolling Demo.

Source docs live in `docs/` — the vector DB is generated at build time using [rag-content](https://github.com/lightspeed-core/rag-content) and is not checked into git.

## Prerequisites

1. Clone [rag-content](https://github.com/lightspeed-core/rag-content)
2. Install the pinned dependencies: `cd rag-content && uv sync`

## Adding documents

Place Markdown source documents in `docs/`. Convert `.txt`, `.pdf`, or `.html`
content to Markdown before running this repository's build script.

For Google Docs: **File > Download > Markdown (.md)**, then place the exported file in `docs/`.

To enable source citations, add YAML frontmatter with a `url:` field at the top
of each document. The official `rag-content` metadata processor reads this
automatically and uses it as the citation link.

```markdown
---
title: My Document
url: https://docs.google.com/document/d/abc123/edit
---

# Document content starts here...
```

## Build the vector DB and container image

```bash
RAG_CONTENT_REPO=/path/to/rag-content \
BYOK_IMAGE=quay.io/<org>/byok-sample:latest \
./build-vector-db.sh
```

This will:
1. Process all Markdown files in `docs/` into a portable OGX FAISS vector store
2. Generate `faiss_store.db`, `lightspeed-stack.yaml`, and `llama-stack.yaml`
3. Build and push the container image for `linux/amd64` by default
4. Print the generated `vector_store_id` to update in `lightspeed-stack.yaml`

The generator passes an empty model directory and the Hugging Face model ID.
This avoids recording a workstation-specific absolute model path in the OGX
store. At runtime, Lightspeed resolves the same model ID through its
`sentence_transformers` inference provider.

To generate the vector DB only (no container build), omit `BYOK_IMAGE`:

```bash
RAG_CONTENT_REPO=/path/to/rag-content ./build-vector-db.sh
```

To use a different docs directory:

```bash
RAG_CONTENT_REPO=/path/to/rag-content ./build-vector-db.sh /path/to/your/docs
```

## Configuration

After building, update `lightspeed-stack.yaml` with the vector store ID printed by the script:

- **Embedding model:** `sentence-transformers/all-mpnet-base-v2` (dimension 768)
- **Image path:** `/byok/vector_db/custom_docs/faiss_store.db`
- **Lightspeed runtime path:** `/rag-content/vector_db/custom_docs/faiss_store.db`

The image platform defaults to `linux/amd64`, which matches the rolling-demo
OpenShift workers. Set `TARGET_PLATFORM` if a different cluster architecture is
required.
