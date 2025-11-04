#!/usr/bin/env bash
set -euo pipefail

ROOT="$(cd "$(dirname "$0")/.." && pwd)"

[ -f "$ROOT/toolchain.env" ] && . "$ROOT/toolchain.env"

# Default to the upstream's primary branch when no override is provided.
: "${ESSENTIA_JS_REF:=main}"
: "${EMSDK_VERSION:=3.1.58}"

# Cap emscripten parallelism for more predictable CI resource usage.
export EMCC_CORES="${EMCC_CORES:-2}"
export MAKEFLAGS="${MAKEFLAGS:--j2}"

REF="$ESSENTIA_JS_REF"

if [[ ! -d "$ROOT/vendor/essentia.js/.git" ]]; then
  echo "[bootstrap] fetching upstream @ $REF"
  "$ROOT/scripts/fetch-upstream.sh" --ref "$REF"
fi

if [[ ! -f "$ROOT/dist/essentia-wasm.web.wasm" ]]; then
  echo "[bootstrap] building minimal bundle"
  "$ROOT/scripts/build.sh" min
fi

echo "[bootstrap] ok"
