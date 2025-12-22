# TStorie Scoping Guide

## Overview

TStorie uses **proper lexical scoping** powered by Nimini's runtime. Understanding scope is important for managing state correctly in your stories.

## Scoping Rules

### 1. Front Matter → Global Definitions

All front matter values become global variables:

```yaml
---
targetFPS: 60
maxEnemies: 10
playerName: "Hero"
---
```

These are accessible in all code blocks as `targetFPS`, `maxEnemies`, `playerName`.

### 2. `on:init` Blocks → Global Scope

Code in `init` blocks executes in the **global scope**. All variables declared here are global:

```nim
# on:init
var score = 0        # GLOBAL
var playerX = 10     # GLOBAL
var enemies = []     # GLOBAL
```

**Use init blocks to define your application state.**

### 3. `on:update`, `on:render`, etc. → Local Scope

These blocks execute in a **child scope**. Variables declared with `var` are local:

```nim
# on:update
var dt = 1.0 / fps          # LOCAL - disappears after block
var tempValue = score * 2   # LOCAL - only exists here

score = score + 1           # UPDATES global score (no 'var')
```

### 4. Assignment Behavior (The Smart Part!)

When you assign without `var`:
- If variable exists in a parent scope → **updates the parent**
- If variable doesn't exist → **creates local variable**

```nim
# on:init
var health = 100

# on:update
health = health - 1        # ✅ Updates global health (found in parent)
newVar = 42                # ✅ Creates LOCAL newVar (not in parent)
```

**To modify globals from update/render: just don't use `var`**

## Best Practices

### ✅ Good Pattern

```nim
# on:init - Define all persistent state here
var gameState = "playing"
var level = 1
var entities = []

# on:update - Use assignments to modify state
if gameState == "playing":
  var input = getInput()     # Local helper variable
  level = level + 1          # Modify global
  
# on:render - Read globals, use locals for rendering
var x = termWidth / 2        # Local calculation
bgWriteText(x, 10, "Level: " & $level)  # Read global
```

### ❌ Anti-Pattern

```nim
# on:update
var counter = 0              # ❌ Creates LOCAL counter each frame!
counter = counter + 1        # ❌ Always 1, never persists

# Should be:
# on:init
var counter = 0

# on:update  
counter = counter + 1        # ✅ Updates global
```

## Scope Nesting

Within each block, Nimini provides full lexical scoping:

```nim
# on:update
var outerVar = 10

if condition:
  var innerVar = 20          # Only visible in if block
  outerVar = 30              # Can access outer scope

# innerVar not accessible here
# outerVar is 30
```

## Function Scopes

Functions create their own scope:

```nim
# on:init
var globalCount = 0

proc increment() =
  var localStep = 1          # Local to function
  globalCount = globalCount + localStep  # Can modify global

# on:update
increment()                  # globalCount increases
# localStep not accessible here
```

## Common Pitfalls

### Pitfall 1: Declaring vars in update/render

```nim
# ❌ WRONG - creates new local variable each frame
# on:update
var position = 0
position = position + 1      # Always 1!

# ✅ RIGHT - declare in init
# on:init
var position = 0

# on:update
position = position + 1      # Properly increments
```

### Pitfall 2: Forgetting var in init

```nim
# ❌ WRONG - creates local variable in init
# on:init
score = 0                    # Local, disappears after init!

# ✅ RIGHT
# on:init
var score = 0                # Global, persists
```

### Pitfall 3: Shadowing

```nim
# on:init
var x = 10

# on:update
var x = 20                   # ❌ Creates LOCAL x, shadows global
x = x + 1                    # Modifies local, global stays 10

# ✅ RIGHT
# on:update
x = 20                       # Updates global (no 'var')
```

## Summary Table

| Location | `var x = 5` | `x = 5` (x exists in parent) | `x = 5` (x doesn't exist) |
|----------|-------------|------------------------------|---------------------------|
| Front matter | N/A - YAML syntax | N/A | N/A |
| `on:init` | Creates global | Updates global | Creates global |
| `on:update` | Creates local | Updates global | Creates local |
| `on:render` | Creates local | Updates global | Creates local |
| Inside function | Creates local | Updates parent scope | Creates local |
| Inside if/for/while | Creates local in block | Updates parent scope | Creates local |

## Technical Details

This scoping is powered by Nimini's environment chain:
- Each execution context has a parent pointer
- Variable lookup walks up the chain
- `var` always creates in current scope
- Assignment without `var` updates parent if found, else creates local

This matches Nim's native scoping behavior closely.
