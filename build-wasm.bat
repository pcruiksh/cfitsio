@echo off
REM build-wasm.bat
REM Windows CMD build script for cfitsio WebAssembly port
REM Usage:
REM   build-wasm.bat [emsdk-path]
REM
REM emsdk-path: Path to emsdk root (if not set in %EMSDK%)
REM
REM If no emsdk path is provided, the script will:
REM   - Check for a local .emsdk\ folder in the project directory
REM   - If not found, prompt to download the latest emsdk from GitHub
REM   - If found, check for updates and prompt to update if a newer version is available
REM
REM This script uses CMake presets to build the WASM module.
REM Configuration options can be customized by modifying CMakePresets.json

setlocal enabledelayedexpansion

set "SCRIPT_DIR=%~dp0"
set "LOCAL_EMSDK=%SCRIPT_DIR%.emsdk"
set "EMSDK_ARCHIVE_URL=https://github.com/emscripten-core/emsdk/archive/refs/heads/main.zip"
set "EMSDK_LATEST_API_URL=https://api.github.com/repos/emscripten-core/emsdk/releases/latest"

set "EMSDK_PATH=%~1"
if "%EMSDK_PATH%"=="" set "EMSDK_PATH=%EMSDK%"

if "%EMSDK_PATH%"=="" (
    if exist "%LOCAL_EMSDK%" (
        REM Check for updates
        set "LOCAL_VERSION="
        for /f "tokens=2 delims==' " %%a in ('findstr /r "EMSDK_VERSION.*=" "%LOCAL_EMSDK%\emsdk.py" 2^>nul') do (
            set "LOCAL_VERSION=%%~a"
        )
        
        REM Fetch latest version from GitHub API
        set "LATEST_VERSION="
        set "TEMP_JSON=%TEMP%\emsdk_latest.json"
        curl -s -H "User-Agent: cfitsio-build-script" "%EMSDK_LATEST_API_URL%" -o "%TEMP_JSON%" 2>nul
        if exist "%TEMP_JSON%" (
            for /f "tokens=2 delims=:," %%a in ('findstr /r "\"tag_name\"" "%TEMP_JSON%"') do (
                set "LATEST_VERSION=%%~a"
                set "LATEST_VERSION=!LATEST_VERSION: =!"
                set "LATEST_VERSION=!LATEST_VERSION:"=!"
            )
            del "%TEMP_JSON%" 2>nul
        )
        
        if defined LOCAL_VERSION if defined LATEST_VERSION if not "!LOCAL_VERSION!"=="!LATEST_VERSION!" (
            echo Local emsdk version: !LOCAL_VERSION!
            echo Latest emsdk version: !LATEST_VERSION!
            set /p "UPDATE_CHOICE=A newer emsdk version is available. Update? [Y/n] "
            if /i "!UPDATE_CHOICE!"=="" set "UPDATE_CHOICE=Y"
            if /i "!UPDATE_CHOICE!"=="Y" (
                call :download_emsdk
            )
        ) else (
            echo Using existing emsdk at %LOCAL_EMSDK% ^(version: !LOCAL_VERSION!^)
        )
        set "EMSDK_PATH=%LOCAL_EMSDK%"
    ) else (
        echo emsdk not found at %LOCAL_EMSDK%
        set /p "DOWNLOAD_CHOICE=Download emsdk? [Y/n] "
        if /i "!DOWNLOAD_CHOICE!"=="" set "DOWNLOAD_CHOICE=Y"
        if /i "!DOWNLOAD_CHOICE!"=="Y" (
            call :download_emsdk
            set "EMSDK_PATH=%LOCAL_EMSDK%"
        ) else (
            echo Error: emsdk is required to build. Set %%EMSDK%%, pass as argument, or allow download. >&2
            exit /b 1
        )
    )
)

if "%EMSDK_PATH%"=="" (
    echo Error: EMSDK path not specified. >&2
    exit /b 1
)

REM Install and activate latest emsdk
if exist "%EMSDK_PATH%\emsdk.bat" (
    echo Installing latest emsdk toolchain...
    call "%EMSDK_PATH%\emsdk.bat" install latest
    if errorlevel 1 (
        echo Error: emsdk install failed >&2
        exit /b 1
    )
    
    echo Activating latest emsdk toolchain...
    call "%EMSDK_PATH%\emsdk.bat" activate latest
    if errorlevel 1 (
        echo Error: emsdk activate failed >&2
        exit /b 1
    )
)

set "ENV_SCRIPT=%EMSDK_PATH%\emsdk_env.bat"
if not exist "%ENV_SCRIPT%" (
    echo Error: Could not find emsdk_env.bat at %ENV_SCRIPT% >&2
    exit /b 1
)

echo Activating emsdk environment from %ENV_SCRIPT%...
call "%ENV_SCRIPT%"

goto :build

:download_emsdk
set "TEMP_ZIP=%TEMP%\emsdk-main.zip"
set "TEMP_EXTRACT=%TEMP%\emsdk-extract"

echo Downloading emsdk from %EMSDK_ARCHIVE_URL%...
curl -L "%EMSDK_ARCHIVE_URL%" -o "%TEMP_ZIP%"
if errorlevel 1 (
    echo Error: Failed to download emsdk >&2
    exit /b 1
)

echo Extracting emsdk...
if exist "%TEMP_EXTRACT%" rmdir /s /q "%TEMP_EXTRACT%"
mkdir "%TEMP_EXTRACT%"
tar -xf "%TEMP_ZIP%" -C "%TEMP_EXTRACT%"
if errorlevel 1 (
    echo Error: Failed to extract emsdk >&2
    exit /b 1
)

REM Move to local .emsdk folder
if exist "%LOCAL_EMSDK%" rmdir /s /q "%LOCAL_EMSDK%"
move "%TEMP_EXTRACT%\emsdk-main" "%LOCAL_EMSDK%"

REM Cleanup
del "%TEMP_ZIP%" 2>nul
rmdir /s /q "%TEMP_EXTRACT%" 2>nul

echo emsdk downloaded to %LOCAL_EMSDK%
goto :eof

:build

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
