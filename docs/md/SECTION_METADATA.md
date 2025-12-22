# Section Metadata Implementation

## Overview

Section metadata has been successfully implemented in tstorie. Sections can now include JSON-formatted metadata in their heading lines, which is parsed and made available to the runtime.

## Format

Metadata is specified in JSON format at the end of heading lines:

```markdown
# section_title {"key": "value", "anotherKey": true, "numericKey": 123}
```

The title and metadata are automatically separated during parsing.

## Implementation Details

### Changes Made

1. **`lib/storie_md.nim`**:
   - Added `metadata: Table[string, string]` field to the `Section` type
   - Created `parseHeadingMetadata()` function to parse JSON from heading lines
   - Updated `parseMarkdownDocument()` to extract metadata when parsing sections
   - All `Section` constructors now initialize the metadata field

### Parsing Algorithm

The parser supports simple JSON key-value pairs:
- String values: `"key": "value"`
- Boolean values: `"key": true` or `"key": false`
- Numeric values: `"key": 123`

All values are stored as strings in the `Table[string, string]`.

## Usage Example

### In Markdown

```markdown
# entrance {"hidden": false}

This is the entrance to the dungeon.

# secret_room {"hidden": true, "removeAfterVisit": true}

You found a secret room!
```

### In Nim Code

```nim
let doc = parseMarkdownDocument(content)

for section in doc.sections:
  echo "Section: ", section.title
  
  # Check if section has metadata
  if section.metadata.hasKey("hidden"):
    echo "  Hidden: ", section.metadata["hidden"]
  
  if section.metadata.hasKey("removeAfterVisit"):
    echo "  Remove after visit: ", section.metadata["removeAfterVisit"]
```

## Integration with Canvas System

This metadata system now enables the IF game mechanics used in `depths.md`:

- **`hidden`**: Sections that haven't been visited yet show as "???"
- **`removeAfterVisit`**: One-time events that disappear after being seen
- **Custom positioning**: `{"x": 100, "y": 50}` for spatial layouts
- **Any game state**: Track inventory, flags, visited state, etc.

## Next Steps

To fully support the canvas.lua functionality, tstorie still needs:

1. **Global event handlers** - Allow modules to register callbacks for:
   - `globalRender()`
   - `globalUpdate(dt)`
   - `globalHandleKey(key)`
   - `globalHandleMouse(event)`

2. **Mouse support** - Capture and route mouse events (optional for now)

3. **Viewport API** - Expose terminal/window dimensions to scripts

4. **Section metadata API** - Expose section.metadata to Nimini scripts

The metadata parsing foundation is now complete and tested. ✓
