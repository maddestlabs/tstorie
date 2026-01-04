#!/bin/bash
# Quick validation wrapper for tstorie demos
# Usage: ./validate-demo.sh [demo-name|path/to/file.md] [--validate|--lines]

set -e

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
DEBUG_TOOL="$SCRIPT_DIR/debugger"

# Compile debug tool if it doesn't exist or is older than source
if [ ! -f "$DEBUG_TOOL" ] || [ "$SCRIPT_DIR/debugger.nim" -nt "$DEBUG_TOOL" ]; then
  echo "Compiling debug tool..."
  nim c -d:release -o:"$DEBUG_TOOL" "$SCRIPT_DIR/debugger.nim" >/dev/null 2>&1
  echo "✓ Debug tool ready"
  echo ""
fi

# Parse arguments
FILE=""
MODE=""

if [ $# -eq 0 ]; then
  echo "Usage: $0 [demo-name|path/to/file.md] [--validate|--lines]"
  echo ""
  echo "Examples:"
  echo "  $0 tui2                    # Quick check of docs/demos/tui2.md"
  echo "  $0 tui2 --validate         # Detailed validation"
  echo "  $0 path/to/custom.md       # Check any markdown file"
  echo ""
  echo "Or use debugger.nim directly: nim r debugger.nim <file.md> [options]"
  exit 1
fi

# Determine file path
if [ -f "$1" ]; then
  FILE="$1"
elif [ -f "docs/demos/$1.md" ]; then
  FILE="docs/demos/$1.md"
elif [ -f "docs/demos/$1" ]; then
  FILE="docs/demos/$1"
else
  echo "Error: File not found: $1"
  echo "Tried:"
  echo "  - $1"
  echo "  - docs/demos/$1.md"
  echo "  - docs/demos/$1"
  exit 1
fi

# Check for mode flag
if [ $# -eq 2 ]; then
  MODE="$2"
fi

# Run validation
"$DEBUG_TOOL" "$FILE" $MODE
