@echo off
REM build-wasm.bat
REM Windows CMD build script for cfitsio WebAssembly port
REM Usage:
REM   build-wasm.bat [emsdk-path]
REM
REM emsdk-path: Path to emsdk root (if not set in %EMSDK%)
REM
REM This script uses CMake presets to build the WASM module.
REM Configuration options can be customized by modifying CMakePresets.json

setlocal

set "EMSDK_PATH=%~1"
if "%EMSDK_PATH%"=="" set "EMSDK_PATH=%EMSDK%"

if "%EMSDK_PATH%"=="" (
    echo Error: EMSDK path not specified. Set %%EMSDK%% or pass as argument. >&2
    exit /b 1
)

set "ENV_SCRIPT=%EMSDK_PATH%\emsdk_env.bat"
if not exist "%ENV_SCRIPT%" (
    echo Error: Could not find emsdk_env.bat at %ENV_SCRIPT% >&2
    exit /b 1
)

echo Activating emsdk environment from %ENV_SCRIPT%...
call "%ENV_SCRIPT%"

echo Configuring WASM build using CMake preset...
cmake --preset wasm
if errorlevel 1 (
    echo Error: CMake configuration failed >&2
    exit /b 1
)

echo Building cfitsio WASM module...
cmake --build --preset wasm
if errorlevel 1 (
    echo Error: CMake build failed >&2
    exit /b 1
)

echo Build complete. Output in build-wasm/: cfitsio.js, cfitsio.wasm
