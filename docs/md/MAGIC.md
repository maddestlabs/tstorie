# Magic Parameter Substitution Guide

## Overview

The magic system supports **safe, explicit parameter substitution** to avoid accidental code breakage.

## Recommended Syntax: `{{PARAM}}`

Use double-brace syntax for parameters:
- ✅ `{{name}}` - Safe, distinctive, won't match JSON or code
- ❌ `{name}` - Unsafe, could match object literals

## Creating Parameterized Presets

### 1. Declare Your Parameters

Add a comment at the top declaring all substitutable parameters:

```markdown
<!-- MAGIC_PARAMS: name, count, speed -->
```

### 2. Use Double-Brace Placeholders

```nim
var {{name}}_particles: seq[Particle]
for i in 0..<{{count}}:
  particles.add(Particle(
    speed: {{speed}}
  ))
```

### 3. Validate Your Preset

Before compressing, validate parameter safety:

```bash
./tools/magic validate presets/my-preset.md
```

This checks:
- All used parameters are declared
- No declared parameters are unused
- No unsafe `{single}` brace syntax
- No mixing of different placeholder styles

### 4. Compress the Preset

```bash
./tools/magic pack presets/my-preset.md
```

## Using Parameterized Magic Blocks

In your document, provide parameter values in the magic block header:

```markdown
\```magic name="fireflies" count="30" speed="0.02"
eJyNUk2L2zAQvetXTOkhdmp7k1Io...
\```
```

## Alternative Syntaxes

If `{{PARAM}}` conflicts with your code, use:

- `@PARAM@` - At-sign markers: `@name@`
- `$PARAM$` - Dollar signs: `$name$`  
- `<!--PARAM-->` - HTML comments: `<!--name-->`

Specify syntax in code:

```nim
expanded = substituteMagicParams(expanded, params, "@PARAM@")
```

## Safety Features

1. **Explicit Declaration**: Only declared parameters get substituted
2. **Validation Tool**: Catches issues before compression
3. **Distinctive Syntax**: `{{param}}` unlikely to match real code
4. **No Regex Accidents**: Won't match `{object: literal}` or `function(){}`

## Example: Particle System

```markdown
# Firefly Particles
<!-- MAGIC_PARAMS: name, count, speed, char -->

\```nim particles-init
var {{name}}_list: seq[Particle]
for i in 0..<{{count}}:
  # Initialize with speed={{speed}}
  ...
\```

\```nim particles-render
for p in {{name}}_list:
  canvas.drawChar(p.x, p.y, '{{char}}')
\```
```

Compress it, then use it:

```markdown
\```magic name="bugs" count="50" speed="0.05" char="*"
[compressed base64 here]
\```
```

## Best Practices

1. **Declare First**: Always add `<!-- MAGIC_PARAMS: ... -->` comment
2. **Validate Before Pack**: Run `magic validate` before compressing
3. **Use Consistent Syntax**: Stick to one placeholder style per preset
4. **Descriptive Names**: Use clear parameter names like `particleCount` not `n`
5. **Document Defaults**: In preset comments, mention recommended values

## Technical Details

- Parameters parsed from space-separated `key="value"` or `key=value` pairs
- Substitution happens during decompression, before Nim compilation  
- Declared params (in `MAGIC_PARAMS`) act as whitelist for safety
- If no declaration present, all parameters are substituted (less safe)

## Compression Format

The magic system uses **zlib format (RFC 1950)** via the zippy library. This format is compatible with:

- **WASM builds**: JavaScript's `CompressionStream('deflate')` / `DecompressionStream('deflate')`
- **Native builds**: Nim's zippy with `dfDeflate` format
- **URL sharing**: The same compression format works across native and WASM

This means magic blocks compressed on native can be decompressed in WASM builds and vice versa, and URL-shared content uses the same format as magic blocks.

## Troubleshooting

**"Parameter not replaced"**: Check you're using `{{name}}` not `{name}`

**"Unsafe placeholder warning"**: Convert `{param}` to `{{param}}`

**"Multiple syntaxes detected"**: Pick one style and use consistently

**"Parameter declared but not used"**: Remove from MAGIC_PARAMS or add to preset
