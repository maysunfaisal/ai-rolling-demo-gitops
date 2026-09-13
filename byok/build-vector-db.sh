#!/usr/bin/env bash
#
# Builds a BYOK FAISS vector DB from source documents and optionally
# builds + pushes a container image.
#
# Supported input formats: .md, .txt, .pdf, .html
# For Google Docs: File > Download > Markdown (.md), then place in docs/
#
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
DOCS_DIR="${1:-$SCRIPT_DIR/docs}"
OUTPUT_DIR="$SCRIPT_DIR/vector_db/custom_docs"
MODEL_NAME="sentence-transformers/all-mpnet-base-v2"
CHUNK_SIZE=512
CHUNK_OVERLAP=128
RAG_CONTENT_REPO="${RAG_CONTENT_REPO:-}"
BYOK_IMAGE="${BYOK_IMAGE:-}"
CONTAINER_ENGINE="${CONTAINER_ENGINE:-podman}"
TARGET_PLATFORM="${TARGET_PLATFORM:-linux/amd64}"

if [ -z "$RAG_CONTENT_REPO" ]; then
  echo "Error: RAG_CONTENT_REPO must be set to the path of your local rag-content clone."
  echo ""
  echo "Usage:"
  echo "  RAG_CONTENT_REPO=/path/to/rag-content BYOK_IMAGE=quay.io/<org>/byok-sample:latest ./build-vector-db.sh [docs_dir]"
  echo ""
  echo "  docs_dir    Directory containing source documents (default: ./docs)"
  echo ""
  echo "Environment variables:"
  echo "  RAG_CONTENT_REPO   (required) Path to local rag-content clone"
  echo "  BYOK_IMAGE         (optional) Container image tag — if set, builds and pushes the image"
  echo "  CONTAINER_ENGINE   (optional) podman or docker (default: podman)"
  echo "  TARGET_PLATFORM    (optional) Image platform (default: linux/amd64)"
  echo ""
  echo "Prerequisites:"
  echo "  1. Clone https://github.com/lightspeed-core/rag-content"
  echo "  2. Install dependencies: cd rag-content && uv sync"
  echo "  3. For Google Docs: export as Markdown via File > Download > Markdown (.md)"
  exit 1
fi

if [ ! -d "$RAG_CONTENT_REPO" ]; then
  echo "Error: RAG_CONTENT_REPO directory not found: $RAG_CONTENT_REPO"
  exit 1
fi

if [ ! -d "$DOCS_DIR" ]; then
  echo "Error: docs directory not found: $DOCS_DIR"
  exit 1
fi

# Build a portable OGX FAISS vector store. An empty model directory records the
# Hugging Face model ID instead of a machine-specific absolute path.
echo "Building portable OGX vector DB from $DOCS_DIR..."
mkdir -p "$(dirname "$OUTPUT_DIR")"
TEMP_OUTPUT_DIR=$(mktemp -d "$(dirname "$OUTPUT_DIR")/.custom_docs.XXXXXX")
trap 'rm -rf "$TEMP_OUTPUT_DIR"' EXIT

(cd "$RAG_CONTENT_REPO" && uv run python scripts/generate_embeddings.py \
  --folder "$DOCS_DIR" \
  --output "$TEMP_OUTPUT_DIR" \
  --index custom-org-docs \
  --vector-store llamastack-faiss \
  --model-dir "" \
  --model-name "$MODEL_NAME" \
  --doc-type markdown \
  --chunk-size "$CHUNK_SIZE" \
  --chunk-overlap "$CHUNK_OVERLAP")

rm -rf "$OUTPUT_DIR"
mv "$TEMP_OUTPUT_DIR" "$OUTPUT_DIR"
trap - EXIT

echo ""
echo "Vector DB built at: $OUTPUT_DIR"

if [ -f "$OUTPUT_DIR/llama-stack.yaml" ]; then
  VECTOR_STORE_ID=$(grep "vector_store_id:" "$OUTPUT_DIR/llama-stack.yaml" | awk '{print $2}')
  echo "Vector store ID: $VECTOR_STORE_ID"
  echo "Update this ID in lightspeed-stack.yaml under rag.byok.stores[].vector_db_id"
fi

# Build and push container image if BYOK_IMAGE is set
if [ -n "$BYOK_IMAGE" ]; then
  echo ""
  echo "Building container image: $BYOK_IMAGE"
  BUILD_CONTEXT=$(mktemp -d "${TMPDIR:-/tmp}/byok-image.XXXXXX")
  trap 'rm -rf "$BUILD_CONTEXT"' EXIT
  mkdir -p "$BUILD_CONTEXT/vector_db"
  cp -R "$OUTPUT_DIR" "$BUILD_CONTEXT/vector_db/custom_docs"
  cp "$SCRIPT_DIR/Containerfile" "$BUILD_CONTEXT/Containerfile"

  $CONTAINER_ENGINE build --platform "$TARGET_PLATFORM" -t "$BYOK_IMAGE" \
    -f "$BUILD_CONTEXT/Containerfile" "$BUILD_CONTEXT"

  echo "Pushing $BYOK_IMAGE..."
  $CONTAINER_ENGINE push "$BYOK_IMAGE"
  rm -rf "$BUILD_CONTEXT"
  trap - EXIT

  echo "Image pushed: $BYOK_IMAGE"
fi
