## Canvas Interactive Fiction Example
## Demonstrates how to use the canvas system with Nimini

import lib/canvas
import lib/canvas_bridge
import lib/storie_md

# This module exports canvas functions and sets up global handlers
# for use in markdown documents with Nimini code blocks

# Note: This is meant to be imported from a markdown global code block
# The actual setup happens when canvas.init() is called

type
  CanvasAPI* = object
    ## Exported API for Nimini scripts
    
proc init*(): bool =
  ## Initialize canvas system
  ## This should be called from a global code block in the markdown
  ## It will set up the rendering and input handlers
  result = true
  # The actual initialization happens in the global block

proc hideSection*(sectionRef: string) =
  ## Hide a section by reference (ID or title)
  canvas.hideSection(sectionRef)

proc removeSection*(sectionRef: string) =
  ## Remove a section from display
  canvas.removeSection(sectionRef)

proc restoreSection*(sectionRef: string) =
  ## Restore a removed section
  canvas.restoreSection(sectionRef)

proc markVisited*(sectionRef: string) =
  ## Manually mark a section as visited
  canvas.markVisited(sectionRef)

proc isVisited*(sectionRef: string): bool =
  ## Check if a section has been visited
  result = canvas.isVisited(sectionRef)

# Export the API
var canvasAPI* = CanvasAPI()
