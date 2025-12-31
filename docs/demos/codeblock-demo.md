---
title: "Code Block API Demo"
---

# Code Block API Features

This demonstrates tstorie's flexible code block system:

1. **Any Language Tag** - Use `lvl`, `json`, `data`, `txt`, or any custom tag
2. **Section-Scoped Access** - Get blocks from specific sections  
3. **Global Procs** - Procs defined in `on:init` work everywhere
4. **Smart Content Rendering** - `contentWrite()` output appears at data block location automatically

```nim on:init
# Define a proc that processes level data
proc loadLevelFromSection(sectionIdx: int) =
  var blocks = getSectionCodeBlocks(sectionIdx, "lvl")
  if len(blocks) > 0:
    print("Level data for section " & $sectionIdx & ":")
    print(blocks[0].code)

# Process level data from section 1
loadLevelFromSection(1)
```

```nim on:render
# Render section content dynamically
var blocks = getCurrentSectionCodeBlocks("data")
if len(blocks) > 0:
  contentClear()
  contentWrite("=== Dynamic Content ===")
  contentWrite(blocks[0].code)
  contentWrite("======================")
```

# Game Level

Example level data in a custom `lvl` code block:

```lvl
#####
#@O.#
#####
```

```data
Player: @
Box: O  
Goal: .
Wall: #
