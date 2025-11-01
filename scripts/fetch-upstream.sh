#!/usr/bin/env bash
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
VENDOR_DIR="$ROOT_DIR/vendor"
UPSTREAM_DIR="$VENDOR_DIR/essentia.js"
UPSTREAM_REPO="${UPSTREAM_REPO:-https://github.com/MTG/essentia.js}"
REF=""

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

DEFAULT_REF="${ESSENTIA_JS_REF:-main}"
REQUESTED_REF="${REF:-$DEFAULT_REF}"

mkdir -p "$VENDOR_DIR"

if [[ -d "$UPSTREAM_DIR" ]]; then
  echo "[fetch-upstream] Removing existing repository at $UPSTREAM_DIR"
  rm -rf "$UPSTREAM_DIR"
fi

echo "[fetch-upstream] Cloning $UPSTREAM_REPO into $UPSTREAM_DIR"

if git ls-remote --exit-code --heads "$UPSTREAM_REPO" "refs/heads/$REQUESTED_REF" >/dev/null 2>&1 \
  || git ls-remote --exit-code --tags "$UPSTREAM_REPO" "refs/tags/$REQUESTED_REF" >/dev/null 2>&1; then
  echo "[fetch-upstream] Using ref '$REQUESTED_REF'"
  git clone --depth 1 --branch "$REQUESTED_REF" "$UPSTREAM_REPO" "$UPSTREAM_DIR"
  CHECKED_OUT_REF="$REQUESTED_REF"
else
  echo "[fetch-upstream] Ref '$REQUESTED_REF' not found, falling back to upstream default branch"
  git clone --depth 1 "$UPSTREAM_REPO" "$UPSTREAM_DIR"
  CHECKED_OUT_REF="$(git -C "$UPSTREAM_DIR" rev-parse --abbrev-ref HEAD 2>/dev/null || echo unknown)"
fi

git -C "$UPSTREAM_DIR" submodule update --init --recursive

COMMIT_SHA="$(git -C "$UPSTREAM_DIR" rev-parse HEAD)"
echo "[fetch-upstream] Checked out ${CHECKED_OUT_REF:-unknown} ($COMMIT_SHA)"
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
  "requestedRef": "$REQUESTED_REF",
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
