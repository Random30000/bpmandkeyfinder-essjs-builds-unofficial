#!/usr/bin/env bash
set -euo pipefail

REF="${ESSENTIA_JS_REF:-v22.08}"
ROOT="$(cd "$(dirname "$0")/.." && pwd)"

if [[ ! -d "$ROOT/vendor/essentia.js/.git" ]]; then
  echo "[bootstrap] fetching upstream @ $REF"
  "$ROOT/scripts/fetch-upstream.sh" --ref "$REF"
fi

if [[ ! -f "$ROOT/dist/essentia-wasm.web.wasm" ]]; then
  echo "[bootstrap] building minimal bundle"
  "$ROOT/scripts/build.sh" min
fi

echo "[bootstrap] ok"
