# BYOK Sample Vector DB

Sample BYOK (Bring Your Own Knowledge) vector database for the AI Rolling Demo.

Source docs live in `docs/` — the vector DB is generated at build time using [rag-content](https://github.com/lightspeed-core/rag-content) and is not checked into git.

## Prerequisites

1. Clone [rag-content](https://github.com/lightspeed-core/rag-content)
2. Set up a virtualenv: `cd rag-content && uv venv && uv pip install -e .`

## Adding documents

Place your source documents in `docs/`. Supported formats: `.md`, `.txt`, `.pdf`, `.html`.

For Google Docs: **File > Download > Markdown (.md)**, then place the exported file in `docs/`.

To enable source citations, add YAML frontmatter with a `url:` field at the top of each doc. rag-content's `MetadataProcessor` reads this automatically and uses it as the citation link. If no frontmatter URL is present, it falls back to the URL defined in `custom_processor.py`.

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
1. Download the embedding model (if not already present)
2. Process all docs in `docs/` into a FAISS vector DB
3. Build and push the container image
4. Print the `vector_store_id` to update in `lightspeed-stack.yaml`

To generate the vector DB only (no container build), omit `BYOK_IMAGE`:

```bash
RAG_CONTENT_REPO=/path/to/rag-content ./build-vector-db.sh
```

To use a different docs directory:

```bash
RAG_CONTENT_REPO=/path/to/rag-content ./build-vector-db.sh /path/to/your/docs
```

To generate an additional store without replacing `custom_docs`, set a unique
store directory and RAG ID. For example, the Maysun test store is reproduced
with:

```bash
RAG_CONTENT_REPO=/path/to/rag-content \
STORE_NAME=maysun-subway-test \
RAG_ID=maysun-subway-test \
./build-vector-db.sh ./test-docs
```

After both stores have been generated, build and push a combined image:

```bash
podman build \
  --platform linux/amd64,linux/arm64 \
  --manifest localhost/rhdh-byok-combined-test:latest \
  -f Containerfile .
podman manifest push \
  --all localhost/rhdh-byok-combined-test:latest \
  docker://quay.io/<org>/rhdh-byok-combined-test:latest
```

The image stores databases below `/byok/vector_db`. The rolling-demo init
containers copy them into `/rag-content/vector_db`, which is the path that must
be used in `lightspeed-stack.yaml`.

## Configuration

After building, update `lightspeed-stack.yaml` with the vector store ID printed by the script:

- **Embedding model:** `sentence-transformers/all-mpnet-base-v2` (dimension 768)
- **Image path:** `/byok/vector_db/custom_docs/faiss_store.db`
- **Lightspeed runtime path:** `/rag-content/vector_db/custom_docs/faiss_store.db`
