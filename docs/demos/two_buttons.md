# Two Buttons Test

```nim on:init
print("Test 1: Creating first button...")
var btn1 = newButton("btn1", 5, 5, 10, 3, "BTN1")
print("  First button created")

print("Test 2: Creating second button...")
var btn2 = newButton("btn2", 5, 10, 10, 3, "BTN2")
print("  Second button created")

print("Test 3: Adding first button...")
addWidget(btn1)
print("  First button added")

print("Test 4: Adding second button...")
addWidget(btn2)
print("  Second button added")

print("SUCCESS: Both buttons created and added!")
```

```nim on:render
renderWidgets()
```
