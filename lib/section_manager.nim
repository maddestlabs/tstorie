## Section Manager
##
## Provides section navigation, CRUD operations, and state management
## for markdown sections. This module is stateless - it operates on
## a SectionManager object that you create and manage.
##
## Includes optional Nimini bindings when used with tstorie.

import storie_types
export storie_types  # Re-export types so users get them automatically

type
  SectionManager* = object
    ## Manages section navigation and state
    sections*: seq[Section]       ## All sections from the document
    currentIndex*: int            ## Index of currently active section (default 0)
    multiSectionMode*: bool       ## If true, render all sections; if false, render only current
    scrollY*: int                 ## Scroll position for multi-section mode

proc newSectionManager*(sections: seq[Section]): SectionManager =
  ## Create a new section manager from parsed sections
  SectionManager(
    sections: sections,
    currentIndex: 0,
    multiSectionMode: true,
    scrollY: 0
  )

# ================================================================
# SECTION ACCESSORS
# ================================================================

proc getCurrentSection*(sm: SectionManager): Section =
  ## Get the currently active section
  if sm.sections.len == 0:
    result = Section(id: "", title: "", level: 1, blocks: @[])
  elif sm.currentIndex >= 0 and sm.currentIndex < sm.sections.len:
    result = sm.sections[sm.currentIndex]
  else:
    result = sm.sections[0]

proc getAllSections*(sm: SectionManager): seq[Section] =
  ## Get all sections in the document
  return sm.sections

proc getSectionById*(sm: SectionManager, id: string): Section =
  ## Get a section by its ID
  for section in sm.sections:
    if section.id == id:
      return section
  
  # Not found
  return Section(id: "", title: "", level: 1, blocks: @[])

proc getSectionByIndex*(sm: SectionManager, index: int): Section =
  ## Get a section by its index
  if index < 0 or index >= sm.sections.len:
    return Section(id: "", title: "", level: 1, blocks: @[])
  return sm.sections[index]

proc getSectionCount*(sm: SectionManager): int =
  ## Get total number of sections
  return sm.sections.len

proc getCurrentSectionIndex*(sm: SectionManager): int =
  ## Get the index of the current section
  return sm.currentIndex

# ================================================================
# SECTION NAVIGATION
# ================================================================

proc gotoSection*(sm: var SectionManager, target: int): bool =
  ## Navigate to a section by index
  if target < 0 or target >= sm.sections.len:
    return false
  
  sm.currentIndex = target
  
  # TODO: Execute on:exit for old section and on:enter for new section
  # This would require finding code blocks with those lifecycle hooks in each section
  
  return true

proc gotoSectionById*(sm: var SectionManager, id: string): bool =
  ## Navigate to a section by ID
  for i, section in sm.sections:
    if section.id == id:
      return sm.gotoSection(i)
  
  return false

# ================================================================
# SECTION CRUD OPERATIONS
# ================================================================

proc createSection*(sm: var SectionManager, id: string, title: string, level: int = 1): bool =
  ## Create a new section and add it to the document
  let newSection = Section(
    id: id,
    title: title,
    level: level,
    blocks: @[ContentBlock(kind: HeadingBlock, level: level, title: title)]
  )
  
  sm.sections.add(newSection)
  return true

proc deleteSection*(sm: var SectionManager, id: string): bool =
  ## Delete a section by ID
  var indexToDelete = -1
  for i, section in sm.sections:
    if section.id == id:
      indexToDelete = i
      break
  
  if indexToDelete >= 0:
    sm.sections.delete(indexToDelete)
    # Adjust current index if needed
    if sm.currentIndex >= sm.sections.len:
      sm.currentIndex = max(0, sm.sections.len - 1)
    return true
  
  return false

proc updateSectionTitle*(sm: var SectionManager, id: string, newTitle: string): bool =
  ## Update a section's title
  for section in sm.sections.mitems:
    if section.id == id:
      section.title = newTitle
      # Update the heading block if it exists
      for blk in section.blocks.mitems:
        if blk.kind == HeadingBlock:
          blk.title = newTitle
          break
      return true
  
  return false

# ================================================================
# VIEW MODE & SCROLL MANAGEMENT
# ================================================================

proc setMultiSectionMode*(sm: var SectionManager, enabled: bool) =
  ## Enable or disable multi-section rendering mode
  sm.multiSectionMode = enabled

proc getMultiSectionMode*(sm: SectionManager): bool =
  ## Get current multi-section mode setting
  return sm.multiSectionMode

proc setScrollY*(sm: var SectionManager, y: int) =
  ## Set scroll position for multi-section mode
  sm.scrollY = y

proc getScrollY*(sm: SectionManager): int =
  ## Get current scroll position
  return sm.scrollY

# ================================================================
# NIMINI BINDINGS
# ================================================================

import ../nimini
import tables

# Helper to convert Value to int (handles both int and float values)
proc valueToInt(v: Value): int =
  case v.kind
  of vkInt: return v.i
  of vkFloat: return int(v.f)
  else: return 0

# Global reference to the section manager (set by registerSectionManagerBindings)
var gSectionMgr*: ptr SectionManager

proc registerSectionManagerBindings*(mgr: ptr SectionManager) =
  ## Register the section manager instance for nimini bindings to use
  gSectionMgr = mgr

proc nimini_getCurrentSection*(env: ref Env; args: seq[Value]): Value {.nimini.} =
  ## Get the currently active section as a table
  if gSectionMgr.isNil:
    return valNil()
  
  let section = gSectionMgr[].getCurrentSection()
  var table = initTable[string, Value]()
  table["id"] = valString(section.id)
  table["title"] = valString(section.title)
  table["level"] = valInt(section.level)
  table["blockCount"] = valInt(section.blocks.len)
  table["index"] = valInt(gSectionMgr[].getCurrentSectionIndex())
  
  # Add metadata as a nested table
  var metadataTable = initTable[string, Value]()
  for key, val in section.metadata:
    metadataTable[key] = valString(val)
  table["metadata"] = valMap(metadataTable)
  
  return valMap(table)

proc nimini_getAllSections*(env: ref Env; args: seq[Value]): Value {.nimini.} =
  ## Get all sections as an array of tables
  if gSectionMgr.isNil:
    return valArray(@[])
  
  let sections = gSectionMgr[].getAllSections()
  var arr: seq[Value] = @[]
  for i, section in sections:
    var table = initTable[string, Value]()
    table["id"] = valString(section.id)
    table["title"] = valString(section.title)
    table["level"] = valInt(section.level)
    table["blockCount"] = valInt(section.blocks.len)
    table["index"] = valInt(i)
    
    # Add metadata as a nested table
    var metadataTable = initTable[string, Value]()
    for key, val in section.metadata:
      metadataTable[key] = valString(val)
    table["metadata"] = valMap(metadataTable)
    
    arr.add(valMap(table))
  return valArray(arr)

proc nimini_getSectionById*(env: ref Env; args: seq[Value]): Value {.nimini.} =
  ## Get a section by ID. Args: id (string)
  if gSectionMgr.isNil or args.len == 0:
    return valNil()
  
  let id = args[0].s
  let section = gSectionMgr[].getSectionById(id)
  if section.id.len == 0:
    return valNil()
  
  # Find index
  var sectionIndex = 0
  for i, s in gSectionMgr[].getAllSections():
    if s.id == id:
      sectionIndex = i
      break
  
  var table = initTable[string, Value]()
  table["id"] = valString(section.id)
  table["title"] = valString(section.title)
  table["level"] = valInt(section.level)
  table["blockCount"] = valInt(section.blocks.len)
  table["index"] = valInt(sectionIndex)
  
  # Add metadata as a nested table
  var metadataTable = initTable[string, Value]()
  for key, val in section.metadata:
    metadataTable[key] = valString(val)
  table["metadata"] = valMap(metadataTable)
  
  return valMap(table)

proc nimini_gotoSection*(env: ref Env; args: seq[Value]): Value {.nimini.} =
  ## Navigate to a section. Args: target (int index or string ID)
  if gSectionMgr.isNil or args.len == 0:
    return valBool(false)
  
  let success = case args[0].kind
    of vkInt:
      gSectionMgr[].gotoSection(args[0].i)
    of vkString:
      gSectionMgr[].gotoSectionById(args[0].s)
    else:
      false
  
  return valBool(success)

proc nimini_createSection*(env: ref Env; args: seq[Value]): Value {.nimini.} =
  ## Create a new section. Args: id (string), title (string), level (int, default 1)
  if gSectionMgr.isNil or args.len < 2:
    return valBool(false)
  
  let id = args[0].s
  let title = args[1].s
  let level = if args.len > 2: valueToInt(args[2]) else: 1
  
  return valBool(gSectionMgr[].createSection(id, title, level))

proc nimini_deleteSection*(env: ref Env; args: seq[Value]): Value {.nimini.} =
  ## Delete a section by ID. Args: id (string)
  if gSectionMgr.isNil or args.len == 0:
    return valBool(false)
  
  let id = args[0].s
  return valBool(gSectionMgr[].deleteSection(id))

proc nimini_updateSectionTitle*(env: ref Env; args: seq[Value]): Value {.nimini.} =
  ## Update a section's title. Args: id (string), newTitle (string)
  if gSectionMgr.isNil or args.len < 2:
    return valBool(false)
  
  let id = args[0].s
  let newTitle = args[1].s
  return valBool(gSectionMgr[].updateSectionTitle(id, newTitle))

proc nimini_setMultiSectionMode*(env: ref Env; args: seq[Value]): Value {.nimini.} =
  ## Enable or disable multi-section rendering. Args: enabled (bool)
  if gSectionMgr.isNil or args.len == 0:
    return valNil()
  
  let enabled = args[0].b
  gSectionMgr[].setMultiSectionMode(enabled)
  return valNil()

proc nimini_getMultiSectionMode*(env: ref Env; args: seq[Value]): Value {.nimini.} =
  ## Get current multi-section mode setting
  if gSectionMgr.isNil:
    return valBool(true)
  return valBool(gSectionMgr[].getMultiSectionMode())

proc nimini_setScrollY*(env: ref Env; args: seq[Value]): Value {.nimini.} =
  ## Set scroll position. Args: y (int)
  if gSectionMgr.isNil or args.len == 0:
    return valNil()
  
  gSectionMgr[].setScrollY(valueToInt(args[0]))
  return valNil()

proc nimini_getScrollY*(env: ref Env; args: seq[Value]): Value {.nimini.} =
  ## Get current scroll position
  if gSectionMgr.isNil:
    return valInt(0)
  return valInt(gSectionMgr[].getScrollY())

proc nimini_getSectionCount*(env: ref Env; args: seq[Value]): Value {.nimini.} =
  ## Get total number of sections
  if gSectionMgr.isNil:
    return valInt(0)
  return valInt(gSectionMgr[].getSectionCount())

proc nimini_getCurrentSectionIndex*(env: ref Env; args: seq[Value]): Value {.nimini.} =
  ## Get the index of the current section
  if gSectionMgr.isNil:
    return valInt(0)
  return valInt(gSectionMgr[].getCurrentSectionIndex())

