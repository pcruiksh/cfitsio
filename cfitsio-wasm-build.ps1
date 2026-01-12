# cfitsio-wasm-build.ps1
# PowerShell build script for cfitsio WebAssembly port
# Usage:
#   .\cfitsio-wasm-build.ps1 [-EmsdkPath <path>] [-ForceConfigure]
#
# -EmsdkPath: Path to emsdk root (if not set in $Env:EMSDK)
# -ForceConfigure: If set, always rerun cmake configuration

param(
    [string]$EmsdkPath = $Env:EMSDK,
    [switch]$ForceConfigure
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

$buildDir = "build"
$cmakeCache = Join-Path $buildDir 'CMakeCache.txt'

# Discover sysroot/zlib paths
$sysroot = Join-Path $EmsdkPath 'upstream/emscripten/cache/sysroot'
$zInc    = Join-Path $sysroot 'include'
$zLib    = Join-Path $sysroot 'lib/wasm32-emscripten/libz.a'

# Only rerun cmake if build dir missing, cache missing, or forced
if ($ForceConfigure -or -not (Test-Path $buildDir) -or -not (Test-Path $cmakeCache)) {
    Write-Host 'Running emcmake cmake configuration...'
    emcmake cmake -S . -B $buildDir `
        -DCMAKE_BUILD_TYPE=Release `
        -DBUILD_SHARED_LIBS=OFF `
        -DUSE_CURL=OFF `
        -DUSE_BZIP2=OFF `
        -DUSE_PTHREADS=OFF `
        -DTESTS=OFF `
        -DUTILS=OFF `
        "-DZLIB_INCLUDE_DIR=$zInc" `
        "-DZLIB_LIBRARY=$zLib" `
        -DCMAKE_C_FLAGS_RELEASE="-O3" `
        -DCMAKE_EXE_LINKER_FLAGS="-O3 -sUSE_ZLIB=1"
} else {
    Write-Host 'CMake configuration already exists. Use -ForceConfigure to rerun.'
}

Write-Host 'Building cfitsio (WASM)...'
cmake --build $buildDir -j

# Sanity check: build a dummy file to ensure emcc/zlib linkage
Write-Host 'Testing emcc zlib linkage...'
$dum = 'int main() { return 0; }'
Set-Content -Path dummy.c -Value $dum -Encoding ascii
emcc dummy.c -sUSE_ZLIB=1 -O2 -o dummy.js
Remove-Item dummy.c, dummy.js, dummy.wasm -Force -ErrorAction SilentlyContinue

# Build the WASM port
Write-Host 'Building cfitsio-orbyter.c to cfitsio.js/wasm...'
emcc cfitsio-orbyter.c -I. -L./$buildDir -lcfitsio -sUSE_ZLIB=1 -sMODULARIZE=1 -sEXPORT_ES6=1 -sEXPORT_ALL=1 -sEXPORTED_FUNCTIONS="['_malloc','_free','_write_fits','_read_file_data','_file_exists','_delete_file']" -sINITIAL_MEMORY=64MB -sMAXIMUM_MEMORY=512MB -sALLOW_MEMORY_GROWTH=1 -O3 -o cfitsio.js

Write-Host 'Build complete. Output: cfitsio.js, cfitsio.wasm'

# list of changes documented below:

# In fitsio2.h:
# ifdef __EMSCRIPTEN__     
#   define BYTESWAPPED TRUE /* little-endian -> needs swap vs FITS big-endian */
# endif

# In putcoluk.c (or in fitsio2.h): maybe??
# // Forward declaration missing in header (required for C99+ before first use)
# int ffuintfi8(unsigned int *input, long ntodo, double scale, double zero,
#               LONGLONG *output, int *status);

# CMakeLists.txt: 
# CMAKE_MINIMUM_REQUIRED(VERSION 3.5)

# IF("${CMAKE_C_COMPILER_ID}" STREQUAL "Emscripten")
#     SET(EMSCRIPTEN TRUE)
# ENDIF()

# # Math library (not available in MSVC or MINGW)
# IF(MSVC OR MINGW OR EMSCRIPTEN)
#    SET(M_LIB "")
# ELSE()
#    FIND_LIBRARY(M_LIB m)
# ENDIF()

# SET(SRC_FILES
#     buffers.c cfileio.c checksum.c
#     drvrfile.c drvrmem.c drvrnet.c drvrsmem.c
#     editcol.c edithdu.c eval_f.c eval_l.c eval_y.c
#     fits_hcompress.c fits_hdecompress.c fitscore.c
#     getcol.c getcolb.c getcold.c getcole.c getcoli.c getcolj.c getcolk.c
#     getcoll.c getcols.c getcolsb.c getcolui.c getcoluj.c getcoluk.c
#     getkey.c group.c grparser.c histo.c imcompress.c iraffits.c modkey.c
#     pliocomp.c
#     putcol.c putcolb.c putcold.c putcole.c putcoli.c putcolj.c putcolk.c
#     putcoll.c putcols.c putcolsb.c putcolu.c putcolui.c putcoluj.c putcoluk.c
#     putkey.c quantize.c region.c ricecomp.c scalnull.c simplerng.c swapproc.c
#     wcssub.c wcsutil.c zcompress.c zuncompress.c
# )

# # Only add Fortran wrappers if not building with Emscripten
# IF(NOT EMSCRIPTEN)
#     LIST(APPEND SRC_FILES
#         f77_wrap1.c f77_wrap2.c f77_wrap3.c f77_wrap4.c
#     )
# ENDIF()