#!/bin/bash
# Build audio plugin as shared library

echo "Building audio plugin..."

# Detect OS
if [[ "$OSTYPE" == "linux-gnu"* ]]; then
    OUTPUT="libaudio_plugin.so"
elif [[ "$OSTYPE" == "darwin"* ]]; then
    OUTPUT="libaudio_plugin.dylib"
elif [[ "$OSTYPE" == "msys" ]] || [[ "$OSTYPE" == "cygwin" ]]; then
    OUTPUT="audio_plugin.dll"
else
    OUTPUT="libaudio_plugin.so"
fi

# Build as shared library
nim c \
  --app:lib \
  --noMain \
  --gc:orc \
  -d:release \
  --opt:size \
  --nimcache:nimcache_audio_plugin \
  --passC:"-I$(pwd)/lib" \
  --out:"$OUTPUT" \
  lib/audio_plugin_impl.nim

if [ $? -eq 0 ]; then
    echo "✓ Built successfully: $OUTPUT"
    ls -lh "$OUTPUT"
    
    # Copy to lib directory for discovery
    mkdir -p lib
    cp "$OUTPUT" "lib/$OUTPUT"
    echo "✓ Copied to: lib/$OUTPUT"
    
    echo ""
    echo "Plugin size: $(du -h $OUTPUT | cut -f1)"
    echo "Plugin is ready to use!"
else
    echo "✗ Build failed"
    exit 1
fi
