# cfitsio-wasm-build.ps1
# PowerShell build script for cfitsio WebAssembly port
# Usage:
#   .\cfitsio-wasm-build.ps1 [-EmsdkPath <path>]
#
# -EmsdkPath: Path to emsdk root (if not set in $Env:EMSDK)
#
# This script uses CMake presets to build the WASM module.
# Configuration options can be customized by modifying CMakePresets.json
# or by passing additional -D flags after the preset configuration.

param(
    [string]$EmsdkPath = $Env:EMSDK
)

if (-not $EmsdkPath) {
    Write-Error 'EMSDK path not specified. Set $Env:EMSDK or use -EmsdkPath.'
    exit 1
}

$envScript = Join-Path $EmsdkPath 'emsdk_env.ps1'
if (-not (Test-Path $envScript)) {
    Write-Error "Could not find emsdk_env.ps1 at $envScript"
    exit 1
}

Write-Host "Activating emsdk environment from $envScript..."
. $envScript

Write-Host "Configuring WASM build using CMake preset..."
cmake --preset wasm
if ($LASTEXITCODE -ne 0) {
    Write-Error "CMake configuration failed"
    exit 1
}

Write-Host "Building cfitsio WASM module..."
cmake --build --preset wasm
if ($LASTEXITCODE -ne 0) {
    Write-Error "CMake build failed"
    exit 1
}

Write-Host "Build complete. Output in build-wasm/: cfitsio.js, cfitsio.wasm"

# Notes on Emscripten-specific changes made to cfitsio:
#
# In fitsio2.h:
# ifdef __EMSCRIPTEN__
#   define BYTESWAPPED TRUE /* little-endian -> needs swap vs FITS big-endian */
# endif
