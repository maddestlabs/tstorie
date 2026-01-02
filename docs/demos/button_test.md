---
title: "Minimal Button Test"
---

# Minimal Button Test

Single button rendering test - SUCCESS! ✓

```nim on:init
# Create widget manager
print("Creating button...")

# Create a simple button
var myButton = newButton("test_btn", 10, 5, 20, 3, "Click Me")
addWidget(myButton)

print("✓ Button ready!")
```

```nim on:render
# Render widgets
renderWidgets()

# Add some help text
draw(0, 2, 15, "Button is rendering successfully!", defaultStyle())
```
