# Nimini Debug System

This document describes the debugging infrastructure available in the Nimini parser.

## Overview

The Nimini parser includes a comprehensive debug logging system that helps diagnose parsing issues. The system is designed to work across both native (Nim) and WASM (Emscripten) builds with platform-appropriate output handling.

## Enabling Debug Mode

Debug output is controlled by a compile-time flag. To enable debugging:

```bash
# Native build with debug output
nim c -d:niminiDebug tstorie.nim

# WASM build with debug output
nim c -d:emscripten -d:niminiDebug -o:docs/tstorie.wasm.js tstorie.nim
```

When debug mode is **disabled** (default), all debug calls are no-ops with zero runtime overhead.

## Debug Module (`nimini/debug.nim`)

The debug module provides platform-aware logging functionality.

### Functions

#### `debugLog(category: string, message: string)`

Logs a timestamped debug message with a category prefix.

**Platform behavior:**
- **Native**: Writes to `stderr` with timestamp in format `[HH:MM:SS.mmm] [CATEGORY] message`
- **WASM**: Silent (no output to avoid browser console pollution)

**Example:**
```nim
debugLog("PARSER", "Starting to parse expression")
# Output: [21:04:22.866] [PARSER] Starting to parse expression
```

#### `debugTokens(category: string, tokens: seq[Token], pos: int, contextSize: int)`

Displays tokens around a specific position, highlighting the current token.

**Parameters:**
- `category`: Debug category (e.g., "PARSER")
- `tokens`: Token sequence
- `pos`: Current parser position
- `contextSize`: Number of tokens to show before/after current position (default: 5)

**Example output:**
```
[PARSER] Tokens around position 645:
[640] tkNewline: '\n' (line 93)
[641] tkIdent: 'break' (line 94)
[642] tkNewline: '\n' (line 94)
[643] tkDedent: '' (line 95)
[644] tkDedent: '' (line 95)
>>> [645] tkIdent: 'if' (line 95)
[646] tkIdent: 'not' (line 95)
[647] tkIdent: 'found' (line 95)
[648] tkColon: ':' (line 95)
```

#### `logParseError(msg: string, line: int, col: int, tokens: seq[Token], pos: int)`

Writes detailed parse error information to a log file (native only).

**Platform behavior:**
- **Native**: Appends to `/tmp/nimini_parse_errors.log` with full context
- **WASM**: Silent (file I/O not available)

**Log format:**
```
================================================================================
Parse Error at 2025-12-22 20:56:20
Message: Expected ':'
Location: line 95, col 1

Token context:
[640] tkNewline: '\n' (line 93)
[641] tkIdent: 'break' (line 94)
...
>>> [645] tkIdent: 'if' (line 95)
...
================================================================================
```

## Usage in Parser

### Basic Logging

Add debug statements to trace parser execution:

```nim
proc parseFor(p: var Parser): Stmt =
  debugLog("PARSER", "parseFor: starting to parse for loop")
  let tok = advance(p)
  # ... parsing logic ...
  debugLog("PARSER", "parseFor: completed successfully")
```

### Error Context

When errors occur, log token context:

```nim
proc expect(p: var Parser; kind: TokenKind; msg: string): Token =
  if p.cur().kind != kind:
    debugLog("PARSER", "expect() FAILED: " & msg & " at line " & $p.cur().line)
    debugTokens("PARSER", p.tokens, p.pos, 5)
    logParseError(msg, p.cur().line, p.cur().col, p.tokens, p.pos)
    # ... raise exception ...
```

### Tracking Parser State

Log important state transitions:

```nim
proc parseExpr(p: var Parser; allowDoNotation=true): Expr =
  debugLog("PARSER", "parseExpr: before parsing, cur token: " & $p.cur().kind & 
           " '" & p.cur().lexeme & "' at line " & $p.cur().line)
  # ... parse expression ...
  debugLog("PARSER", "parseExpr: after parsing, cur token: " & $p.cur().kind & 
           " '" & p.cur().lexeme & "' at line " & $p.cur().line)
```

## Viewing Debug Output

### Native Builds

Debug output goes to `stderr`, so you can:

```bash
# View all output
./tstorie examples/dungeon.md 2>&1 | less

# Filter for specific categories
./tstorie examples/dungeon.md 2>&1 | grep '\[PARSER\]'

# Remove ANSI color codes
./tstorie examples/dungeon.md 2>&1 | sed 's/\x1b\[[0-9;]*m//g'

# Check error log
cat /tmp/nimini_parse_errors.log
```

### WASM Builds

Debug logging is silent in WASM builds to avoid:
- Browser console pollution
- Performance overhead
- Exposing internal implementation details to users

To debug WASM builds, use the native build with the same code first.

## Common Debugging Patterns

### Finding Parse Errors

When encountering parse errors:

1. Build with `-d:niminiDebug`
2. Run and capture stderr output
3. Search for "FAILED" or "Error" messages
4. Look at token context around the error
5. Check `/tmp/nimini_parse_errors.log` for detailed history

```bash
./tstorie problematic.md 2>&1 | grep -E "(FAILED|Error)" -A 10
```

### Tracing Execution Flow

Add debug logs at function entry/exit:

```nim
proc myFunction(p: var Parser): Stmt =
  debugLog("PARSER", "myFunction: ENTER")
  defer: debugLog("PARSER", "myFunction: EXIT")
  # ... function body ...
```

### Comparing Token Positions

Track how far the parser advances:

```nim
let startPos = p.pos
# ... parsing ...
debugLog("PARSER", "Advanced from " & $startPos & " to " & $p.pos)
```

## Performance Considerations

- Debug calls compile to no-ops when `-d:niminiDebug` is not set
- No runtime overhead in release builds
- String concatenation in debug calls still evaluated in debug builds
- Consider using `when defined(niminiDebug):` blocks for expensive debug operations

## Implementation Details

### Conditional Compilation

The module uses `when defined(niminiDebug)` to enable/disable functionality:

```nim
proc debugLog*(category: string, message: string) =
  when defined(niminiDebug):
    # actual implementation
  else:
    discard
```

### Platform Detection

Platform-specific code uses `when defined(emscripten)`:

```nim
when not defined(emscripten):
  import std/times  # Native only - WASM doesn't need it
```

### Thread Safety

The current implementation is **not thread-safe**. Debug output from concurrent parsers may interleave. For multi-threaded scenarios, consider adding locks or per-thread log files.

## Troubleshooting

### Issue: No debug output appears

**Solution:** Ensure you compiled with `-d:niminiDebug` flag.

### Issue: WASM build fails with debug enabled

**Solution:** This should not happen. Debug mode is designed to work with WASM (output is just silent). If it fails, check for use of native-only imports outside `when not defined(emscripten)` blocks.

### Issue: Error log file not created

**Solution:** 
- Check `/tmp/` directory permissions
- Error logging only works on native builds (not WASM)
- Errors must actually occur for the file to be created

## Examples

See the following parser functions for debug usage examples:
- `expect()` - Error logging with token context
- `parseFor()` - State tracking before/after parsing
- `parseProc()` - Detailed execution tracing

## Future Enhancements

Potential improvements to the debug system:

- [ ] Configurable log file location
- [ ] Debug levels (ERROR, WARN, INFO, DEBUG, TRACE)
- [ ] Per-category enable/disable
- [ ] Structured logging (JSON format)
- [ ] Debug server for remote debugging of WASM builds
- [ ] Integration with VS Code debug protocol
