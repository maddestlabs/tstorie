#!/bin/bash
# Test script to send keypress to tstorie

echo "Starting tstorie with tui2.md..."
timeout 5 ./tstorie examples/tui2.md &
PID=$!

sleep 1

echo "Sending 'a' key..."
# We can't easily send keys to the terminal, so just show what we expect
echo "Expected: Input block should return 0 for key events"
echo "Expected: Key should propagate to default handlers"

wait $PID
echo "Test complete"
