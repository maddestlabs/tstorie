#!/usr/bin/env python3
"""
Generate a visual breakdown of tstorie's binary size
"""

import sys

def format_size(kb):
    """Format size in KB"""
    if kb >= 1024:
        return f"{kb/1024:.1f}MB"
    return f"{kb}KB"

def draw_bar(percentage, width=50):
    """Draw a text-based bar chart"""
    filled = int(percentage / 100 * width)
    return "█" * filled + "░" * (width - filled)

def main():
    print("=" * 80)
    print("TStorie Binary Size Breakdown (1.2 MB total)")
    print("=" * 80)
    print()
    
    # Component data: (name, size_kb, percentage, description)
    components = [
        ("Nimini Runtime", 450, 37, "Parser, VM, AST, backends, stdlib"),
        ("Feature Bindings", 200, 17, "API exposure to scripts (*_bindings.nim)"),
        ("Standard Library", 150, 12, "Nim stdlib (strings, tables, algorithms)"),
        ("Core Rendering", 120, 10, "Layout, layers, terminal handling"),
        ("FIGlet System", 80, 7, "Font rendering + embedded data"),
        ("Particle System", 60, 5, "Particle engine + graphs"),
        ("HTTP Client", 44, 4, "Gist loading (optional)"),
        ("Dungeon Gen", 40, 3, "Procedural generation"),
        ("Audio System", 30, 2, "Plugin loader"),
        ("ASCII Art", 30, 2, "Art generators"),
        ("Other", 16, 1, "Miscellaneous"),
    ]
    
    print(f"{'Component':<20} {'Size':>10} {'%':>5}  {'Bar':50}  {'Description':30}")
    print("-" * 135)
    
    for name, size, pct, desc in components:
        bar = draw_bar(pct, 40)
        size_str = format_size(size)
        print(f"{name:<20} {size_str:>10} {pct:>4}%  {bar}  {desc[:50]}")
    
    print()
    print("=" * 80)
    print("Key Insights:")
    print("=" * 80)
    print()
    print("  • Nimini scripting (37%) + Feature bindings (17%) = 54% of binary")
    print("    This provides the flexibility that makes tstorie scriptable")
    print()
    print("  • Core rendering engine is only ~120 KB (10%)")
    print("    The 180 KB WASM build proves the core is compact")
    print()
    print("  • Only 44 KB (4%) can be removed with -d:noGistLoading")
    print("    Most modules are interdependent and cannot be easily removed")
    print()
    print("Optimization Strategy:")
    print()
    print("  1. Make feature bindings conditional (~200 KB potential savings)")
    print("  2. Make embedded fonts optional (~50 KB savings)")
    print("  3. Consider plugin system for heavy features")
    print("  4. Create minimal/standard/full build variants")
    print()

if __name__ == "__main__":
    main()
