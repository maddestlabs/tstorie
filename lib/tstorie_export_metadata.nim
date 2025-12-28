## tStorie Export Metadata Registration
##
## Registers metadata for tStorie-specific library functions to enable
## proper import detection during export to native Nim.
##
## These functions exist in the tStorie runtime but for export, they map
## to specific lib/ modules.

import ../nimini/runtime
import tables

proc registerTStorieExportMetadata*() =
  ## Register export metadata for tStorie runtime functions
  ## Maps runtime functions to their lib/ module equivalents
  ## Call this after initStdlib() to add tStorie-specific metadata
  
  # Unified drawing API functions (defined in index.nim runtime)
  gFunctionMetadata["draw"] = FunctionMetadata(
    description: "Draw text on specified layer")
  
  gFunctionMetadata["clear"] = FunctionMetadata(
    description: "Clear layer(s)")
  
  gFunctionMetadata["fillRect"] = FunctionMetadata(
    description: "Fill rectangle on specified layer")
  
  # Terminal info functions -> available in runtime context
  # These need special handling in standalone mode
  gFunctionMetadata["termWidth"] = FunctionMetadata(
    description: "Get terminal width - requires runtime context")
  
  gFunctionMetadata["termHeight"] = FunctionMetadata(
    description: "Get terminal height - requires runtime context")
  
  # Style/Theme functions -> lib/storie_themes
  gFunctionMetadata["getStyle"] = FunctionMetadata(
    storieLibs: @["storie_themes"],
    description: "Get style by name from theme")
  
  gFunctionMetadata["applyTheme"] = FunctionMetadata(
    storieLibs: @["storie_themes"],
    description: "Apply theme to stylesheet")
  
  # Canvas/Drawing functions -> lib/canvas
  gFunctionMetadata["write"] = FunctionMetadata(
    storieLibs: @["canvas"],
    description: "Write single character at position")
  
  gFunctionMetadata["writeText"] = FunctionMetadata(
    storieLibs: @["canvas"],
    description: "Write text string at position")
  
  gFunctionMetadata["fillRect"] = FunctionMetadata(
    storieLibs: @["canvas"],
    description: "Fill rectangle with character")
  
  gFunctionMetadata["clearLayer"] = FunctionMetadata(
    storieLibs: @["canvas"],
    description: "Clear entire layer")
  
  gFunctionMetadata["clearLayerTransparent"] = FunctionMetadata(
    storieLibs: @["canvas"],
    description: "Clear layer to transparent")
  
  # Layout functions -> lib/layout
  gFunctionMetadata["wrapText"] = FunctionMetadata(
    storieLibs: @["layout"],
    description: "Wrap text to fit within width")
  
  gFunctionMetadata["alignHorizontal"] = FunctionMetadata(
    storieLibs: @["layout"],
    description: "Align text horizontally")
  
  gFunctionMetadata["writeAligned"] = FunctionMetadata(
    storieLibs: @["layout"],
    description: "Write aligned text")
  
  gFunctionMetadata["writeWrapped"] = FunctionMetadata(
    storieLibs: @["layout"],
    description: "Write wrapped text")
  
  gFunctionMetadata["writeTextBox"] = FunctionMetadata(
    storieLibs: @["layout"],
    description: "Write text box with wrapping and alignment")
  
  # Figlet functions -> lib/figlet  
  gFunctionMetadata["loadFont"] = FunctionMetadata(
    storieLibs: @["figlet"],
    description: "Load figlet font file")
  
  gFunctionMetadata["render"] = FunctionMetadata(
    storieLibs: @["figlet"],
    dependencies: @["loadFont"],
    description: "Render text in figlet font")
  
  # Audio functions -> lib/audio
  gFunctionMetadata["initAudio"] = FunctionMetadata(
    storieLibs: @["audio"],
    description: "Initialize audio system")
  
  gFunctionMetadata["playTone"] = FunctionMetadata(
    storieLibs: @["audio_gen"],
    description: "Play tone at frequency")
  
  gFunctionMetadata["playSound"] = FunctionMetadata(
    storieLibs: @["audio"],
    description: "Play registered sound by name")
  
  gFunctionMetadata["registerSound"] = FunctionMetadata(
    storieLibs: @["audio"],
    description: "Register sound sample")
  
  gFunctionMetadata["playBleep"] = FunctionMetadata(
    storieLibs: @["audio_gen"],
    dependencies: @["playTone"],
    description: "Play bleep sound effect")
  
  gFunctionMetadata["playJump"] = FunctionMetadata(
    storieLibs: @["audio_gen"],
    dependencies: @["playTone"],
    description: "Play jump sound effect")
  
  gFunctionMetadata["playHit"] = FunctionMetadata(
    storieLibs: @["audio_gen"],
    dependencies: @["playTone"],
    description: "Play hit sound effect")
  
  gFunctionMetadata["playLaser"] = FunctionMetadata(
    storieLibs: @["audio_gen"],
    dependencies: @["playTone"],
    description: "Play laser sound effect")
  
  # Animation functions -> lib/animation
  gFunctionMetadata["newAnimation"] = FunctionMetadata(
    storieLibs: @["animation"],
    description: "Create new animation")
  
  gFunctionMetadata["updateAnimation"] = FunctionMetadata(
    storieLibs: @["animation"],
    description: "Update animation state")
  
  # Section management -> lib/section_manager
  gFunctionMetadata["navigateToSection"] = FunctionMetadata(
    storieLibs: @["section_manager"],
    description: "Navigate to section by ID")
  
  gFunctionMetadata["getCurrentSection"] = FunctionMetadata(
    storieLibs: @["section_manager"],
    description: "Get current section ID")
  
  # TUI widgets -> lib/tui
  gFunctionMetadata["newWidgetManager"] = FunctionMetadata(
    storieLibs: @["tui"],
    description: "Create widget manager for TUI")
  
  gFunctionMetadata["newLabel"] = FunctionMetadata(
    storieLibs: @["tui"],
    dependencies: @["newWidgetManager"],
    description: "Create label widget")
  
  gFunctionMetadata["newButton"] = FunctionMetadata(
    storieLibs: @["tui"],
    dependencies: @["newWidgetManager"],
    description: "Create button widget")
  
  gFunctionMetadata["newCheckBox"] = FunctionMetadata(
    storieLibs: @["tui"],
    dependencies: @["newWidgetManager"],
    description: "Create checkbox widget")
  
  gFunctionMetadata["newTextBox"] = FunctionMetadata(
    storieLibs: @["tui", "textfield"],
    dependencies: @["newWidgetManager"],
    description: "Create text input widget")
  
  # Animation easing functions -> lib/animation
  gFunctionMetadata["easeLinear"] = FunctionMetadata(
    storieLibs: @["animation"],
    description: "Linear easing function")
  
  gFunctionMetadata["easeInQuad"] = FunctionMetadata(
    storieLibs: @["animation"],
    description: "Quadratic ease-in function")
  
  gFunctionMetadata["easeOutQuad"] = FunctionMetadata(
    storieLibs: @["animation"],
    description: "Quadratic ease-out function")
  
  gFunctionMetadata["easeInOutQuad"] = FunctionMetadata(
    storieLibs: @["animation"],
    description: "Quadratic ease-in-out function")
  
  gFunctionMetadata["easeInCubic"] = FunctionMetadata(
    storieLibs: @["animation"],
    description: "Cubic ease-in function")
  
  gFunctionMetadata["easeOutCubic"] = FunctionMetadata(
    storieLibs: @["animation"],
    description: "Cubic ease-out function")
  
  gFunctionMetadata["easeInOutCubic"] = FunctionMetadata(
    storieLibs: @["animation"],
    description: "Cubic ease-in-out function")
  
  gFunctionMetadata["easeInSine"] = FunctionMetadata(
    storieLibs: @["animation"],
    imports: @["math"],
    description: "Sine ease-in function")
  
  gFunctionMetadata["easeOutSine"] = FunctionMetadata(
    storieLibs: @["animation"],
    imports: @["math"],
    description: "Sine ease-out function")
  
  gFunctionMetadata["easeInOutSine"] = FunctionMetadata(
    storieLibs: @["animation"],
    imports: @["math"],
    description: "Sine ease-in-out function")
  
  gFunctionMetadata["lerp"] = FunctionMetadata(
    storieLibs: @["animation"],
    description: "Linear interpolation between two values")
  
  gFunctionMetadata["lerpColor"] = FunctionMetadata(
    storieLibs: @["animation"],
    description: "Interpolate between two colors")
  
  gFunctionMetadata["lerpStyle"] = FunctionMetadata(
    storieLibs: @["animation"],
    description: "Interpolate between two styles")
  
  gFunctionMetadata["newParticle"] = FunctionMetadata(
    storieLibs: @["animation"],
    description: "Create particle for particle system")
  
  # TextField widget functions -> lib/textfield
  gFunctionMetadata["newTextField"] = FunctionMetadata(
    storieLibs: @["textfield"],
    description: "Create text input field")
  
  gFunctionMetadata["setText"] = FunctionMetadata(
    storieLibs: @["textfield"],
    description: "Set text content of field")
  
  gFunctionMetadata["insert"] = FunctionMetadata(
    storieLibs: @["textfield"],
    description: "Insert character at cursor")
  
  gFunctionMetadata["deleteChar"] = FunctionMetadata(
    storieLibs: @["textfield"],
    description: "Delete character at cursor")
  
  gFunctionMetadata["backspace"] = FunctionMetadata(
    storieLibs: @["textfield"],
    description: "Delete character before cursor")
  
  gFunctionMetadata["moveCursorLeft"] = FunctionMetadata(
    storieLibs: @["textfield"],
    description: "Move cursor left")
  
  gFunctionMetadata["moveCursorRight"] = FunctionMetadata(
    storieLibs: @["textfield"],
    description: "Move cursor right")
  
  gFunctionMetadata["moveCursorHome"] = FunctionMetadata(
    storieLibs: @["textfield"],
    description: "Move cursor to start")
  
  gFunctionMetadata["moveCursorEnd"] = FunctionMetadata(
    storieLibs: @["textfield"],
    description: "Move cursor to end")
  
  # Event handling -> lib/events
  gFunctionMetadata["newTerminalEventHandler"] = FunctionMetadata(
    storieLibs: @["events"],
    description: "Create terminal event handler")
  
  gFunctionMetadata["captureKey"] = FunctionMetadata(
    storieLibs: @["events"],
    description: "Register key for capture")
  
  gFunctionMetadata["ignoreKey"] = FunctionMetadata(
    storieLibs: @["events"],
    description: "Register key to ignore")
  
  gFunctionMetadata["isKeyPressed"] = FunctionMetadata(
    storieLibs: @["events"],
    description: "Check if key is currently pressed")
  
  gFunctionMetadata["dispatchEvent"] = FunctionMetadata(
    storieLibs: @["events"],
    description: "Dispatch input event to handlers")
  
  # Transition effects -> lib/transition_helpers
  gFunctionMetadata["captureTermBuffer"] = FunctionMetadata(
    storieLibs: @["transition_helpers"],
    description: "Capture current terminal buffer state")
  
  gFunctionMetadata["transitionBuffers"] = FunctionMetadata(
    storieLibs: @["transition_helpers"],
    description: "Animate transition between buffers")
  
  gFunctionMetadata["transitionRegion"] = FunctionMetadata(
    storieLibs: @["transition_helpers"],
    description: "Animate transition in specific region")
  
  # Additional audio effects -> lib/audio
  gFunctionMetadata["playPowerUp"] = FunctionMetadata(
    storieLibs: @["audio"],
    description: "Play power-up sound effect")
  
  gFunctionMetadata["playLanding"] = FunctionMetadata(
    storieLibs: @["audio"],
    description: "Play landing sound effect")
  
  gFunctionMetadata["stopAll"] = FunctionMetadata(
    storieLibs: @["audio"],
    description: "Stop all playing sounds")
  
  gFunctionMetadata["registerSound"] = FunctionMetadata(
    storieLibs: @["audio"],
    description: "Register named sound sample")
  
  gFunctionMetadata["playSample"] = FunctionMetadata(
    storieLibs: @["audio"],
    description: "Play audio sample directly")

