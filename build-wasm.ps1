# cfitsio-wasm-build.ps1
# PowerShell build script for cfitsio WebAssembly port
# Usage:
#   .\build-wasm.ps1 [-EmsdkPath <path>]
#
# -EmsdkPath: Path to emsdk root (if not set in $Env:EMSDK)
#
# If no emsdk path is provided, the script will:
#   - Check for a local .emsdk/ folder in the project directory
#   - If not found, prompt to download the latest emsdk from GitHub
#   - If found, check for updates and prompt to update if a newer version is available
#
# This script uses CMake presets to build the WASM module.
# Configuration options can be customized by modifying CMakePresets.json
# or by passing additional -D flags after the preset configuration.

param(
    [string]$EmsdkPath = $Env:EMSDK
)

$ScriptDir = Split-Path -Parent $MyInvocation.MyCommand.Path
$LocalEmsdk = Join-Path $ScriptDir '.emsdk'
$EmsdkArchiveUrl = 'https://github.com/emscripten-core/emsdk/archive/refs/heads/main.zip'
$EmsdkLatestApiUrl = 'https://api.github.com/repos/emscripten-core/emsdk/releases/latest'

function Get-LocalEmsdkVersion {
    $emsdkPy = Join-Path $LocalEmsdk 'emsdk.py'
    if (Test-Path $emsdkPy) {
        $content = Get-Content $emsdkPy -Raw
        if ($content -match "EMSDK_VERSION\s*=\s*['""]([^'""]+)['""]") {
            return $Matches[1]
        }
    }
    return $null
}

function Get-LatestEmsdkVersion {
    try {
        $response = Invoke-RestMethod -Uri $EmsdkLatestApiUrl -Headers @{ 'User-Agent' = 'cfitsio-build-script' }
        return $response.tag_name
    } catch {
        Write-Warning "Could not fetch latest emsdk version: $_"
        return $null
    }
}

function Download-Emsdk {
    $tempZip = Join-Path $env:TEMP 'emsdk-main.zip'
    $tempExtract = Join-Path $env:TEMP 'emsdk-extract'
    
    Write-Host "Downloading emsdk from $EmsdkArchiveUrl..."
    try {
        Invoke-WebRequest -Uri $EmsdkArchiveUrl -OutFile $tempZip -UseBasicParsing
    } catch {
        Write-Error "Failed to download emsdk: $_"
        exit 1
    }
    
    Write-Host "Extracting emsdk..."
    if (Test-Path $tempExtract) {
        Remove-Item -Recurse -Force $tempExtract
    }
    Expand-Archive -Path $tempZip -DestinationPath $tempExtract -Force
    
    # The archive extracts to emsdk-main/
    $extractedFolder = Join-Path $tempExtract 'emsdk-main'
    if (-not (Test-Path $extractedFolder)) {
        Write-Error "Expected folder 'emsdk-main' not found in archive"
        exit 1
    }
    
    # Move to local .emsdk folder
    if (Test-Path $LocalEmsdk) {
        Remove-Item -Recurse -Force $LocalEmsdk
    }
    Move-Item -Path $extractedFolder -Destination $LocalEmsdk
    
    # Cleanup
    Remove-Item -Force $tempZip -ErrorAction SilentlyContinue
    Remove-Item -Recurse -Force $tempExtract -ErrorAction SilentlyContinue
    
    Write-Host "emsdk downloaded to $LocalEmsdk"
}

function Prompt-YesNo {
    param([string]$Message)
    $response = Read-Host "$Message [Y/n]"
    return ($response -eq '' -or $response -match '^[Yy]')
}

# Determine emsdk path
if (-not $EmsdkPath) {
    if (Test-Path $LocalEmsdk) {
        # Check for updates
        $localVersion = Get-LocalEmsdkVersion
        $latestVersion = Get-LatestEmsdkVersion
        
        if ($localVersion -and $latestVersion -and $localVersion -ne $latestVersion) {
            Write-Host "Local emsdk version: $localVersion"
            Write-Host "Latest emsdk version: $latestVersion"
            if (Prompt-YesNo "A newer emsdk version is available. Update?") {
                Download-Emsdk
            }
        } else {
            Write-Host "Using existing emsdk at $LocalEmsdk (version: $localVersion)"
        }
        $EmsdkPath = $LocalEmsdk
    } else {
        # Prompt to download
        Write-Host "emsdk not found at $LocalEmsdk"
        if (Prompt-YesNo "Download emsdk?") {
            Download-Emsdk
            $EmsdkPath = $LocalEmsdk
        } else {
            Write-Error 'emsdk is required to build. Set $Env:EMSDK, use -EmsdkPath, or allow download.'
            exit 1
        }
    }
}

# Install and activate latest emsdk
$emsdkScript = Join-Path $EmsdkPath 'emsdk.ps1'
if (Test-Path $emsdkScript) {
    Write-Host "Installing latest emsdk toolchain..."
    & $emsdkScript install latest
    if ($LASTEXITCODE -ne 0) {
        Write-Error "emsdk install failed"
        exit 1
    }
    
    Write-Host "Activating latest emsdk toolchain..."
    & $emsdkScript activate latest
    if ($LASTEXITCODE -ne 0) {
        Write-Error "emsdk activate failed"
        exit 1
    }
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
