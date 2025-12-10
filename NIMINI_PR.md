# Map Literal Support and Array Operations for Nimini

This PR significantly enhances Nimini's data structure capabilities by adding map/dictionary literals and improving array operations.

## Overview

This enhancement makes Nimini more practical for real-world applications by adding first-class support for dictionaries and array concatenation. These features enable common patterns like managing collections of structured data, which are essential for games, visualizations, and interactive applications.

## Core Features

### 1. Map/Dictionary Literals
- Create maps with `{}` syntax: `{"name": "Alice", "age": 30}`
- Read values: `person["name"]`
- Write values: `person["age"] = 31`
- Empty maps: `var config = {}`

### 2. Array Concatenation
- Concatenate arrays with `+`: `[1, 2] + [3, 4]` → `[1, 2, 3, 4]`
- Build arrays incrementally: `items = items + [newItem]`

### 3. Standard Library Integration
- Automatic registration of `add`, `len`, `newSeq`, `setLen`, `delete`, `insert`
- New `initStdlib()` function for stdlib initialization

## Detailed Changes

### AST Changes (`src/nimini/ast.nim`)
- Added `ekMap` variant to `ExprKind` enum for map expressions
- Added `mapPairs*: seq[tuple[key: string, value: Expr]]` field to `Expr`
- Added `newMap()` constructor for creating map expressions

### Parser Changes (`src/nimini/parser.nim`)
- Implemented map literal parsing in `parsePrefix()`
- Syntax: `{key1: value1, key2: value2, ...}`
- Keys can be identifiers or string literals  
- Supports empty maps: `{}`
- Supports trailing commas for cleaner multi-line maps

### Runtime Changes (`src/nimini/runtime.nim`)
- **Map Support**: 
  - Map evaluation in `evalExpr()` creates `vkMap` values
  - Map indexing for reading: `map["key"]`
  - Map key assignment in indexed expressions: `map["key"] = value`
  - Returns `nil` for missing keys (safe access)
  
- **Array Concatenation**:
  - Enhanced `+` operator to detect array operands
  - Concatenates arrays: `[1, 2] + [3]` → `[1, 2, 3]`
  - Preserves integer/float arithmetic behavior

### Codegen Changes (`src/nimini/codegen.nim`)
- Added `ekMap` case handler for Nim backend
- Generates `.toTable` syntax for Nim compatibility
- Handles nested map literals correctly

### Main Module Changes (`src/nimini.nim`)
- Added `initStdlib()` public function
- Registers seqops functions: `add`, `len`, `newSeq`, `setLen`, `delete`, `insert`
- Avoids circular import by separating stdlib registration from runtime init

## Examples

### Basic Map Operations
```nim
# Create a map
var person = {"name": "Alice", "age": 30, "active": true}

# Read values
print(person["name"])  # Alice

# Update values
person["age"] = 31
person["city"] = "Portland"  # Add new key

# Nested structures
var config = {
  "window": {"width": 800, "height": 600},
  "features": ["sound", "graphics", "network"]
}
```

### Array Building Pattern
```nim
# Build array incrementally
var items = []
var i = 0
while i < 10:
  items = items + [i * 2]
  i = i + 1

# Result: [0, 2, 4, 6, 8, 10, 12, 14, 16, 18]
```

### Real-World Use Case: Matrix Rain Effect
```nim
# Initialize rain drops - each column has properties
var drops = []
var col = 0
while col < termWidth:
  var drop = {
    "y": randInt(termHeight),
    "speed": randInt(1, 4),
    "length": randInt(5, 20)
  }
  drops = drops + [drop]
  col = col + 1

# Update each drop's position
var col = 0
while col < termWidth:
  var drop = drops[col]
  var y = drop["y"] + 1
  drop["y"] = y
  drops[col] = drop
  col = col + 1
```

## Testing

The test file `test_map_literals.nim` demonstrates all features:

```bash
cd nimini
nim c -r test_map_literals.nim
```

## Compatibility

- **Backward Compatible**: Existing code continues to work
- **No Breaking Changes**: `{}` syntax was previously unused for literals
- **Type Safe**: Maps enforce string keys, provide nil for missing entries

## Performance

- Map operations use Nim's `Table` internally (O(1) average lookup)
- Array concatenation creates new arrays (functional approach)
- No runtime overhead for numeric operations

## Future Enhancements

Possible follow-ups (not in this PR):
- Support for integer keys: `{0: "zero", 1: "one"}`
- Dot notation for map access: `person.name`
- Map comprehensions: `{k: v * 2 for k, v in data}`
- In-place array append optimization
- Map/array spread operator: `{...base, "new": val}`

## Migration Guide

### Before (workaround patterns):
```nim
# Had to use arrays of arrays or complex index math
var drops = [[10, 2, 5], [15, 3, 8]]  # [y, speed, length]
var y = drops[0][0]  # Unclear what index 0 means
```

### After (clear and expressive):
```nim
var drops = [{"y": 10, "speed": 2, "length": 5}]
var y = drops[0]["y"]  # Self-documenting
```

## Credits

This enhancement was developed to support creative coding applications in the TStorie terminal engine, specifically for implementing a Matrix digital rain effect that required tracking multiple properties per column.
