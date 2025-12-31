---
title: "Code Block Access API"
author: "Maddest Labs"
---

# Code Block Access Functions

Three new functions have been added to access code block content from scripts:

## `getSectionCodeBlocks(sectionIndex, language)`

Get all code blocks from a specific section, filtered by language tag.

**Parameters:**
- `sectionIndex` (int) - The index of the section (0-based)
- `language` (string, optional) - Language filter (e.g., "lvl", "data", "json")

**Returns:** Array of code block objects with fields:
- `code` (string) - The code content
- `language` (string) - The language tag
- `lifecycle` (string) - The lifecycle hook (empty for non-lifecycle blocks)

**Example:**
```nim
# Get all "lvl" blocks from section 1
var levelBlocks = getSectionCodeBlocks(1, "lvl")
for block in levelBlocks:
  print("Level data: " & block["code"])
```

## `getCodeBlock(sectionIndex, language, blockIndex)`

Get a specific code block by section, language, and index.

**Parameters:**
- `sectionIndex` (int) - The index of the section
- `language` (string) - Language filter
- `blockIndex` (int, default 0) - Which block to get (0 for first, 1 for second, etc.)

**Returns:** Code block object or nil if not found

**Example:**
```nim
# Get the first "lvl" block from section 1
var level = getCodeBlock(1, "lvl", 0)
if level != nil:
  var levelData = level["code"]
  # Parse levelData...
```

## `getCurrentSectionCodeBlocks(language)`

Get all code blocks from the currently active section, filtered by language.

**Parameters:**
- `language` (string, optional) - Language filter

**Returns:** Array of code block objects

**Example:**
```nim
# Get all data blocks from current section
var dataBlocks = getCurrentSectionCodeBlocks("data")
print("Found " & $len(dataBlocks) & " data blocks")
```

## Practical Example: Sokoban Level Loader

Here's how to use these functions to load Sokoban level data:

```markdown
# Level 1
⠀
Description text here...
⠀
\`\`\`lvl
#######
#  @  #
#  O  #
# . . #
#######
\`\`\`
```

```nim on:init
# Load the level from the current section
var levelBlocks = getCurrentSectionCodeBlocks("lvl")
if len(levelBlocks) > 0:
  var levelData = levelBlocks[0]["code"]
  
  # Parse the level data
  var lines = split(levelData, "\n")
  for y, line in lines:
    for x, ch in line:
      if ch == '@':
        # Player position found
        playerX = x
        playerY = y
      elif ch == 'O':
        # Box position
        # ... add to boxes array
      elif ch == '.':
        # Goal position
        # ... add to goals array
      # etc.
```

## Tips

1. **Non-lifecycle blocks**: Code blocks without `on:*` annotations can be accessed with these functions
2. **Custom languages**: Use any language tag you want (lvl, data, json, config, etc.)
3. **Multiple blocks**: Each section can have multiple code blocks with the same language
4. **Index access**: Use `blockIndex` parameter to get specific blocks when there are multiples

## See Also

- `getCurrentSection()` - Get current section info
- `getSectionById(id)` - Get section by ID
- `gotoSection(index)` - Navigate to a section
