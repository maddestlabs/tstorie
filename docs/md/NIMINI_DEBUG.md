# Nimini Debug System

## Overview

The Nimini parser now includes a comprehensive debug system that works across both native and WASM builds.

## Features

### 1. Compile-Time Debug Flag

Enable verbose debug logging with `-d:niminiDebug`:

```bash
# Native with debug
nim c -d:niminiDebug tstorie.nim

# WASM with debug (not typically needed)
nim c -d:emscripten -d:niminiDebug tstorie.nim
```

### 2. Debug Output Channels

- **Native builds**: Debug output goes to **stderr** (separate from user stdout)
- **WASM builds**: Debug output is **silently disabled** to avoid build issues

### 3. Error Logging

Parse errors are automatically logged:

- **Native**: Written to `/tmp/nimini_parse_errors.log` with timestamps
- **WASM**: Silent (errors are caught and displayed by main error handler)

## Debug Functions

### `debugLog(category, message)`

Log a debug message with timestamp (native only):

```nim
debugLog("PARSER", "Parsing proc declaration")
```

### `debugTokens(category, tokens, pos, context)`

Dump tokens around a position for error analysis:

```nim
debugTokens("PARSER", p.tokens, p.pos, 5)  # Show 5 tokens before/after
```

### `logParseError(msg, line, col, tokens, pos)`

Automatically called on parse errors. Logs to file (native) with full token context.

## Example Debug Output

When a parse error occurs with `-d:niminiDebug`:

```
[20:41:52.654] [PARSER] expect() FAILED: Expected '=' at line 31
[PARSER] Tokens around position 154:
     [149] tkDedent: '' (line 31)
     [150] tkIdent: 'var' (line 31)
     [151] tkIdent: 'dungeon' (line 31)
     [152] tkColon: ':' (line 31)
     [153] tkIdent: 'Dungeon' (line 31)
 >>> [154] tkNewline: '\n' (line 31)
     [155] tkNewline: '\n' (line 32)
     [156] tkNewline: '\n' (line 33)
     [157] tkIdent: 'proc' (line 34)
```

## Error Log File

Parse errors are automatically written to `/tmp/nimini_parse_errors.log`:

```
================================================================================
Parse Error at 2025-12-22 20:41:52
  Message: Expected '='
  Location: line 31, col 21

  Token context:
     [149] tkDedent: '' (line 31)
     [150] tkIdent: 'var' (line 31)
     ...
 >>> [154] tkNewline: '\n' (line 31)
     ...
```

## Usage Tips

1. **Development**: Use `-d:niminiDebug` to see detailed parsing flow
2. **Production**: Build without the flag for zero debug overhead
3. **Post-mortem**: Check `/tmp/nimini_parse_errors.log` after failures
4. **WASM**: Debug flag is safe but output is silent by design

## Implementation

See [nimini/debug.nim](nimini/debug.nim) for the complete implementation.
