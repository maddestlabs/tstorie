#!/bin/bash
# tstorie compiler script - compile and run with custom file support

VERSION="0.1.0"

show_help() {
    cat << EOF
tstorie v$VERSION
Terminal engine with sophisticated input parsing

Usage: ./build.sh [OPTIONS]

Options:
  -h, --help            Show this help message
  -v, --version         Show version information
  -d, --debug           Compile in debug mode (default is release with size optimization)
  -c, --compile-only    Compile without running

Examples:
  ./build.sh                           # Compile and run tstorie
  ./build.sh -d                        # Compile in debug mode
  ./build.sh -c                        # Compile only, don't run

Note: Application logic is in src/runtime_api.nim
      (formerly index.nim, now part of the core engine)

EOF
}

RELEASE_MODE="-d:release --opt:size -d:strip -d:useMalloc --passC:-flto --passL:-flto --passL:-s"
COMPILE_ONLY=false

# Parse arguments
while [[ $# -gt 0 ]]; do
    case $1 in
        -h|--help)
            show_help
            exit 0
            ;;
        -v|--version)
            echo "tstorie version $VERSION"
            exit 0
            ;;
        -d|--debug)
            RELEASE_MODE=""
            shift
            ;;
        -c|--compile-only)
            COMPILE_ONLY=true
            shift
            ;;
        -*)
            echo "Unknown option: $1"
            echo "Use --help for usage information"
            exit 1
            ;;
        *)
            echo "Unknown argument: $1"
            echo "Use --help for usage information"
            exit 1
            ;;
    esac
done

# Compile tstorie
echo "Compiling tstorie..."
nim c --path:nimini/src $RELEASE_MODE tstorie.nim

if [ $? -ne 0 ]; then
    echo "Compilation failed!"
    exit 1
fi

echo "Compilation successful!"
echo "Run with: ./tstorie"