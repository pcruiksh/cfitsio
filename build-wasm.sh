#!/bin/bash
# build-wasm.sh
# Bash build script for cfitsio WebAssembly port
# Usage:
#   ./build-wasm.sh [emsdk-path]
#
# emsdk-path: Path to emsdk root (if not set in $EMSDK)
#
# This script uses CMake presets to build the WASM module.
# Configuration options can be customized by modifying CMakePresets.json
# or by passing additional -D flags after the preset configuration.

set -e

EMSDK_PATH="${1:-$EMSDK}"

if [ -z "$EMSDK_PATH" ]; then
    echo "Error: EMSDK path not specified. Set \$EMSDK or pass as argument." >&2
    exit 1
fi

ENV_SCRIPT="$EMSDK_PATH/emsdk_env.sh"
if [ ! -f "$ENV_SCRIPT" ]; then
    echo "Error: Could not find emsdk_env.sh at $ENV_SCRIPT" >&2
    exit 1
fi

echo "Activating emsdk environment from $ENV_SCRIPT..."
source "$ENV_SCRIPT"

echo "Configuring WASM build using CMake preset..."
cmake --preset wasm

echo "Building cfitsio WASM module..."
cmake --build --preset wasm

echo "Build complete. Output in build-wasm/: cfitsio.js, cfitsio.wasm"
