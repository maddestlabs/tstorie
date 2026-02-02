## Buffer Interface Definition
## Defines the abstract interface that all rendering backends must implement
##
## This allows the same high-level code (canvas, animations, etc.) to work
## with different rendering backends (terminal, SDL3, etc.)

import ../src/types

type
  RenderBuffer* = concept buffer
    ## Abstract interface for a 2D rendering buffer
    ## All backends (terminal, SDL3, etc.) must implement these operations
    
    # Core properties
    buffer.width is int
    buffer.height is int
    
    # Cell-based buffer operations - these are the primitives all backends support
    buffer.writeCell(x: int, y: int, ch: string, style: Style)
    buffer.writeCellText(x: int, y: int, text: string, style: Style)
    buffer.fillCellRect(x: int, y: int, w: int, h: int, ch: string, style: Style)
    buffer.clearCells(bgColor: tuple[r: uint8, g: uint8, b: uint8])
    buffer.clearCellsTransparent()
    
    # Cell access
    buffer.getCell(x: int, y: int) is tuple[ch: string, style: Style]
    
    # Clipping and offset (for advanced rendering)
    buffer.setClip(x: int, y: int, w: int, h: int)
    buffer.clearClip()
    buffer.setOffset(x: int, y: int)

  CanvasUnits* = enum
    ## Coordinate system used by a backend
    CellBased      # Terminal: 1 unit = 1 character cell (monospace)
    PixelBased     # SDL3: 1 unit = 1 pixel (sub-pixel positioning)

# Note: The concept above defines what operations must exist, but doesn't
# enforce implementation details. Each backend (terminal, SDL3) implements
# these operations in a way that makes sense for that platform.
#
# Terminal backend: writeText operates on character cells
# SDL3 backend: writeText renders TTF glyphs at pixel positions
#
# The beauty of this approach is that 95% of tStorie's code (canvas, animation,
# particles, etc.) doesn't need to know which backend it's using - it just
# calls these primitives and the backend handles the details.

## Backend Coordinate Systems
##
## TERMINAL BACKEND (CellBased):
##   - Units are character cells (typically 1 cell = 1 character width)
##   - x, y are integer cell coordinates
##   - Monospace fonts only (all characters same width)
##   - Fast rendering, minimal memory
##
## SDL3 BACKEND (PixelBased):
##   - Units are pixels (floating point for smooth motion)
##   - x, y can be sub-pixel positions (0.5, 2.3, etc.)
##   - Variable-width fonts supported (TTF rendering)
##   - Can still render monospace for terminal emulation
##   - Smooth scrolling, animations, effects

## Backend Selection
##
## Backends are selected at compile time using conditional compilation:
##
##   when defined(terminalBackend) or not defined(sdl3Backend):
##     import backends/terminal/termbuffer
##     type Canvas* = TermBuffer
##   elif defined(sdl3Backend):
##     import backends/sdl3/sdl_canvas
##     type Canvas* = SDLCanvas
##
## This means zero runtime overhead - only the code for the selected
## backend is included in the final binary.

## Migration Notes
##
## Phase 1 (Current): Terminal backend extracted to backends/terminal/
## - TermBuffer moved to backends/terminal/termbuffer.nim
## - No API changes, just file reorganization
## - All existing code continues to work
##
## Phase 2 (Future): SDL3 backend implementation
## - Create backends/sdl3/sdl_canvas.nim
## - Implement same interface as TermBuffer
## - Add compile-time backend selection
##
## Phase 3 (Future): Float coordinates for smooth motion
## - Camera positions become float (x: 45.7 instead of x: 45)
## - Terminal backend rounds to nearest cell
## - SDL3 backend uses exact pixel positions
