#!/bin/bash
# Binary Size Analysis Script for tstorie
# Measures the contribution of each /lib/ module to the final binary size

set -e

BASELINE_SIZE=0
BUILD_FLAGS="-d:release --opt:size -d:strip -d:useMalloc --passC:-flto --passL:-flto --passL:-s"
RESULTS_FILE="binary_size_results.md"
TMP_DIR="size_analysis_tmp"

# Function to format bytes nicely
format_size() {
    local bytes=$1
    if [ $bytes -lt 1024 ]; then
        echo "${bytes}B"
    elif [ $bytes -lt $((1024*1024)) ]; then
        echo "$((bytes/1024))KB"
    else
        echo "$((bytes/1024/1024))MB"
    fi
}

echo "======================================"
echo "TStorie Binary Size Analysis"
echo "======================================"
echo ""

# Create temp directory
mkdir -p "$TMP_DIR"

# Get current binary size as baseline
echo "Building baseline (full binary)..."
nim c $BUILD_FLAGS -o:tstorie tstorie.nim 2>&1 | grep -v "^Hint:" | tail -3
BASELINE_SIZE=$(stat -c%s tstorie 2>/dev/null || stat -f%z tstorie 2>/dev/null)
echo "Baseline size: $(format_size $BASELINE_SIZE) ($BASELINE_SIZE bytes)"
echo ""

# Store results
cat > "$RESULTS_FILE" << EOF
# TStorie Binary Size Analysis

**Generated**: $(date)  
**Baseline**: $(format_size $BASELINE_SIZE) ($BASELINE_SIZE bytes)

## Module Contributions

Modules are tested by commenting out their import and recompiling to measure the size difference.

| Module | Size Contribution | % of Binary | Notes |
|--------|------------------|-------------|-------|
EOF

# Function to test build without a specific import
test_without_module() {
    local module_name=$1
    local import_line=$2
    local define_flag=$3
    local notes=$4
    
    printf "  %-35s" "Testing $module_name..."
    
    # Create a temporary version of tstorie.nim with the import commented out
    if [ -n "$define_flag" ]; then
        # Use compile flag
        if nim c $BUILD_FLAGS $define_flag -o:"$TMP_DIR/tstorie_test" tstorie.nim 2>&1 > "$TMP_DIR/build.log"; then
            NEW_SIZE=$(stat -c%s "$TMP_DIR/tstorie_test" 2>/dev/null || stat -f%z "$TMP_DIR/tstorie_test" 2>/dev/null)
            DIFF=$((BASELINE_SIZE - NEW_SIZE))
            if [ $DIFF -gt 1024 ]; then
                PERCENT=$(awk "BEGIN {printf \"%.2f\", ($DIFF/$BASELINE_SIZE)*100}")
                echo "✓ Saves $(format_size $DIFF) ($PERCENT%)"
                echo "| $module_name | $(format_size $DIFF) | $PERCENT% | $notes |" >> "$RESULTS_FILE"
            else
                echo "✓ ~0 KB"
                echo "| $module_name | ~0 KB | 0.00% | $notes |" >> "$RESULTS_FILE"
            fi
        else
            echo "✗ Build failed"
            echo "| $module_name | ✗ Build failed | - | $notes |" >> "$RESULTS_FILE"
        fi
    else
        # Comment out import
        sed "s|^${import_line}|# ${import_line}  # DISABLED FOR TEST|" tstorie.nim > "$TMP_DIR/tstorie_test.nim"
        
        # Also check for conditional imports
        if grep -q "when.*emscripten" <<< "$import_line"; then
            # Handle conditional imports more carefully
            awk "/$import_line/{print \"# \" \$0 \"  # DISABLED FOR TEST\"; next} 1" tstorie.nim > "$TMP_DIR/tstorie_test.nim"
        fi
        
        if nim c $BUILD_FLAGS -o:"$TMP_DIR/tstorie_test" "$TMP_DIR/tstorie_test.nim" 2>&1 > "$TMP_DIR/build.log"; then
            NEW_SIZE=$(stat -c%s "$TMP_DIR/tstorie_test" 2>/dev/null || stat -f%z "$TMP_DIR/tstorie_test" 2>/dev/null)
            DIFF=$((BASELINE_SIZE - NEW_SIZE))
            if [ $DIFF -gt 1024 ]; then
                PERCENT=$(awk "BEGIN {printf \"%.2f\", ($DIFF/$BASELINE_SIZE)*100}")
                echo "✓ Saves $(format_size $DIFF) ($PERCENT%)"
                echo "| $module_name | $(format_size $DIFF) | $PERCENT% | $notes |" >> "$RESULTS_FILE"
            else
                echo "✓ ~0 KB"
                echo "| $module_name | ~0 KB | 0.00% | $notes |" >> "$RESULTS_FILE"
            fi
        else
            echo "✗ Build failed (deps)"
            echo "| $module_name | ✗ Build failed | - | $notes (has dependencies) |" >> "$RESULTS_FILE"
        fi
    fi
}

# Test individual modules
echo "Testing individual module contributions..."
echo ""

# Binding modules (these expose APIs to nimini scripts)
test_without_module "figlet_bindings" "import lib/figlet_bindings" "" "FIGlet text art API"
test_without_module "ascii_art_bindings" "import lib/ascii_art_bindings" "" "ASCII art generation"
test_without_module "ansi_art_bindings" "import lib/ansi_art_bindings" "" "ANSI art parser"
test_without_module "dungeon_bindings" "import lib/dungeon_bindings" "" "Dungeon generator"
test_without_module "particles_bindings" "import lib/particles_bindings" "" "Particle system"
test_without_module "tui_helpers_bindings" "import lib/tui_helpers_bindings" "" "TUI/dialog helpers"
test_without_module "text_editor_bindings" "import lib/text_editor_bindings" "" "Text editor widget"

# Optional features
test_without_module "animation" "import lib/animation" "" "Easing functions"

# Test HTTP client (with compile flag)
test_without_module "httpclient (gist)" "" "-d:noGistLoading" "HTTP/gist loading"

echo ""
echo "======================================"
echo "Analysis complete!"
echo "======================================"
echo ""
echo "Results saved to: $RESULTS_FILE"
echo ""

# Show summary
echo "Summary of significant contributors:"
grep -E '\|.*[0-9]+KB.*\|' "$RESULTS_FILE" | grep -v "Module |" | sort -t'|' -k3 -rn | head -10

# Cleanup
rm -rf "$TMP_DIR"
