# Section-Based Markdown System Implementation Guide

This document outlines the implementation of a section-based markdown parsing and navigation system for story/interactive engines. This was implemented in TStorie (a terminal-based engine using Nimini for scripting) and can be adapted for graphical engines using Raylib/SDL3.

## Overview

The section-based markdown system transforms markdown documents from a flat sequence of code blocks into a structured hierarchy of navigable sections. This enables:

- **Section-based navigation** - Jump between sections by heading
- **Per-section code execution** - Each section can have its own lifecycle hooks
- **Dynamic section manipulation** - Create, delete, and modify sections at runtime
- **Metadata queries** - Access section titles, IDs, content structure
- **Flexible rendering modes** - Single-section or multi-section display

## Architecture

### Core Concept

Markdown headings (`# Title`, `## Title`, etc.) define section boundaries. All content between headings belongs to that section, including:
- Text paragraphs
- Code blocks
- Links and formatted text

### Backward Compatibility

The implementation maintains backward compatibility:
- Old markdown files without headings still work (creates a single default section)
- Flat `codeBlocks` list is preserved for legacy code
- Section system is additive, not replacing existing functionality

## Data Structures

### 1. Inline Markdown Elements

```nim
type
  MarkdownElement* = object
    ## Represents inline markdown formatting
    text*: string
    bold*: bool
    italic*: bool
    isLink*: bool
    linkUrl*: string
```

**Purpose**: Parses inline formatting like **bold**, *italic*, and [links](url).

### 2. Content Block Types

```nim
type
  ContentBlockKind* = enum
    TextBlock, CodeBlock_Content, HeadingBlock
  
  ContentBlock* = object
    ## A block of content within a section
    case kind*: ContentBlockKind
    of TextBlock:
      text*: string
      elements*: seq[MarkdownElement]
    of CodeBlock_Content:
      codeBlock*: CodeBlock  # Reference to existing CodeBlock type
    of HeadingBlock:
      level*: int
      title*: string
```

**Purpose**: Represents different types of content blocks that can appear in a section.

**Note**: `CodeBlock_Content` is named this way to avoid conflict with existing `CodeBlock` type used for script execution.

### 3. Section Structure

```nim
type
  Section* = object
    ## A section represents a heading and all content until the next heading
    id*: string          ## Generated from title or explicit anchor
    title*: string       ## The heading text
    level*: int          ## Heading level (1-6)
    blocks*: seq[ContentBlock]  ## All content blocks in this section
```

**Purpose**: Encapsulates a complete section with its metadata and content.

**Section ID Generation**: 
- Converts title to lowercase, alphanumeric + underscores
- Example: "Welcome to Sections" → "welcome_to_sections"
- Fallback: "section_N" where N is the section number

### 4. Document Structure

```nim
type
  MarkdownDocument* = object
    frontMatter*: FrontMatter
    codeBlocks*: seq[CodeBlock]  ## Flat list (backward compatibility)
    sections*: seq[Section]      ## Structured section view
```

**Purpose**: Contains both the legacy flat structure and new section hierarchy.

## Parsing Implementation

### Helper Function: Generate Section ID

```nim
proc generateSectionId*(title: string): string =
  ## Generate a URL-safe section ID from a title
  result = ""
  for c in title.toLowerAscii():
    if c in {'a'..'z', '0'..'9'}:
      result.add(c)
    elif c == ' ' or c == '-' or c == '_':
      if result.len > 0 and result[^1] != '_':
        result.add('_')
  # Remove trailing underscores
  while result.len > 0 and result[^1] == '_':
    result.setLen(result.len - 1)
  if result.len == 0:
    result = "section"
```

### Inline Markdown Parser

```nim
proc parseMarkdownInline*(text: string): seq[MarkdownElement]
```

**Parses**: `**bold**`, `*italic*`, `[text](url)`

**Implementation Notes**:
- Processes text character by character
- Maintains state for bold/italic flags
- Handles nested/overlapping formatting
- Flushes accumulated text when format changes
- **Critical**: Avoid nested procedures that capture `result` - causes closure issues in Nim

**Key Logic**:
1. Scan for markdown tokens: `[`, `*`, `**`
2. When found, flush current text buffer
3. Toggle formatting state or extract link
4. Continue scanning

### Main Document Parser

```nim
proc parseMarkdownDocument*(content: string): MarkdownDocument
```

**Algorithm**:

1. **Parse front matter** (YAML between `---` delimiters)
2. **Initialize section tracking**:
   - `currentSection`: Section being built
   - `hasCurrentSection`: bool flag
   - `sectionCounter`: for auto-generating IDs
   - `textBuffer`: accumulates text lines

3. **Line-by-line parsing**:
   ```
   For each line:
     If starts with '#':
       - Flush text buffer to current section
       - Finish current section (add to results)
       - Count '#' characters for heading level
       - Extract title
       - Start new section
     
     Else if starts with '```nim':
       - Flush text buffer
       - Parse code block with lifecycle hooks
       - Add to both flat list AND current section
       - Create default section if needed
     
     Else:
       - Add line to text buffer
   ```

4. **Finalization**:
   - Flush remaining text buffer
   - Finish last section
   - If no sections created, create default section with all code blocks

**Critical Implementation Detail**: 
- **Do NOT use nested procedures** that access `result`
- This creates closures that violate Nim's memory safety
- Instead, inline the logic or use temporary variables

### Code Block Association

Code blocks between headings belong to that section:

```markdown
# Section 1

Some text

```nim on:render
# This belongs to Section 1
```

# Section 2

```nim on:render
# This belongs to Section 2
```
```

Code blocks BEFORE the first heading can either:
- Create a default "intro" section
- Be added to a global code list

## Section Management API

### Context/State Structure

```nim
type
  Context = object  # or StorieContext, AppContext, etc.
    sections: seq[Section]
    currentSectionIndex: int
    multiSectionMode: bool
    scrollY: int  # for multi-section scrolling
```

### Core Functions

#### Query Functions

```nim
proc getCurrentSection*(): Section
proc getAllSections*(): seq[Section]
proc getSectionById*(id: string): Section
proc getSectionByIndex*(index: int): Section
proc getSectionCount*(): int
proc getCurrentSectionIndex*(): int
```

#### Navigation Functions

```nim
proc gotoSection*(target: int): bool
  ## Navigate to section by index
  ## Returns false if index out of bounds

proc gotoSectionById*(id: string): bool
  ## Navigate to section by ID
  ## Returns false if ID not found
```

**Implementation**:
- Validate bounds/existence
- Update `currentSectionIndex`
- Optionally trigger lifecycle events (on:exit, on:enter)
- Return success status

#### Manipulation Functions

```nim
proc createSection*(id: string, title: string, level: int = 1): bool
  ## Create new section dynamically

proc deleteSection*(id: string): bool
  ## Remove section by ID
  ## Adjust currentSectionIndex if needed

proc updateSectionTitle*(id: string, newTitle: string): bool
  ## Modify section metadata
```

#### Rendering Mode

```nim
proc setMultiSectionMode*(enabled: bool)
proc getMultiSectionMode*(): bool
proc setScrollY*(y: int)
proc getScrollY*(): int
```

**Multi-Section Mode**:
- `true`: Render all sections in scrollable view (like a document)
- `false`: Render only current section (like slides/pages)

## Script Bindings

### For Nimini/Lua/Python/JS Engines

Expose functions to the scripting engine. Example for Nimini:

```nim
proc nimini_getCurrentSection(env: ref Env; args: seq[Value]): Value {.nimini.} =
  let section = getCurrentSection()
  var table = initTable[string, Value]()
  table["id"] = valString(section.id)
  table["title"] = valString(section.title)
  table["level"] = valInt(section.level)
  table["blockCount"] = valInt(section.blocks.len)
  return valMap(table)  # or valTable depending on your system
```

**Register all functions**:
```nim
exportNiminiProcs(
  nimini_getCurrentSection,
  nimini_getAllSections,
  nimini_getSectionById,
  nimini_gotoSection,
  nimini_createSection,
  nimini_deleteSection,
  nimini_updateSectionTitle,
  nimini_setMultiSectionMode,
  nimini_getMultiSectionMode,
  nimini_setScrollY,
  nimini_getScrollY,
  nimini_getSectionCount,
  nimini_getCurrentSectionIndex
)
```

### Script Usage Examples

#### Basic Section Info

```nim
let count = nimini_getSectionCount()
let index = nimini_getCurrentSectionIndex()
print("Section " & $(index + 1) & " of " & $count)
```

#### Accessing Section Metadata

```nim
let sect = nimini_getCurrentSection()
let sectId = sect["id"]
let sectTitle = sect["title"]
```

**Important**: Extract map values before using operators:
```nim
# DON'T do this (causes parsing issues in some engines):
print("Level: " & $sect["level"])

# DO this instead:
let level = sect["level"]
print("Level: " & $level)
```

#### Navigation

```nim
# By index
if nimini_gotoSection(2):
  print("Navigated to section 3")

# By ID
if nimini_gotoSection("welcome_section"):
  print("Jumped to welcome")
```

#### Dynamic Section Creation

```nim
let newId = "dynamic_" & $count
nimini_createSection(newId, "New Section", 1)
```

## Lifecycle Hooks

### Section-Specific Hooks

Beyond global lifecycle hooks (init, render, update, input, shutdown), add section-specific hooks:

- `on:enter` - Execute when navigating TO this section
- `on:exit` - Execute when navigating AWAY from this section

**Implementation**: Store hook type in CodeBlock, execute during `gotoSection()`.

### Hook Execution Order

```
Navigation from Section A to Section B:
1. Execute Section A's on:exit hooks
2. Update currentSectionIndex
3. Execute Section B's on:enter hooks
4. Continue with normal on:update, on:render cycle
```

## Rendering Considerations

### Single-Section Mode

Render only `sections[currentSectionIndex]`:

```nim
proc renderCurrentSection():
  let section = getCurrentSection()
  var y = 0
  
  for block in section.blocks:
    case block.kind:
    of HeadingBlock:
      renderHeading(block.title, block.level, y)
      y += 2
    of TextBlock:
      renderText(block.elements, y)
      y += countLines(block.text)
    of CodeBlock_Content:
      # Code blocks don't render - they execute
      discard
```

### Multi-Section Mode

Render all sections with scrolling:

```nim
proc renderAllSections(scrollY: int):
  var y = -scrollY  # Start above viewport
  
  for section in getAllSections():
    for block in section.blocks:
      # Render block
      # Increment y
      # Skip if outside viewport
```

### For Raylib/SDL3

Instead of terminal text rendering, use:
- `DrawText()` for text blocks
- Parse markdown elements to apply formatting (bold/italic fonts)
- `DrawRectangle()` for section dividers
- Handle mouse wheel for scrolling
- Click on links to navigate

## Implementation Checklist

### Phase 1: Core Types
- [ ] Define MarkdownElement, ContentBlock, Section types
- [ ] Add sections field to document structure
- [ ] Maintain backward compatibility with flat code blocks list

### Phase 2: Parsing
- [ ] Implement `generateSectionId()`
- [ ] Implement `parseMarkdownInline()` for bold/italic/links
- [ ] Update document parser to build sections
- [ ] Test with various markdown files

### Phase 3: State Management
- [ ] Add section tracking to context/state
- [ ] Implement query functions (get, count, index)
- [ ] Implement navigation functions (goto)
- [ ] Implement manipulation functions (create, delete, update)

### Phase 4: Script Bindings
- [ ] Create wrapper functions for script engine
- [ ] Register all functions
- [ ] Test basic access from scripts

### Phase 5: Rendering
- [ ] Implement single-section rendering
- [ ] Implement multi-section rendering with scroll
- [ ] Add mode toggle functionality

### Phase 6: Lifecycle
- [ ] Add on:enter and on:exit hook support
- [ ] Execute hooks during navigation
- [ ] Test section-specific behavior

## Common Issues & Solutions

### Issue 1: Closure Violations
**Problem**: Nim complains about capturing `result` in nested procs  
**Solution**: Inline the logic instead of using nested procedures

### Issue 2: Map Access in Scripts
**Problem**: Complex expressions like `$map["key"]` fail  
**Solution**: Extract value to variable first:
```nim
let value = map["key"]
let str = $value
```

### Issue 3: Missing Sections
**Problem**: Markdown without headings creates no sections  
**Solution**: Create default section if `sections.len == 0`

### Issue 4: Code Block Association
**Problem**: Code blocks not appearing in sections  
**Solution**: Add to BOTH flat list and current section during parsing

### Issue 5: Section ID Conflicts
**Problem**: Two sections with same title  
**Solution**: Add numbering suffix: "welcome_1", "welcome_2"

## Testing Strategy

### Unit Tests
- Parse markdown with 0, 1, N sections
- Parse inline formatting
- Generate section IDs from various titles
- Handle edge cases (empty sections, code-only sections)

### Integration Tests
- Navigate between sections
- Create/delete sections
- Access section metadata from scripts
- Render single vs multi-section modes

### Regression Tests
- Old markdown files still work
- Code blocks execute correctly
- Front matter parsing unchanged

## Example Markdown File

```markdown
---
title: "Section Demo"
author: "Your Name"
---

# Welcome

This is the introduction section.

You can navigate with arrow keys!

```nim on:init
var currentIdx = 0
```

```nim on:render
currentIdx = getCurrentSectionIndex()
drawText("Section: " & $(currentIdx + 1))
```

```nim on:input
if keyPressed(KEY_RIGHT):
  gotoSection(currentIdx + 1)
```

# Second Section

More content here.

```nim on:render
drawText("This is section 2!")
```

# Conclusion

The end!
```

## Adaptation for Raylib/SDL3

### Key Differences from Terminal

1. **Coordinate System**: Pixel-based instead of character grid
2. **Text Rendering**: Use font rendering with proper layout
3. **Input**: Mouse + keyboard instead of terminal key codes
4. **Scrolling**: Smooth pixel scrolling vs discrete line scrolling
5. **Formatting**: Use different fonts for bold/italic

### Recommended Changes

1. **ContentBlock Rendering**:
   ```c
   // For each MarkdownElement:
   if (element.bold) {
     font = boldFont;
   }
   if (element.italic) {
     font = italicFont;
   }
   DrawTextEx(font, element.text, position, fontSize, spacing, color);
   ```

2. **Section Navigation UI**:
   - Add visual section list (sidebar or dropdown)
   - Clickable section titles
   - Progress indicator

3. **Smooth Transitions**:
   - Animate section changes
   - Fade in/out effects
   - Smooth scroll interpolation

4. **Interactive Elements**:
   - Clickable links (check mouse position vs text bounds)
   - Hover effects on links
   - Visual section separators

## Conclusion

This section-based system provides powerful document structure and navigation while maintaining backward compatibility. The key is clean separation between:
- **Parsing** (markdown → sections)
- **State** (current section tracking)
- **API** (script-accessible functions)
- **Rendering** (display logic)

By following this architecture, you can implement the same functionality in any engine with any rendering system.
