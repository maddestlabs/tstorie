---
name: "Themer - Interactive Theme Editor"
theme: "coffee"
shaders: "paper"
---

# 🎨 Themer

Interactive theme editor powered by the TUI system. Browse presets, customize colors, and generate shareable theme URLs!

```nim on:init  
  initTUI()
  
  # State
  var currentScreen = 0  # 0=menu, 1=presets, 2-4=color editors
  var selectedPreset = -1
  var mousePressed = false
  
  # Flat array: 7 colors × 3 RGB channels = 21 values
  # Order: bg, bgAlt, fg, fgAlt, accent1, accent2, accent3
  # Each color has [R, G, B] stored sequentially
  var themeColors = @[0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0]
  
  # Built-in theme names (using separate variables to avoid array in init)
  var preset0 = "neotopia"
  var preset1 = "neonopia"
  var preset2 = "catppuccin"
  var preset3 = "nord"
  var preset4 = "dracula"
  var preset5 = "outrun"
  var preset6 = "coffee"
  var preset7 = "stonegarden"
  
  # Initialize with coffee theme defaults (current theme)
  proc initDefaultColors() =
    # Coffee: warm cream and burgundy palette
    themeColors[0] = 242    # bg.r (cream)
    themeColors[1] = 211    # bg.g
    themeColors[2] = 172    # bg.b
    themeColors[3] = 115    # bgAlt.r (dark burgundy)
    themeColors[4] = 20     # bgAlt.g
    themeColors[5] = 37     # bgAlt.b
    themeColors[6] = 38     # fg.r (deep purple-brown)
    themeColors[7] = 3      # fg.g
    themeColors[8] = 36     # fg.b
    themeColors[9] = 191    # fgAlt.r (tan)
    themeColors[10] = 140   # fgAlt.g
    themeColors[11] = 111   # fgAlt.b
    themeColors[12] = 191   # accent1.r (rich red)
    themeColors[13] = 52    # accent1.g
    themeColors[14] = 52    # accent1.b
    themeColors[15] = 191   # accent2.r (tan)
    themeColors[16] = 140   # accent2.g
    themeColors[17] = 111   # accent2.b
    themeColors[18] = 242   # accent3.r (cream accent)
    themeColors[19] = 211   # accent3.g
    themeColors[20] = 172   # accent3.b
  
  # Build hex theme string from current colors
  # Format: RRGGBB+RRGGBB+RRGGBB+RRGGBB+RRGGBB+RRGGBB+RRGGBB
  proc buildThemeHex(): string =
    result = ""
    for colorIdx in 0..6:
      if colorIdx > 0:
        result = result & "+"
      var baseIdx = colorIdx * 3
      result = result & toHex(themeColors[baseIdx], 2)
      result = result & toHex(themeColors[baseIdx + 1], 2)
      result = result & toHex(themeColors[baseIdx + 2], 2)
  
  # Apply custom theme from current slider values
  proc applyCustomTheme() =
    var hexTheme = buildThemeHex()
    switchTheme(hexTheme)
  
  # Initialize with default colors
  initDefaultColors()
  
  # Group 0: Main Menu
  initLabel(0, 10, 2, 50, 1, "🎨 THEMER - THEME EDITOR", "center", 0)
  initButton(1, 10, 5, 30, 3, "Browse Presets", 0)
  initButton(2, 10, 9, 30, 3, "Edit Colors", 0)
  initButton(3, 10, 13, 30, 3, "Apply Custom", 0)
  initLabel(4, 10, 17, 50, 1, "Create and share custom themes!", "left", 0)
  
  # Group 1: Preset Browser
  initLabel(5, 10, 2, 50, 1, "SELECT PRESET THEME", "center", 1)
  initButton(6, 10, 5, 22, 3, preset0, 1)
  initButton(7, 35, 5, 22, 3, preset1, 1)
  initButton(8, 10, 9, 22, 3, preset2, 1)
  initButton(9, 35, 9, 22, 3, preset3, 1)
  initButton(10, 10, 13, 22, 3, preset4, 1)
  initButton(11, 35, 13, 22, 3, preset5, 1)
  initButton(12, 10, 17, 22, 3, preset6, 1)
  initButton(13, 35, 17, 22, 3, preset7, 1)
  initButton(14, 10, 21, 22, 3, "< Back", 1)
  
  # Group 2: Background Color Editor (indices 0-2 = bg)
  initLabel(15, 10, 2, 50, 1, "BACKGROUND COLOR", "center", 2)
  initSlider(16, 10, 5, 45, 3, "Red", 0, 255, themeColors[0], 2)
  initSlider(17, 10, 9, 45, 3, "Green", 0, 255, themeColors[1], 2)
  initSlider(18, 10, 13, 45, 3, "Blue", 0, 255, themeColors[2], 2)
  initButton(19, 10, 18, 15, 3, "< Menu", 2)
  initButton(20, 30, 18, 15, 3, "Next >", 2)
  
  # Group 3: Foreground Color Editor (indices 6-8 = fg)
  initLabel(21, 10, 2, 50, 1, "TEXT COLOR", "center", 3)
  initSlider(22, 10, 5, 45, 3, "Red", 0, 255, themeColors[6], 3)
  initSlider(23, 10, 9, 45, 3, "Green", 0, 255, themeColors[7], 3)
  initSlider(24, 10, 13, 45, 3, "Blue", 0, 255, themeColors[8], 3)
  initButton(25, 10, 18, 15, 3, "< Back", 3)
  initButton(26, 30, 18, 15, 3, "Next >", 3)
  
  # Group 4: Accent Color Editor (indices 12-14 = accent1)
  initLabel(27, 10, 2, 50, 1, "ACCENT COLOR", "center", 4)
  initSlider(28, 10, 5, 45, 3, "Red", 0, 255, themeColors[12], 4)
  initSlider(29, 10, 9, 45, 3, "Green", 0, 255, themeColors[13], 4)
  initSlider(30, 10, 13, 45, 3, "Blue", 0, 255, themeColors[14], 4)
  initButton(31, 10, 18, 15, 3, "< Back", 4)
  initButton(0, 30, 18, 15, 3, "Apply!", 4)
  
  # Start with only main menu visible
  setGroupVisible(1, false)
  setGroupVisible(2, false)
  setGroupVisible(3, false)
  setGroupVisible(4, false)
```

```nim on:input
  if event.type == "mouse":
    if event.action == "press":
      mousePressed = true
    elif event.action == "release":
      mousePressed = false
```

```nim on:update
  updateTUI(mouseX, mouseY, mousePressed)
  
  # Main Menu (Group 0)
  if wasClicked(1):  # Browse Presets
    setGroupVisible(0, false)
    setGroupVisible(1, true)
    currentScreen = 1
  
  if wasClicked(2):  # Edit Colors
    setGroupVisible(0, false)
    setGroupVisible(2, true)
    currentScreen = 2
  
  if wasClicked(3):  # Apply Custom
    applyCustomTheme()
  
  # Preset Browser (Group 1)
  if wasClicked(6):
    switchTheme(preset0)
  if wasClicked(7):
    switchTheme(preset1)
  if wasClicked(8):
    switchTheme(preset2)
  if wasClicked(9):
    switchTheme(preset3)
  if wasClicked(10):
    switchTheme(preset4)
  if wasClicked(11):
    switchTheme(preset5)
  if wasClicked(12):
    switchTheme(preset6)
  if wasClicked(13):
    switchTheme(preset7)
  
  if wasClicked(14):  # Back
    setGroupVisible(1, false)
    setGroupVisible(0, true)
    currentScreen = 0
  
  # Background Editor (Group 2) - bg color (indices 0-2)
  themeColors[0] = getSliderValue(16)
  themeColors[1] = getSliderValue(17)
  themeColors[2] = getSliderValue(18)
  
  if wasClicked(19):  # Menu
    setGroupVisible(2, false)
    setGroupVisible(0, true)
    currentScreen = 0
  if wasClicked(20):  # Next
    setGroupVisible(2, false)
    setGroupVisible(3, true)
    currentScreen = 3
  
  # Foreground Editor (Group 3) - fg color (indices 6-8)
  themeColors[6] = getSliderValue(22)
  themeColors[7] = getSliderValue(23)
  themeColors[8] = getSliderValue(24)
  
  if wasClicked(25):  # Back
    setGroupVisible(3, false)
    setGroupVisible(2, true)
    currentScreen = 2
  if wasClicked(26):  # Next
    setGroupVisible(3, false)
    setGroupVisible(4, true)
    currentScreen = 4
  
  # Accent Editor (Group 4) - accent1 color (indices 12-14)
  themeColors[12] = getSliderValue(28)
  themeColors[13] = getSliderValue(29)
  themeColors[14] = getSliderValue(30)
  
  if wasClicked(31):  # Back
    setGroupVisible(4, false)
    setGroupVisible(3, true)
    currentScreen = 3
  if wasClicked(0):  # Apply (reusing button ID 0)
    applyCustomTheme()
    setGroupVisible(4, false)
    setGroupVisible(0, true)
    currentScreen = 0
```

```nim on:render
  clear()
  
  # Draw all TUI widgets
  drawTUI("button")
  
  # Show context-specific information at bottom
  if currentScreen == 0:
    draw(0, 5, 23, "Navigate with mouse • Customize colors • Share themes", "dim")
    var hexTheme = buildThemeHex()
    draw(0, 5, 24, "Theme URL: ?theme=" & hexTheme, "info")
  elif currentScreen == 1:
    draw(0, 5, 23, "Click any preset to preview instantly", "dim")
    draw(0, 5, 24, "Press 'Back' to return to menu", "dim")
  elif currentScreen >= 2 and currentScreen <= 4:
    # Show live RGB preview
    var baseIdx = 0
    if currentScreen == 2:
      baseIdx = 0   # bg
    elif currentScreen == 3:
      baseIdx = 6   # fg
    elif currentScreen == 4:
      baseIdx = 12  # accent1
    
    var r = themeColors[baseIdx]
    var g = themeColors[baseIdx + 1]
    var b = themeColors[baseIdx + 2]
    
    draw(0, 5, 23, "Adjust RGB sliders to customize color", "dim")
    draw(0, 5, 24, "Preview: RGB(" & str(r) & ", " & str(g) & ", " & str(b) & ")", "info")
```
