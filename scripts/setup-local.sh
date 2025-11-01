#!/usr/bin/env bash
set -euo pipefail

REQUIRED_CMDS=("git" "cmake" "python3" "node" "npm")

missing=0
for cmd in "${REQUIRED_CMDS[@]}"; do
  if ! command -v "$cmd" >/dev/null 2>&1; then
    echo "[setup-local] Missing required command: $cmd" >&2
    missing=1
  else
    echo "[setup-local] Found $cmd: $(command -v "$cmd")"
  fi
done

if command -v emcc >/dev/null 2>&1; then
  echo "[setup-local] Found emcc version: $(emcc --version | head -n 1)"
else
  echo "[setup-local] emcc (Emscripten) not found."
  echo "Please install emsdk and activate the appropriate version. Example:"
  cat <<'USAGE'
  git clone https://github.com/emscripten-core/emsdk.git
  cd emsdk
  ./emsdk install latest
  ./emsdk activate latest
  source ./emsdk_env.sh
USAGE
  missing=1
fi

if [[ "$missing" -eq 0 ]]; then
  echo "[setup-local] Environment looks good!"
else
  echo "[setup-local] One or more requirements are missing. Please install them and re-run."
fi
