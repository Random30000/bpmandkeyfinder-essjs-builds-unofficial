#!/usr/bin/env bash
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
VENDOR_DIR="$ROOT_DIR/vendor"
UPSTREAM_DIR="$VENDOR_DIR/essentia.js"
UPSTREAM_REPO="${UPSTREAM_REPO:-https://github.com/MTG/essentia.js}"
REF="main"

usage() {
  cat <<'USAGE'
Usage: fetch-upstream.sh [--ref <tag-or-commit>] [--repo <url>]

Clones the Essentia.js upstream repository into vendor/essentia.js and
records metadata in build-info.json.
USAGE
}

while [[ $# -gt 0 ]]; do
  case "$1" in
    --ref)
      REF="$2"
      shift 2
      ;;
    --repo)
      UPSTREAM_REPO="$2"
      shift 2
      ;;
    -h|--help)
      usage
      exit 0
      ;;
    *)
      echo "Unknown argument: $1" >&2
      usage
      exit 1
      ;;
  esac
done

mkdir -p "$VENDOR_DIR"

if [[ -d "$UPSTREAM_DIR/.git" ]]; then
  echo "[fetch-upstream] Updating existing repository at $UPSTREAM_DIR"
  git -C "$UPSTREAM_DIR" remote set-url origin "$UPSTREAM_REPO"
  git -C "$UPSTREAM_DIR" fetch origin --tags
else
  echo "[fetch-upstream] Cloning $UPSTREAM_REPO into $UPSTREAM_DIR"
  git clone "$UPSTREAM_REPO" "$UPSTREAM_DIR"
fi

if ! git -C "$UPSTREAM_DIR" rev-parse --verify "$REF" >/dev/null 2>&1; then
  if [[ "$REF" == "main" ]] && git -C "$UPSTREAM_DIR" rev-parse --verify master >/dev/null 2>&1; then
    echo "[fetch-upstream] Ref 'main' not found, falling back to 'master'"
    REF="master"
  else
    echo "[fetch-upstream] Unable to resolve ref '$REF'" >&2
    exit 1
  fi
fi

echo "[fetch-upstream] Checking out $REF"
git -C "$UPSTREAM_DIR" checkout "$REF"
git -C "$UPSTREAM_DIR" submodule update --init --recursive

COMMIT_SHA="$(git -C "$UPSTREAM_DIR" rev-parse HEAD)"
EMSCRIPTEN_VERSION="unknown"
if command -v emcc >/dev/null 2>&1; then
  EMSCRIPTEN_VERSION="$(emcc --version | head -n 1)"
fi

EMPP_VERSION="unknown"
if command -v em++ >/dev/null 2>&1; then
  EMPP_VERSION="$(em++ --version | head -n 1)"
fi

NODE_VERSION="unknown"
if command -v node >/dev/null 2>&1; then
  NODE_VERSION="$(node --version)"
fi

BUILD_INFO_FILE="$ROOT_DIR/build-info.json"
DATE_UTC="$(date -u +"%Y-%m-%dT%H:%M:%SZ")"

cat > "$BUILD_INFO_FILE" <<JSON
{
  "upstreamRepository": "$UPSTREAM_REPO",
  "requestedRef": "$REF",
  "resolvedCommit": "$COMMIT_SHA",
  "generatedAt": "$DATE_UTC",
  "emscriptenVersion": "$EMSCRIPTEN_VERSION",
  "toolchain": {
    "emcc": "$EMSCRIPTEN_VERSION",
    "em++": "$EMPP_VERSION",
    "node": "$NODE_VERSION"
  },
  "repositoryCommit": "$(git -C "$ROOT_DIR" rev-parse HEAD 2>/dev/null || echo unknown)",
  "builds": {}
}
JSON

echo "[fetch-upstream] Wrote metadata to $BUILD_INFO_FILE"
