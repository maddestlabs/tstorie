## Canvas Module - Example loadable module for tstorie
##
## This demonstrates how to create reusable modules that can be loaded
## at runtime via require("gist:ID/canvas.nim")
##
## This is a simplified version of the Lua canvas.lua for demonstration

# Note: When this module is loaded via require(), it has access to all
# tstorie APIs registered in nimini_bridge.nim

type
  CanvasState = ref object
    initialized: bool
    sections: seq[tuple[title: string, x: int, y: int]]

var state = CanvasState(initialized: false, sections: @[])

proc init*() =
  ## Initialize the canvas system
  if state.initialized:
    return
  
  echo "Canvas module initialized!"
  state.initialized = true
  
  # Create a canvas layer
  createLayer("canvas", 10)

proc addSection*(title: string, x: int, y: int) =
  ## Add a section to the canvas at specific coordinates
  state.sections.add((title, x, y))

proc renderSection*(title: string, x: int, y: int, content: string) =
  ## Render a section with a title and content
  var currentY = y
  
  # Draw title
  let titleStyle = {
    "fg": rgb(255, 255, 0),
    "bold": true
  }
  write(x, currentY, "=== " & title & " ===", titleStyle)
  currentY += 1
  
  # Draw content line by line
  let contentStyle = {
    "fg": rgb(200, 200, 200)
  }
  
  for line in content.split("\n"):
    if line.len > 0:
      write(x, currentY, line, contentStyle)
      currentY += 1

proc drawBox*(x: int, y: int, w: int, h: int, title: string = "") =
  ## Draw a box with optional title
  let borderStyle = {
    "fg": rgb(100, 100, 255)
  }
  
  # Top border
  write(x, y, "┌" & ("─".repeat(w - 2)) & "┐", borderStyle)
  
  # Title if provided
  if title.len > 0:
    let titleX = x + 2
    write(titleX, y, " " & title & " ", borderStyle)
  
  # Sides
  for dy in 1..<h-1:
    write(x, y + dy, "│", borderStyle)
    write(x + w - 1, y + dy, "│", borderStyle)
  
  # Bottom border
  write(x, y + h - 1, "└" & ("─".repeat(w - 2)) & "┘", borderStyle)

proc clear*() =
  ## Clear the canvas
  # This would clear the canvas layer
  # For now, just reset sections
  state.sections = @[]

# Export functions for module users
# When this module is loaded, these will be available in the returned environment
