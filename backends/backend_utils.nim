## Backend Utilities
## Helper functions and type aliases for multi-backend support
##
## This module provides utilities that work across all backends:
## - Coordinate conversion (float -> int for terminal, float -> pixel for SDL3)
## - Backend-agnostic helper functions
## - Type aliases based on compile-time backend selection

import ../src/types

# ================================================================
# BACKEND-AWARE COORDINATE CONVERSION
# ================================================================

when defined(sdl3Backend):
  # SDL3 backend - pixel-based coordinates (future)
  proc toScreenCoord*(f: float): int =
    ## Convert float coordinate to screen coordinate (pixel-perfect)
    int(f)
  
  proc toScreenCoordRounded*(f: float): int =
    ## Convert float coordinate to screen coordinate with rounding
    int(f + 0.5)
else:
  # Terminal backend - cell-based coordinates (default)
  proc toScreenCoord*(f: float): int =
    ## Convert float coordinate to character cell coordinate
    ## Rounds to nearest cell for character-aligned rendering
    int(f + 0.5)
  
  proc toScreenCoordRounded*(f: float): int =
    ## Convert float coordinate to screen coordinate with rounding
    int(f + 0.5)

# ================================================================
# BACKEND-AWARE RENDERING HELPERS
# ================================================================

proc toBackendUnits*(pixels: int): float =
  ## Convert pixels to backend units
  ## Terminal: 1 pixel ~= 1/8th of a character (approximate)
  ## SDL3: 1 pixel = 1 pixel
  when defined(sdl3Backend):
    float(pixels)
  else:
    # For terminal, assume ~8 pixels per character cell
    float(pixels) / 8.0

proc fromBackendUnits*(units: float): int =
  ## Convert backend units to pixels
  ## Terminal: 1 cell ~= 8 pixels (approximate)
  ## SDL3: 1 unit = 1 pixel
  when defined(sdl3Backend):
    int(units)
  else:
    # For terminal, assume ~8 pixels per character cell
    int(units * 8.0)

# ================================================================
# BACKEND INFORMATION
# ================================================================

const
  BackendName* = when defined(sdl3Backend): "SDL3" else: "Terminal"
  BackendUnits* = when defined(sdl3Backend): "pixels" else: "cells"
  BackendSupportsSubPixel* = when defined(sdl3Backend): true else: false

proc getBackendName*(): string =
  ## Get the name of the current backend
  BackendName

proc getBackendUnits*(): string =
  ## Get the unit type for the current backend
  BackendUnits

proc supportsSubPixelPositioning*(): bool =
  ## Check if backend supports sub-pixel positioning (smooth scrolling)
  BackendSupportsSubPixel
