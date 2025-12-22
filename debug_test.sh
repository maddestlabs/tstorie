#!/bin/bash

echo "Building tstorie with debug enabled..."
nim c -d:niminiDebug --hints:off -o:tstorie_debug tstorie.nim 2>&1 | tail -20

echo ""
echo "Running dungeon example with debug..."
echo "======================================="
./tstorie_debug examples/dungeon.md 2>&1 | head -100

echo ""
echo "======================================="
echo "Check error log:"
if [ -f /tmp/nimini_parse_errors.log ]; then
    echo "Error log exists, showing last 50 lines:"
    tail -50 /tmp/nimini_parse_errors.log
else
    echo "No error log found"
fi
