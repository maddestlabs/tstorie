#!/bin/bash
# TStorie SDL3 Build - Default with TTF
# Includes TTF rendering for immediate use (~2.5MB)
# Plugin architecture ready for future extensions (audio, etc.)

set -e

VERSION="0.3.0"
OUTPUT_DIR="docs"

echo "=== TStorie SDL3 Build ==="
echo "Building with TTF support (~2.5MB total)"
echo ""

# Common flags
COMMON_FLAGS="
  --path:nimini/src
  --cpu:wasm32
  --os:linux
  --cc:clang
  --clang.exe:emcc
  --clang.linkerexe:emcc
  -d:emscripten
  -d:noSignalHandler
  --threads:off
  --exceptions:goto
  -d:release
  --opt:size
  -d:strip
  -d:useMalloc
"

# ============================================
# Build with TTF Support
# ============================================
echo "Building with SDL3 + TTF rendering..."

nim c \
  $COMMON_FLAGS \
  --nimcache:nimcache_wasm \
  -d:sdl3Backend \
  --passC:"-sUSE_SDL=3" \
  --passC:"-ISDL3" \
  --passC:"-I." \
  --passC:"-Ilib" \
  --passC:"-I/workspaces/storie-vendor/vendor/SDL_ttf-src/include" \
  --passL:"-sUSE_SDL=3" \
  --passL:"--use-port=sdl3" \
  --passL:"-I/workspaces/storie-vendor/vendor/SDL_ttf-src/include" \
  --passL:"/workspaces/storie-vendor/build-wasm/vendor/SDL_ttf-src/libSDL3_ttf.a" \
  --passL:"/workspaces/storie-vendor/build-wasm/vendor/SDL_ttf-src/external/freetype-build/libfreetype.a" \
  --passL:"/workspaces/storie-vendor/build-wasm/vendor/SDL_ttf-src/external/harfbuzz-build/libharfbuzz.a" \
  --passL:"--preload-file" --passL:"docs/assets/3270-Regular.ttf@/fonts/3270-Regular.ttf" \
  --passL:--js-library --passL:web/sdl3_stub_bridge.js \
  --passL:--js-library --passL:web/figlet_bridge.js \
  --passL:"-sALLOW_MEMORY_GROWTH=1" \
  --passL:"-sWASM_ASYNC_COMPILATION=1" \
  --passL:"-sFULL_ES2=1" \
  --passL:"-sUSE_WEBGL2=1" \
  --passL:"-sMIN_WEBGL_VERSION=2" \
  --passL:"-sMAX_WEBGL_VERSION=2" \
  --passL:"-sEXPORTED_FUNCTIONS=['_main','_malloc','_free','_setMarkdownContent']" \
  --passL:"-sEXPORTED_RUNTIME_METHODS=['ccall','cwrap','UTF8ToString','allocateUTF8']" \
  --passL:"-sMODULARIZE=1" \
  --passL:"-sEXPORT_NAME='TStorie'" \
  --passL:"-sENVIRONMENT=web" \
  --passL:"-sINITIAL_MEMORY=64MB" \
  --passL:"--preload-file" --passL:"presets@/presets" \
  --passL:"-Os" \
  --passL:"-flto" \
  -o:"$OUTPUT_DIR/tstorie.js" \
  tstorie.nim

echo "✓ Build complete: $OUTPUT_DIR/tstorie.{js,wasm}"
echo ""

# Note: Plugin architecture is ready for future extensions
# To build minimal version without TTF, use build-web-sdl3-minimal.sh

# ============================================
# Summary
# ============================================
echo "=== Build Complete ==="
echo ""
echo "Output:"
ls -lh "$OUTPUT_DIR/tstorie.wasm" | awk '{print "  " $5 "\t" $9}'
echo ""
echo "Features:"
echo "  ✓ SDL3 rendering backend"
echo "  ✓ TTF font support (Unicode, anti-aliasing)"
echo "  ✓ Plugin architecture ready for extensions"
echo ""
echo "For minimal build without TTF (~800KB), use:"
echo "  ./build-web-sdl3-minimal.sh"
