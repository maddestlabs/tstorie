# SDL3 Web Testing - Quick Reference

## 🚀 Quick Start

### Test URLs
```bash
# Basic test page
http://localhost:8001/index-sdl3.html

# Enhanced debug page (recommended)
http://localhost:8001/test-sdl3.html

# With URL parameters
http://localhost:8001/test-sdl3.html?theme=dark&test=1
```

### Server Control
```bash
# Start server (if not running)
cd /workspaces/telestorie/docs
python3 -m http.server 8001

# Check if running
lsof -ti:8001

# Stop server
kill $(lsof -ti:8001)
```

### Rebuild
```bash
# Full rebuild
cd /workspaces/telestorie
./build-web-sdl3.sh

# Debug build
./build-web-sdl3.sh -d

# Build and serve
./build-web-sdl3.sh -s
```

## 📊 Build Artifacts

```
docs/tstorie-sdl3.wasm    2.0M   ✅ WASM binary
docs/tstorie-sdl3.js      368K   ✅ SDL3 glue
docs/tstorie-sdl3.data    4.0K   ✅ Assets
docs/index-sdl3.html      1.9K   ✅ Basic wrapper
docs/test-sdl3.html       7.8K   ✅ Debug page
```

## 🧪 Testing Checklist

### Visual Tests
- [ ] Canvas appears (1024x768)
- [ ] Black background visible
- [ ] Green border (debug page)
- [ ] Status indicator updates
- [ ] No rendering errors

### Console Tests
- [ ] "[tStorie]" messages appear
- [ ] "Initializing SDL3 web..." logged
- [ ] "SDL3 canvas initialized" logged
- [ ] "Starting SDL3 main loop..." logged
- [ ] No JavaScript errors

### Interactive Tests
- [ ] Click "Test URL Params" button
- [ ] Click "Simulate Input" button
- [ ] Try keyboard input (focus canvas first)
- [ ] Check URL with ?theme=dark
- [ ] Reload with parameters

### Performance Tests
- [ ] Page loads < 3 seconds
- [ ] WASM loads successfully
- [ ] Module initializes
- [ ] Main loop starts
- [ ] No console errors

## 🐛 Troubleshooting

### Canvas Not Appearing
```
Check:
- Canvas element in DOM
- Module.canvas set correctly
- SDL_Init succeeded
- Renderer created
```

### Module Load Failure
```
Check:
- tstorie-sdl3.js loads (368K)
- tstorie-sdl3.wasm loads (2.0M)
- tstorie-sdl3.data loads (4.0K)
- No 404 errors in network tab
```

### Console Errors
```
Common issues:
- "Cannot find module" → Check file paths
- "Invalid WASM" → Rebuild WASM
- "SDL_Init failed" → Check canvas setup
- "Module is undefined" → Check script load order
```

### No Logs Appearing
```
Check:
- Module.print defined
- Module.printErr defined
- consoleLog() working
- Browser console open
```

## 📝 Expected Console Output

### Successful Load
```
[Init] Loading tStorie SDL3...
[Init] Canvas: 1024x768
[Status] Running
[Module] Runtime initialized successfully!
[tStorie] Initializing tStorie SDL3 web...
[tStorie] URL param: (if any)
[tStorie] SDL3 canvas initialized: 1024x768
[tStorie] Starting SDL3 main loop...
```

### With URL Parameters
```
[tStorie] URL param: theme=dark
[tStorie] URL param: gist=test
[tStorie] Loading gist: test
[tStorie] [Web] Gist loading not yet implemented: test
```

## 🎯 Debug Page Features

### Buttons
- **Test URL Params** - Parse and display query string
- **Simulate Input** - Fire keyboard event
- **Clear Console** - Reset log display
- **Reload with Params** - Test with ?theme=dark&test=1

### Status Colors
- 🟢 Green "Ready ✓" - Success
- 🟡 Yellow "Loading..." - In progress
- 🔴 Red "Error" - Failed

### Console Colors
- Green - Normal logs
- Yellow - Warnings
- Red - Errors

## 🔧 Advanced Testing

### Browser DevTools
```bash
# Open browser DevTools
Right-click → Inspect Element

# Check tabs:
- Console: Error messages
- Network: File loading (2.0M WASM)
- Performance: FPS monitoring
- Memory: Usage tracking
```

### URL Parameter Tests
```
?theme=dark              Single param
?theme=dark&test=1       Multiple params
?gist=abc123             Gist loading (stub)
?width=800&height=600    Custom dimensions
```

### Keyboard Tests
```
Focus canvas (click it)
Press: a-z, 0-9, arrows, space, enter
Check console for event logs
```

## 📚 Documentation

- `SDL3_WEB_PHASE4_COMPLETE.md` - Detailed test results
- `SDL3_WEB_PROGRESS_SUMMARY.md` - Overall progress
- `SDL3_WEB_QUICK_REFERENCE.md` - This document

## 🎯 Next Steps

1. **Open test page**: http://localhost:8001/test-sdl3.html
2. **Check console**: Look for initialization messages
3. **Test interactions**: Click buttons, try input
4. **Verify rendering**: Canvas should show output
5. **Report issues**: Document any errors found

## ✅ Success Indicators

- ✅ Page loads without errors
- ✅ Module initializes successfully
- ✅ Console shows "[tStorie]" messages
- ✅ Status changes to "Ready ✓"
- ✅ URL parameters parse correctly
- 🔄 Canvas shows visual output (pending)
- 🔄 Input events work (pending)

---
**Server**: http://localhost:8001  
**Status**: ✅ Ready for testing  
**Phase**: 4 of 7 complete  
