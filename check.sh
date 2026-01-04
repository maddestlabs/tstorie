#!/bin/bash
# Full validation: syntax + symbols
# Usage: ./check.sh <demo-name|file.md>

set -e

FILE=""

if [ $# -eq 0 ]; then
  echo "Usage: $0 <demo-name|file.md>"
  echo ""
  echo "Runs both syntax and symbol validation."
  echo ""
  echo "Examples:"
  echo "  $0 tui2"
  echo "  $0 docs/demos/myfile.md"
  exit 1
fi

# Determine file
if [ -f "$1" ]; then
  FILE="$1"
elif [ -f "docs/demos/$1.md" ]; then
  FILE="docs/demos/$1.md"
elif [ -f "docs/demos/$1" ]; then
  FILE="docs/demos/$1"
else
  echo "Error: File not found: $1"
  exit 1
fi

echo "===================================="
echo "Full Validation: $FILE"
echo "===================================="
echo ""

# Step 1: Syntax validation
echo "Step 1: Syntax Validation"
echo "--------------------------"
./validate.sh "$FILE"
SYNTAX_OK=$?

echo ""

if [ $SYNTAX_OK -ne 0 ]; then
  echo "❌ Syntax validation failed. Fix errors above before checking symbols."
  exit 1
fi

# Step 2: Symbol checking
echo "Step 2: Symbol Checking"
echo "-----------------------"

# Compile symbol checker if needed
if [ ! -f "./check_symbols" ] || [ "check_symbols.nim" -nt "./check_symbols" ]; then
  echo "Compiling symbol checker..."
  nim c -d:release check_symbols.nim >/dev/null 2>&1
  echo ""
fi

./check_symbols "$FILE"
SYMBOLS_OK=$?

echo ""

if [ $SYMBOLS_OK -ne 0 ]; then
  echo "❌ Symbol validation found issues."
  echo ""
  echo "Common fixes:"
  echo "  - Check if functions are registered in lib/*_bindings.nim"
  echo "  - Verify variable names and spelling"
  echo "  - Ensure variables are defined in on:init"
  exit 1
fi

echo "===================================="
echo "✅ All validation passed!"
echo "===================================="
echo ""
echo "Safe to run: ./ts $(basename "$FILE" .md)"
