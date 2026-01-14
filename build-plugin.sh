#!/bin/bash
# Build compression plugin as shared library

echo "Building compression plugin..."

# Detect OS
if [[ "$OSTYPE" == "linux-gnu"* ]]; then
    OUTPUT="libcompression_plugin.so"
elif [[ "$OSTYPE" == "darwin"* ]]; then
    OUTPUT="libcompression_plugin.dylib"
elif [[ "$OSTYPE" == "msys" ]] || [[ "$OSTYPE" == "cygwin" ]]; then
    OUTPUT="compression_plugin.dll"
else
    OUTPUT="libcompression_plugin.so"
fi

# Build as shared library
nim c --app:lib -d:release --opt:size --nimcache:nimcache_plugin lib/compression_plugin.nim

# Move to lib directory
if [ -f "lib/compression_plugin" ]; then
    mv "lib/compression_plugin" "lib/$OUTPUT"
fi

if [ -f "lib/$OUTPUT" ]; then
    echo "✓ Built successfully: lib/$OUTPUT"
    ls -lh "lib/$OUTPUT"
    
    # Copy to main directory for easy access
    cp "lib/$OUTPUT" "./$OUTPUT"
    echo "✓ Copied to: ./$OUTPUT"
else
    echo "✗ Build failed"
    exit 1
fi
