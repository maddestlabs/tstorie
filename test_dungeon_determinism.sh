#!/bin/bash
# Test dungeon generators with same seed

SEED=654321

echo "Testing dungeon generators with seed: $SEED"
echo "==========================================="
echo ""

echo "Running native version..."
timeout 3 ./ts dungen --seed:$SEED 2>&1 | grep -i "steps" | head -1 || echo "Native: Could not capture steps"

echo ""
echo "Running scripted version..."
timeout 3 ./ts dungen_scripted --seed:$SEED 2>&1 | grep -i "steps" | head -1 || echo "Scripted: Could not capture steps"

echo ""
echo "Note: Both should show the same number of steps if deterministic!"
