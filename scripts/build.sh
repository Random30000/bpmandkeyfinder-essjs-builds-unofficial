#!/usr/bin/env bash
set -euo pipefail

if [[ $# -lt 1 ]]; then
  echo "Usage: $(basename "$0") <full|min>" >&2
  exit 1
fi

TARGET="$1"
if [[ "$TARGET" != "full" && "$TARGET" != "min" ]]; then
  echo "Unknown build target: $TARGET" >&2
  exit 1
fi

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
VENDOR_DIR="$ROOT_DIR/vendor/essentia.js"
BUILD_ROOT="$ROOT_DIR/build/$TARGET"
ARTIFACT_DIR="$BUILD_ROOT/artifacts"
DIST_ROOT="$ROOT_DIR/dist"
DIST_VARIANT_DIR="$DIST_ROOT/$TARGET"
CONFIG_DIR="$ROOT_DIR/configs/$TARGET"

if [[ ! -d "$VENDOR_DIR" ]]; then
  echo "[build] Upstream repository not found. Run scripts/fetch-upstream.sh first." >&2
  exit 1
fi

mkdir -p "$BUILD_ROOT" "$ARTIFACT_DIR" "$DIST_VARIANT_DIR" "$DIST_ROOT"

if ! command -v emcc >/dev/null 2>&1; then
  echo "[build] emcc not found. Please activate emsdk (source emsdk_env.sh)." >&2
  exit 1
fi

pushd "$VENDOR_DIR" >/dev/null

# Install dependencies required by the upstream build.
if [[ ! -d node_modules ]]; then
  npm install --legacy-peer-deps
fi

PYTHON="${PYTHON:-python3}"
BINDINGS_SCRIPT="src/python/configure_bindings.py"

EXTRA_ARGS=()
if [[ "$TARGET" == "min" ]]; then
  INCLUDE_LIST="$CONFIG_DIR/included_algos.md"
  EXCLUDE_LIST="$CONFIG_DIR/excluded_algos.md"
  if [[ ! -f "$INCLUDE_LIST" ]]; then
    echo "[build] Missing include list for min build at $INCLUDE_LIST" >&2
    exit 1
  fi
  EXTRA_ARGS+=("--include-algos" "$INCLUDE_LIST")
  if [[ -s "$EXCLUDE_LIST" ]]; then
    EXTRA_ARGS+=("--exclude-algos" "$EXCLUDE_LIST")
  fi
fi

echo "[build] Configuring bindings via $PYTHON $BINDINGS_SCRIPT ${EXTRA_ARGS[*]}"
"$PYTHON" "$BINDINGS_SCRIPT" "${EXTRA_ARGS[@]}"

# Determine build directories for upstream makefile.
export ESSENTIAJS_WASM_BUILDS_DIR="$BUILD_ROOT/wasm"
export ESSENTIAJS_BUILDS_DIR="$ARTIFACT_DIR"

mkdir -p "$ESSENTIAJS_WASM_BUILDS_DIR" "$ESSENTIAJS_BUILDS_DIR"

# Build the WASM backend and JS wrappers.
make -f Makefile.essentiajs build

# Build JS APIs (ESM and UMD bundles).
DIST_DIR="$ARTIFACT_DIR" npm run build-js-api
DIST_DIR="$ARTIFACT_DIR" npm run build-js-api rollup.config.min.js

popd >/dev/null

# Collect artifacts
SOURCE_WASM="$ARTIFACT_DIR/essentia-wasm.web.wasm"
SOURCE_WEB="$ARTIFACT_DIR/essentia-wasm.web.js"
SOURCE_ESM="$ARTIFACT_DIR/essentia-wasm.es.js"
SOURCE_CORE="$ARTIFACT_DIR/essentia.js-core.es.js"
SOURCE_CORE_IIFE="$ARTIFACT_DIR/essentia.js-core.js"

if [[ ! -f "$SOURCE_WASM" || ! -f "$SOURCE_WEB" || ! -f "$SOURCE_ESM" ]]; then
  echo "[build] Expected artifacts not found in $ARTIFACT_DIR" >&2
  exit 1
fi

for dest in "$DIST_VARIANT_DIR" "$DIST_ROOT"; do
  rm -f \
    "$dest/essentia-wasm.web.wasm" \
    "$dest/essentia-wasm.web.js" \
    "$dest/essentia-wasm.module.js" \
    "$dest/essentia.js-core.es.js" \
    "$dest/essentia.js-core.js"
  cp "$SOURCE_WASM" "$dest/essentia-wasm.web.wasm"
  cp "$SOURCE_WEB" "$dest/essentia-wasm.web.js"
  cp "$SOURCE_ESM" "$dest/essentia-wasm.module.js"

  if [[ -f "$SOURCE_CORE" ]]; then
    cp "$SOURCE_CORE" "$dest/essentia.js-core.es.js"
  fi

  if [[ -f "$SOURCE_CORE_IIFE" ]]; then
    cp "$SOURCE_CORE_IIFE" "$dest/essentia.js-core.js"
  fi
done

EMCC_VERSION="unknown"
if command -v emcc >/dev/null 2>&1; then
  EMCC_VERSION="$(emcc --version 2>/dev/null | head -n 1)"
fi

EMPP_VERSION="unknown"
if command -v em++ >/dev/null 2>&1; then
  EMPP_VERSION="$(em++ --version 2>/dev/null | head -n 1)"
fi

NODE_VERSION="unknown"
if command -v node >/dev/null 2>&1; then
  NODE_VERSION="$(node --version 2>/dev/null)"
fi
BUILD_INFO_FILE="$ROOT_DIR/build-info.json"
BUILD_TIMESTAMP="$(date -u +"%Y-%m-%dT%H:%M:%SZ")"
REPO_SHA="$(git -C "$ROOT_DIR" rev-parse HEAD 2>/dev/null || echo unknown)"

if command -v node >/dev/null 2>&1; then
  node <<'NODE' "$BUILD_INFO_FILE" "$TARGET" "$BUILD_TIMESTAMP" "$EMCC_VERSION" "$EMPP_VERSION" "$NODE_VERSION" "$REPO_SHA" "$DIST_VARIANT_DIR"
const fs = require('fs/promises');
const path = require('path');

const [file, target, builtAt, emccVersion, empVersion, nodeVersion, repoSha, variantDir] = process.argv.slice(2);

(async () => {
  const resolved = path.resolve(file);

  let data = {};
  try {
    const text = await fs.readFile(resolved, 'utf8');
    data = JSON.parse(text);
  } catch (error) {
    if (error.code !== 'ENOENT') {
      throw error;
    }
  }

  const toolchain = Object.assign({}, data.toolchain);
  toolchain.emcc = emccVersion;
  toolchain['em++'] = empVersion;
  toolchain.node = nodeVersion;
  data.toolchain = toolchain;

  data.repositoryCommit = repoSha;

  const builds = data.builds ?? {};
  builds[target] = {
    builtAt,
    outputDir: path.relative(path.dirname(resolved), path.resolve(variantDir)).replace(/\\/g, '/'),
  };
  data.builds = builds;

  await fs.writeFile(resolved, JSON.stringify(data, null, 2) + '\n');
})().catch((error) => {
  console.error(`[build-info] ${error.message}`);
  process.exit(1);
});
NODE
fi

# Update metadata and verify artifacts are present
if ! command -v node >/dev/null 2>&1; then
  echo "[build] node is required to finalize artifacts" >&2
  exit 1
fi

(
  cd "$ROOT_DIR"
  node tools/hash.js
  node tools/size-report.js
  for artifact in \
    "dist/essentia-wasm.web.wasm" \
    "dist/essentia-wasm.web.js" \
    "dist/essentia-wasm.module.js" \
    "dist/SHA256SUMS.txt"; do
    if [[ ! -f "$artifact" ]]; then
      echo "[build] Missing artifact: $artifact" >&2
      exit 1
    fi
  done
)

echo "[build] artifacts verified"
echo "[build] Build completed. Artifacts available in $DIST_VARIANT_DIR and $DIST_ROOT"
