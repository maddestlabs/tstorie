# XOR and Negative Variable Support in Nimini

This document demonstrates the newly added features to nimini:

## XOR Operator

The XOR (exclusive or) operator is now supported in nimini. It returns `true` when exactly one of its operands is `true`.

### Examples

```nim
let a = true
let b = false

let result1 = a xor b  # true (one is true)
let result2 = a xor a  # false (both are true)
let result3 = b xor b  # false (both are false)
```

### Truth Table

| A     | B     | A xor B |
|-------|-------|---------|
| true  | true  | false   |
| true  | false | true    |
| false | true  | true    |
| false | false | false   |

### Use with Expressions

The XOR operator can be used with any boolean expressions:

```nim
let x = 5
let y = 3

let result = (x > 4) xor (y > 4)  # true (5 > 4 is true, 3 > 4 is false)
```

## Negative Variable Support

Nimini now supports the unary minus operator to negate variables and expressions.

### Examples

```nim
let x = 10
let y = -x      # -10

let z = 5
let neg_z = -z  # -5

# Double negation
let pos = -(-x)  # 10
```

### In Expressions

Negative variables can be used in arithmetic expressions:

```nim
let a = 10
let b = 5

let result1 = -a + b    # -5
let result2 = a + (-b)  # 5
let result3 = -a * -b   # 50
```

## Implementation Details

### Changes Made

1. **Parser (`nimini/parser.nim`)**:
   - Added `xor` to the `precedence()` function at level 2 (same as `and`)
   - Added `xor` to the keyword operator list in `parseExpr()`
   - Unary minus already supported for variables through `parsePrefix()`

2. **Runtime (`nimini/runtime.nim`)**:
   - Added XOR evaluation in the `ekBinOp` case handling
   - Uses Nim's built-in `xor` operator for boolean XOR
   - Unary minus already supported for variables in `ekUnaryOp`

3. **Tokenizer (`nimini/tokenizer.nim`)**:
   - No changes needed - `xor` is tokenized as an identifier (tkIdent)
   - Unary minus already tokenized as an operator (tkOp)

### Operator Precedence

The XOR operator has precedence level 2, which is:
- Higher than OR (level 1)
- Same as AND (level 2)
- Lower than comparison operators (level 3)
- Lower than arithmetic operators (levels 4-5)

This matches standard boolean operator precedence in most languages.
