# TStorie Debugging Tools

Quick reference for debugging tstorie markdown scripts.

## Quick Start

```bash
# Validate a demo (fastest way)
./validate.sh tui2

# Detailed validation with error context
./validate.sh tui2 --validate

# Show line mappings
./validate.sh tui2 --lines
```

## The Problem

Tstorie scripts are embedded in markdown. When errors occur, line numbers don't match:

```
Error in render block: Unexpected token in expression at line 85
```

Line 85 of *what*? The script? The markdown? 🤔

## The Solution

Use `debugger.nim` or the wrapper `validate.sh` to:
- ✓ See both script and markdown line numbers
- ✓ Validate syntax before running
- ✓ Get context around errors

## Examples

### Example 1: Quick validation before running
```bash
./validate.sh tui2 && ./ts tui2
```

### Example 2: Find and fix an error
```bash
# You see: "Error at line 85"
./validate.sh tui2 --validate

# Shows: "Script line 79 (MD line 134)"
# Now edit line 134 in your markdown!
```

### Example 3: Inspect a specific block
```bash
nim r debugger.nim docs/demos/tui2.md render
```

## Files

- **`debugger.nim`** - Main debugging tool (syntax validation, line mapping)
- **`check_symbols.nim`** - Symbol checker (runtime validation)
- **`validate.sh`** - Convenient wrapper for syntax checks
- **`check.sh`** - Combined syntax + symbol validation
- **`DEBUGGING.md`** - Complete guide covering syntax AND runtime errors

## Common Issues

### Multi-line function calls don't work
```nim
# ❌ This breaks:
func(arg1, arg2,
     arg3, arg4)

# ✓ Put on one line:
func(arg1, arg2, arg3, arg4)
```

### "Unexpected token" errors
Usually means:
- Missing closing bracket/parenthesis
- Incorrect indentation
- Statement on wrong line

Use `--validate` to see exact location!

## For Claude/AI Assistance

When asking for help:

1. Run validation: `./validate.sh yourfile --validate`
2. Copy the full output
3. Paste into your request
4. Mention both line numbers: "Line 79 in script (line 134 in markdown)"

## debugger.nim Usage

Direct usage (more control):

```bash
# Quick check
nim r debugger.nim docs/demos/tui2.md

# Full validation
nim r debugger.nim docs/demos/tui2.md --validate

# Show specific block
nim r debugger.nim docs/demos/tui2.md render

# Show all line mappings
nim r debugger.nim docs/demos/tui2.md --lines
```

## Workflow Integration

### Pre-commit hook
```bash
#!/bin/bash
# .git/hooks/pre-commit
for file in docs/demos/*.md; do
  ./validate.sh "$file" || exit 1
done
```

### VS Code task (add to .vscode/tasks.json)
```json
{
  "label": "Validate Current Demo",
  "type": "shell",
  "command": "./validate.sh ${fileBasenameNoExtension}",
  "problemMatcher": []
}
```

## Future Enhancements

Possible improvements (more complex to build):
- [ ] Interactive debugger with breakpoints
- [ ] Variable inspection at runtime
- [ ] Step-through execution
- [ ] AST visualization
- [ ] Better error suggestions

These would require deeper integration with the nimini interpreter.

## See Also

- **DEBUGGING.md** - Complete guide covering both syntax and runtime errors
- **nimini/** - The scripting engine source code
- **lib/nimini_bridge.nim** - Tstorie ↔ Nimini API bridge

---

**TL;DR**: Use `./validate.sh <demo-name>` for syntax, `./check_symbols <file>` for runtime checks! 🚀
