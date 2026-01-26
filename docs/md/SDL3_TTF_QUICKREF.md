# SDL3 TTF Fonts & Input - Quick Reference

## Font Management

### Initialize Fonts
```nim
# Automatic initialization when creating canvas
let canvas = newSDLCanvas(800, 600)
# Fonts are initialized automatically
```

### Load Custom Font
```nim
# Set custom font for canvas
canvas.setFont("/path/to/font.ttf", size = 20.0)

# Common font paths:
# Linux:   /usr/share/fonts/truetype/dejavu/DejaVuSans.ttf
# macOS:   /System/Library/Fonts/Helvetica.ttc
# Windows: C:\Windows\Fonts\arial.ttf
```

### Change Font Size
```nim
canvas.setFontSize(24.0)  # Changes current font size
```

### Reset to Default
```nim
canvas.resetFont()  # Back to system default monospace
```

### Measure Text
```nim
let (width, height) = canvas.measureText("Hello World")
echo "Text is ", width, "x", height, " pixels"
```

### Clear Cache
```nim
canvas.clearTextCache()  # Free memory from cached textures
```

## Text Rendering

### Basic Text
```nim
var style = Style()
style.fg = (255'u8, 255'u8, 255'u8)  # White

canvas.writeText(10, 10, "Hello!", style)
```

### With Colors
```nim
# Red text
style.fg = (255'u8, 0'u8, 0'u8)
canvas.writeText(10, 10, "Red text", style)

# Green background (for fillRect, not text yet)
style.bg = (0'u8, 255'u8, 0'u8)
canvas.fillRect(0, 0, 100, 50, " ", style)
```

### Multiple Fonts
```nim
# Title with large font
canvas.setFont("/path/to/bold.ttf", 32.0)
canvas.writeText(10, 10, "Title", style)

# Body with smaller font
canvas.setFont("/path/to/regular.ttf", 16.0)
canvas.writeText(10, 50, "Body text", style)
```

## Keyboard Input

### Import Types
```nim
import backends/sdl3/sdl_window
# Exports: SDLInputEvent, SDLInputEventKind, KeyCode, keyCodeToString
```

### Event Loop
```nim
for event in canvas.pollEvents():
  case event.kind
  of SDLKeyDown:
    handleKeyPress(event.key)
  of SDLKeyUp:
    handleKeyRelease(event.key)
  of SDLQuit:
    quit(0)
  of SDLResize:
    echo "New size: ", canvas.getSize()
  else:
    discard
```

### Check Specific Keys
```nim
proc handleKeyPress(key: KeyCode) =
  case key
  of KeyEscape:
    echo "ESC pressed, quitting"
    quit(0)
  
  of KeyReturn:
    echo "Enter pressed"
  
  of KeySpace:
    echo "Space pressed"
  
  of KeyUp, KeyDown, KeyLeft, KeyRight:
    echo "Arrow key: ", keyCodeToString(key)
  
  of KeyA..KeyZ:
    echo "Letter: ", keyCodeToString(key)
  
  of Key0..Key9:
    echo "Number: ", keyCodeToString(key)
  
  of KeyF1..KeyF12:
    echo "Function key: ", keyCodeToString(key)
  
  else:
    echo "Other key: ", keyCodeToString(key)
```

### Get Key Names
```nim
let event = canvas.pollEvents()[0]
if event.kind == SDLKeyDown:
  let name = keyCodeToString(event.key)
  echo "Pressed: ", name  # "A", "Escape", "F1", etc.
```

### Access Raw Scancode
```nim
if event.kind == SDLKeyDown:
  echo "KeyCode: ", event.key      # Mapped: KeyA, KeyEscape, etc.
  echo "Scancode: ", event.scancode # Raw SDL: 4, 41, etc.
```

## Key Code Reference

### Common Keys
```nim
KeyEscape, KeyReturn, KeySpace, KeyBackspace, KeyTab
KeyUp, KeyDown, KeyLeft, KeyRight
KeyHome, KeyEnd, KeyPageUp, KeyPageDown
KeyInsert, KeyDelete
```

### Letters
```nim
KeyA, KeyB, KeyC, ..., KeyZ
# Use ranges: KeyA..KeyZ
```

### Numbers
```nim
Key0, Key1, Key2, ..., Key9
# Use ranges: Key0..Key9
```

### Function Keys
```nim
KeyF1, KeyF2, ..., KeyF12
# Use ranges: KeyF1..KeyF12
```

### Modifiers
```nim
KeyLeftShift, KeyRightShift
KeyLeftCtrl, KeyRightCtrl
KeyLeftAlt, KeyRightAlt
```

## Complete Example

```nim
import backends/sdl3/sdl_canvas
import backends/sdl3/sdl_window
import src/types

proc main() =
  # Create window
  let canvas = newSDLCanvas(800, 600, "TTF Demo")
  if canvas.isNil:
    echo "Failed to create canvas"
    return
  defer: canvas.shutdown()
  
  # Load custom font
  canvas.setFont("/usr/share/fonts/truetype/dejavu/DejaVuSans-Bold.ttf", 24.0)
  
  var messages: seq[string] = @["Press any key..."]
  var running = true
  
  while running:
    # Handle events
    for event in canvas.pollEvents():
      case event.kind
      of SDLQuit:
        running = false
      
      of SDLKeyDown:
        let keyName = keyCodeToString(event.key)
        messages.add("Pressed: " & keyName)
        
        # Keep last 20 messages
        if messages.len > 20:
          messages = messages[^20..^1]
        
        # Check for quit
        if event.key == KeyEscape:
          running = false
      
      of SDLResize:
        let (w, h) = canvas.getSize()
        messages.add("Resized to: " & $w & "x" & $h)
      
      else:
        discard
    
    # Render
    canvas.clear((0'u8, 0'u8, 0'u8))  # Black background
    
    var style = Style()
    style.fg = (255'u8, 255'u8, 255'u8)  # White text
    
    # Draw all messages
    for i, msg in messages:
      canvas.writeText(10, 10 + i * 30, msg, style)
    
    canvas.present()

main()
```

## Performance Tips

### Cache Optimization
```nim
# Good: Same text rendered many times uses cache
for i in 0..100:
  canvas.writeText(10, i * 20, "Cached text", style)

# Bad: Unique text each time (no cache benefit)
for i in 0..100:
  canvas.writeText(10, i * 20, "Text " & $i, style)
```

### Font Loading
```nim
# Load fonts once at startup
canvas.setFont("/path/to/font.ttf", 16.0)

# Not: Load on every frame (slow!)
while running:
  canvas.setFont("/path/to/font.ttf", 16.0)  # DON'T DO THIS
  # ... render
```

### Memory Management
```nim
# Clear cache periodically if rendering many unique strings
if frameCount mod 1000 == 0:
  canvas.clearTextCache()  # Free memory every 1000 frames
```

## Troubleshooting

### "No default font found"
**Solution**: Install system fonts or specify custom font path
```bash
# Ubuntu/Debian
sudo apt-get install fonts-dejavu-core

# Or specify font manually
canvas.setFont("/path/to/your/font.ttf", 16.0)
```

### Text not appearing
**Checklist**:
1. Is `canvas.present()` called?
2. Is text color same as background? (check style.fg)
3. Is text positioned on-screen? (check x, y coordinates)
4. Did TTF initialization succeed? (check console for errors)

### Slow rendering
**Solutions**:
- Use texture cache (automatic)
- Render static text once to texture
- Reduce unique text strings
- Clear cache if using too much memory

### Key not recognized
```nim
# Check if KeyCode is defined
echo event.key  # Should show KeyA, not KeyUnknown
echo event.scancode  # Show raw SDL scancode

# Add missing keys to sdl_input.nim if needed
```

## Platform Notes

### Linux
- Default fonts usually in `/usr/share/fonts/`
- TTF fonts in `truetype/` subdirectory

### macOS
- System fonts in `/System/Library/Fonts/`
- User fonts in `/Library/Fonts/`
- TTC (TrueType Collection) files supported

### Windows
- Fonts in `C:\Windows\Fonts\`
- Use full path: `C:\Windows\Fonts\arial.ttf`

---

**Quick Start**: Create canvas → Load font → Write text → Present!  
**Best Practice**: Cache common text, clear cache periodically  
**Remember**: TTF requires SDL3_ttf library installed
