#!/bin/bash

# Check if argument was provided
if [ $# -eq 0 ]; then
    echo "Usage: $0 <filename> [additional args...]"
    exit 1
fi

# Get the filename
file="$1"
shift  # Remove first argument, leaving the rest for pass-through

# Add .md extension if not present
if [[ ! "$file" == *.md ]]; then
    file="${file}.md"
fi

# Check if file exists in current directory
if [ -f "$file" ]; then
    ./tstorie "$file" "$@"
# Check if file exists in examples directory
elif [ -f "docs/demos/$file" ]; then
    ./tstorie "docs/demos/$file" "$@"
else
    echo "Error: File not found: $file"
    echo "Checked locations:"
    echo "  - ./$file"
    echo "  - ./docs/demos/$file"
    exit 1
fi