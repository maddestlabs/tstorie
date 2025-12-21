#!/bin/bash

# Check if argument was provided
if [ $# -eq 0 ]; then
    echo "Usage: $0 <filename>"
    exit 1
fi

# Get the filename
file="$1"

# Add .md extension if not present
if [[ ! "$file" == *.md ]]; then
    file="${file}.md"
fi

# Check if file exists in current directory
if [ -f "$file" ]; then
    ./tstorie "$file"
# Check if file exists in examples directory
elif [ -f "examples/$file" ]; then
    ./tstorie "examples/$file"
else
    echo "Error: File not found: $file"
    echo "Checked locations:"
    echo "  - ./$file"
    echo "  - ./examples/$file"
    exit 1
fi
