#!/bin/bash
# build-wasm.sh
# Bash build script for cfitsio WebAssembly port
# Usage:
#   ./build-wasm.sh [emsdk-path]
#
# emsdk-path: Path to emsdk root (if not set in $EMSDK)
#
# If no emsdk path is provided, the script will:
#   - Check for a local .emsdk/ folder in the project directory
#   - If not found, prompt to download the latest emsdk from GitHub
#   - If found, check for updates and prompt to update if a newer version is available
#
# This script uses CMake presets to build the WASM module.
# Configuration options can be customized by modifying CMakePresets.json
# or by passing additional -D flags after the preset configuration.

set -e

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
LOCAL_EMSDK="$SCRIPT_DIR/.emsdk"
EMSDK_ARCHIVE_URL="https://github.com/emscripten-core/emsdk/archive/refs/heads/main.tar.gz"
EMSDK_LATEST_API_URL="https://api.github.com/repos/emscripten-core/emsdk/releases/latest"

get_local_emsdk_version() {
    if [ -f "$LOCAL_EMSDK/emsdk.py" ]; then
        grep -oP "EMSDK_VERSION\s*=\s*['\"]?\K[^'\"]*" "$LOCAL_EMSDK/emsdk.py" 2>/dev/null || echo ""
    fi
}

get_latest_emsdk_version() {
    if command -v curl &> /dev/null; then
        curl -s -H "User-Agent: cfitsio-build-script" "$EMSDK_LATEST_API_URL" 2>/dev/null | grep -oP '"tag_name":\s*"\K[^"]*' || echo ""
    elif command -v wget &> /dev/null; then
        wget -q -O - --header="User-Agent: cfitsio-build-script" "$EMSDK_LATEST_API_URL" 2>/dev/null | grep -oP '"tag_name":\s*"\K[^"]*' || echo ""
    fi
}

download_emsdk() {
    local temp_tar="/tmp/emsdk-main.tar.gz"
    local temp_extract="/tmp/emsdk-extract"
    
    echo "Downloading emsdk from $EMSDK_ARCHIVE_URL..."
    if command -v curl &> /dev/null; then
        curl -L "$EMSDK_ARCHIVE_URL" -o "$temp_tar"
    elif command -v wget &> /dev/null; then
        wget -O "$temp_tar" "$EMSDK_ARCHIVE_URL"
    else
        echo "Error: Neither curl nor wget found. Cannot download emsdk." >&2
        exit 1
    fi
    
    echo "Extracting emsdk..."
    rm -rf "$temp_extract"
    mkdir -p "$temp_extract"
    tar -xzf "$temp_tar" -C "$temp_extract"
    
    # Move to local .emsdk folder
    rm -rf "$LOCAL_EMSDK"
    mv "$temp_extract/emsdk-main" "$LOCAL_EMSDK"
    
    # Cleanup
    rm -f "$temp_tar"
    rm -rf "$temp_extract"
    
    echo "emsdk downloaded to $LOCAL_EMSDK"
}

prompt_yes_no() {
    local message="$1"
    read -p "$message [Y/n] " response
    [[ -z "$response" || "$response" =~ ^[Yy] ]]
}

EMSDK_PATH="${1:-$EMSDK}"

if [ -z "$EMSDK_PATH" ]; then
    if [ -d "$LOCAL_EMSDK" ]; then
        # Check for updates
        LOCAL_VERSION=$(get_local_emsdk_version)
        LATEST_VERSION=$(get_latest_emsdk_version)
        
        if [ -n "$LOCAL_VERSION" ] && [ -n "$LATEST_VERSION" ] && [ "$LOCAL_VERSION" != "$LATEST_VERSION" ]; then
            echo "Local emsdk version: $LOCAL_VERSION"
            echo "Latest emsdk version: $LATEST_VERSION"
            if prompt_yes_no "A newer emsdk version is available. Update?"; then
                download_emsdk
            fi
        else
            echo "Using existing emsdk at $LOCAL_EMSDK (version: $LOCAL_VERSION)"
        fi
        EMSDK_PATH="$LOCAL_EMSDK"
    else
        echo "emsdk not found at $LOCAL_EMSDK"
        if prompt_yes_no "Download emsdk?"; then
            download_emsdk
            EMSDK_PATH="$LOCAL_EMSDK"
        else
            echo "Error: emsdk is required to build. Set \$EMSDK, pass as argument, or allow download." >&2
            exit 1
        fi
    fi
fi

# Install and activate latest emsdk
if [ -f "$EMSDK_PATH/emsdk" ]; then
    echo "Installing latest emsdk toolchain..."
    "$EMSDK_PATH/emsdk" install latest
    
    echo "Activating latest emsdk toolchain..."
    "$EMSDK_PATH/emsdk" activate latest
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
