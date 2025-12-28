## AppState Management Module
## Provides application state initialization, frame counting, and FPS tracking
##
## This module contains all state management functionality extracted from tstorie.nim

import types
import layers

# ================================================================
# APPSTATE INITIALIZATION
# ================================================================

proc newAppState*(width, height: int): AppState =
  ## Create a new application state with default values
  result = new(AppState)
  result.termWidth = width
  result.termHeight = height
  result.currentBuffer = newTermBuffer(width, height)
  result.previousBuffer = newTermBuffer(width, height)
  result.colorSupport = 16777216  # Full RGB support
  result.running = true
  result.layers = @[]
  result.targetFps = 60.0
  result.inputParser = newTerminalInputParser()
  result.lastMouseX = 0
  result.lastMouseY = 0
  result.fps = 60.0
  result.frameCount = 0
  result.totalTime = 0.0
  result.lastFpsUpdate = 0.0
  result.audioSystemPtr = nil
  result.themeBackground = (0'u8, 0'u8, 0'u8)

# ================================================================
# FPS AND FRAME MANAGEMENT
# ================================================================

proc setTargetFps*(state: AppState, fps: float) =
  ## Set the target frames per second
  state.targetFps = fps

proc updateFpsCounter*(state: AppState, deltaTime: float) =
  ## Update FPS counter based on delta time
  ## Should be called once per frame
  state.frameCount += 1
  state.totalTime += deltaTime
  
  # Update FPS calculation every 0.5 seconds
  if state.totalTime - state.lastFpsUpdate >= 0.5:
    state.fps = 1.0 / deltaTime
    state.lastFpsUpdate = state.totalTime

proc getFps*(state: AppState): float =
  ## Get current FPS
  result = state.fps

proc getFrameCount*(state: AppState): int =
  ## Get total frame count
  result = state.frameCount

proc getTotalTime*(state: AppState): float =
  ## Get total elapsed time in seconds
  result = state.totalTime

# ================================================================
# STATE RESIZE
# ================================================================

proc resizeState*(state: AppState, newWidth, newHeight: int) =
  ## Resize state buffers and layers to new dimensions
  state.termWidth = newWidth
  state.termHeight = newHeight
  state.currentBuffer = newTermBuffer(newWidth, newHeight)
  state.previousBuffer = newTermBuffer(newWidth, newHeight)
  state.resizeLayers(newWidth, newHeight)
