---
title: "Theme Test"
---

# Theme Parameter Test

Testing custom hex theme parsing.

```nim
import storie_themes

# Test 1: Parse Neonopia custom theme
let customHex = "#110000#340905#110000#110000#ff2671#0000ff#00ff91"
print("Test 1: Custom hex theme")
print("  Input: " & customHex)

let custom = parseCustomTheme(customHex)
if custom.isSome:
  let theme = custom.get()
  print("  ✓ Parsed successfully!")
  print("  Accent1: #" & toHexString(theme.accent1))
else:
  print("  ✗ Failed to parse")

# Test 2: Get theme from URL param
print("\nTest 2: URL parameter")
let themeParam = getParam("theme")
print("  theme param: " & (if themeParam == "": "(empty)" else: themeParam))

let currentTheme = getTheme(themeParam)
print("  BG: #" & toHexString(currentTheme.bgPrimary))
print("  Accent1: #" & toHexString(currentTheme.accent1))

# Test 3: Built-in theme
print("\nTest 3: Built-in theme")
let dracula = getTheme("dracula")
print("  Dracula BG: #" & toHexString(dracula.bgPrimary))
print("  Dracula Accent1: #" & toHexString(dracula.accent1))

# Test 4: Invalid theme (should fallback)
print("\nTest 4: Invalid theme fallback")
let invalid = getTheme("#invalid")
print("  Invalid theme BG: #" & toHexString(invalid.bgPrimary))
print("  (Should be Neotopia: #001111)")

# Test 5: Generate shareable URL
print("\nTest 5: Generate shareable URL")
let shareableHex = toHexString(currentTheme)
print("  Shareable: ?theme=" & shareableHex)

print("\n✓ All tests complete!")
```
