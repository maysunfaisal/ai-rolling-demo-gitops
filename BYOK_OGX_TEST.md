# OGX BYOK Test Notes

Date: 2026-09-13

This records the local OGX vector-store experiment for a small custom BYOK document and the issues found in the existing rolling-demo BYOK configuration.

## Test document

Source file:

`byok/test-docs/maysun-subway-test.md`

Document text:

> The quick brown fox jumped over the lazy Maysun while he was eating Subway.

The document frontmatter uses:

```yaml
title: Maysun Subway Test Knowledge
url: https://github.com/maysunfaisal
```

## Generated OGX vector store

- RAG ID: `maysun-subway-test`
- Vector-store ID: `vs_5785a2a1-6257-43de-ab08-820198985661`
- Embedding model: `sentence-transformers/all-mpnet-base-v2`
- Embedding dimension: `768`
- Local database: `byok/vector_db/maysun-subway-test/faiss_store.db`
- Expected container database path: `/rag-content/vector_db/maysun-subway-test/faiss_store.db`

The generated vector-store directory is ignored by Git; the Markdown source document is tracked.

## Combined local image

The original local image tag is:

`localhost/rhdh-byok-combined-test:latest`

It contains two independent vector stores at different paths:

```text
/byok/vector_db/custom_docs/faiss_store.db
/byok/vector_db/maysun-subway-test/faiss_store.db
```

After the rolling-demo init containers copy the content into the shared RAG volume, the expected runtime paths are:

```text
/rag-content/vector_db/custom_docs/faiss_store.db
/rag-content/vector_db/maysun-subway-test/faiss_store.db
```

The combined AMD64/ARM64 image is published as
`quay.io/mfaisal2/rhdh-byok-combined-test:latest` and is wired into the Helm
chart for the cluster test.

## Query test

The upstream `rag-content` query helper was run against the generated portable store:

```bash
uv run python scripts/query_rag.py \
  -p /private/tmp/maysun-subway-ogx-portable.fzqpAH/output \
  -x maysun-subway-test \
  -m '' \
  -k 5 \
  -q 'What was Maysun doing when the quick brown fox jumped over him?' \
  --json
```

The query succeeded and returned the custom sentence as the highest-ranked result:

```json
{
  "query": "What was Maysun doing when the quick brown fox jumped over him?",
  "top_k": 5,
  "threshold": 0.0,
  "nodes": [
    {
      "id": "e90e5483-0a9c-4047-a7d5-c4cca919d832",
      "score": 1.440025268998098,
      "text": "# Maysun Subway Test Knowledge\n\nThe quick brown fox jumped over the lazy Maysun while he was eating Subway.",
      "metadata": {
        "docs_url": "https://github.com/maysunfaisal",
        "title": "Maysun Subway Test Knowledge",
        "url_reachable": true,
        "header_path": "/",
        "document_id": "file-20816b37ea3246c7a32e1753723ec392",
        "source": "maysun-subway-test"
      }
    },
    {
      "id": "4cf07da7-60e0-449b-93cb-b99ce829ce10",
      "score": 0.5786820512640093,
      "text": "---\ntitle: Maysun Subway Test Knowledge\nurl: https://github.com/maysunfaisal\n---",
      "metadata": {
        "docs_url": "https://github.com/maysunfaisal",
        "title": "Maysun Subway Test Knowledge",
        "url_reachable": true,
        "header_path": "/",
        "document_id": "file-20816b37ea3246c7a32e1753723ec392",
        "source": "maysun-subway-test"
      }
    }
  ]
}
```

The substantive document chunk ranked first. The frontmatter was also indexed as a separate, lower-scoring chunk.

## OpenShift and Intelligent Assistant verification

The test branch was deployed to the `rolling-demo-ns` namespace with
`make install-no-rhoai` on 2026-09-13.

### Lightspeed startup and vector stores

- The `rolling-demo-backstage` pod reached `3/3 Running` with zero restarts.
- The `byok-rag-init` and `lightspeed-rag-init` containers completed with exit
  code `0`.
- The BYOK init logs reported `BYOK staging complete` and `BYOK merge complete`.
- Both non-empty FAISS databases were present in the Lightspeed container:

  ```text
  /rag-content/vector_db/custom_docs/faiss_store.db
  /rag-content/vector_db/maysun-subway-test/faiss_store.db
  ```

- Lightspeed logged that it added two BYOK storage backends, two vector I/O
  providers, two registered vector stores, and two embedding models.
- The `/readiness` endpoint returned HTTP `200` with `ready: true` and an
  overall status of `healthy`.
- The `/v1/rags` endpoint listed `custom-org-docs`, `okp`, and
  `maysun-subway-test`.
- The `/v1/vector-stores` endpoint reported both BYOK stores with a status of
  `completed`:

  ```text
  vs_fae456e2-95b1-47e9-8b2d-0dd5f354c0cb  custom-org-docs
  vs_5785a2a1-6257-43de-ab08-820198985661  maysun-subway-test
  ```

### Intelligent Assistant retrieval test

The following prompt was submitted through the RHDH Intelligent Assistant:

> In the Maysun Subway Test Knowledge document used to test RHDH BYOK
> retrieval, what was Maysun eating when the quick brown fox jumped over him?

The assistant answered:

> In the Maysun Subway Test Knowledge document, Maysun was eating Subway when
> the quick brown fox jumped over him.

The retrieval result confirms that the answer came from the custom store:

- The substantive `maysun-subway-test` chunk ranked first with a score of
  `1.613471859766606`.
- Its text contained the complete Subway test sentence.
- Its metadata identified `source: maysun-subway-test`, title
  `Maysun Subway Test Knowledge`, and citation URL
  `https://github.com/maysunfaisal`.
- A second, lower-scoring chunk contained the document frontmatter.
- The combined retrieval response also contained ten OKP chunks. The UI
  displayed eleven sources, which is consistent with the two chunks from the
  Maysun document sharing one document identity and being presented as one
  source.

This completes the local query-helper test and the end-to-end OpenShift
Intelligent Assistant retrieval test.

## Rolling-demo BYOK issues found and corrected

Three mismatches were present in the existing rolling-demo BYOK configuration:

1. **Vector-store ID mismatch**

   The existing `custom_docs/llama-stack.yaml` in `quay.io/redhat-ai-dev/byok-sample:latest` identifies the store as:

   ```text
   vs_fae456e2-95b1-47e9-8b2d-0dd5f354c0cb
   ```

   The Helm chart previously configured a different ID:

   ```text
   vs_727b6321-1ff4-47bf-a76b-1cc12426c954
   ```

2. **Database-path mismatch**

   The chart previously pointed to:

   ```text
   /tmp/vector_db/custom_docs/faiss_store.db
   ```

   The deployment mounts the shared RAG volume at `/rag-content`, and the init containers place the BYOK database at:

   ```text
   /rag-content/vector_db/custom_docs/faiss_store.db
   ```

3. **Embedding-model mismatch**

   The chart previously configured `nomic-ai/nomic-embed-text-v1.5`, while the existing BYOK store was generated with `sentence-transformers/all-mpnet-base-v2`. Retrieval must use the same embedding model that created the store.

The existing public BYOK image also appears to predate the unified OGX/Lightspeed configuration format: it contains `faiss_store.db` and `llama-stack.yaml`, but no generated `lightspeed-stack.yaml`. The compatibility name `llamastack-faiss` is still used by the current OGX tooling and is not itself evidence that the database is invalid.

The working-tree chart now corrects all three mismatches and adds the
`maysun-subway-test` store as a retrieval source. Cluster deployment and chatbot
verification remain pending until `make install-no-rhoai` is run.

## Proposed chart entry for the test store

The test store is represented in the unified Lightspeed configuration as:

```yaml
- rag_id: maysun-subway-test
  backend: faiss
  embedding_model: sentence-transformers/all-mpnet-base-v2
  embedding_dimension: 768
  vector_db_id: vs_5785a2a1-6257-43de-ab08-820198985661
  db_path: /rag-content/vector_db/maysun-subway-test/faiss_store.db
```
