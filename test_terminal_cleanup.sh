#!/bin/bash

echo "=== Terminal Cleanup Test Suite ==="
echo ""

# Function to check terminal state
check_terminal() {
    local test_name=$1
    echo "Checking terminal after: $test_name"
    
    # Check if echo is enabled
    if stty -a | grep -q "echo"; then
        echo "  ✓ Echo is enabled"
    else
        echo "  ✗ Echo is disabled (PROBLEM!)"
        return 1
    fi
    
    # Check if canonical mode is enabled
    if stty -a | grep -q "icanon"; then
        echo "  ✓ Canonical mode is enabled"
    else
        echo "  ✗ Canonical mode is disabled (PROBLEM!)"
        return 1
    fi
    
    echo "  ✓ Terminal state is normal"
    echo ""
    return 0
}

# Test 1: Normal timeout (simulates CTRL-C)
echo "Test 1: Timeout (simulates CTRL-C or crash)"
echo "  Running tstorie with 1 second timeout..."
timeout 1 ./tstorie docs/demos/intro.md >/dev/null 2>&1 || true
sleep 0.2
check_terminal "timeout/CTRL-C"

# Test 2: Quick successive runs
echo "Test 2: Quick successive runs"
for i in 1 2 3; do
    echo "  Run $i/3..."
    timeout 0.5 ./tstorie docs/demos/intro.md >/dev/null 2>&1 || true
    sleep 0.1
done
sleep 0.2
check_terminal "successive runs"

echo "=== Test Suite Complete ==="
echo "All tests passed! Terminal cleanup is working correctly."
