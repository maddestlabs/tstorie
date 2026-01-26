---
title: "Unicode & Emoji Test"
theme: "default"
---

```nim on:init
print "Init: Testing unicode and emoji rendering"
```

```nim on:render
# Clear and draw unicode characters
clear()

# ASCII baseline
draw(0, 2, 2, "ASCII: Hello World!", defaultStyle())

# Unicode characters
draw(0, 2, 4, "Unicode: Héllo Wörld! 日本語 العربية", defaultStyle())

# Box drawing
draw(0, 2, 6, "Box: ┌─────┐ │ BOX │ └─────┘", defaultStyle())

# Emoji (if supported)
draw(0, 2, 8, "Emoji: 😀 🎨 🚀 ⭐ 💻 🌈", defaultStyle())

# Math symbols
draw(0, 2, 10, "Math: π ≈ 3.14159 ∑ ∫ √ ∞", defaultStyle())

# Arrows and symbols
draw(0, 2, 12, "Arrows: → ← ↑ ↓ ⇒ ⇐ ↔", defaultStyle())
```
