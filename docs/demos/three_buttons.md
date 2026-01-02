# Three Buttons Demo

```nim on:init
var btn1 = newButton("start", 5, 6, 16, 3, "[ START ]")
addWidget(btn1)

var btn2 = newButton("stop", 5, 10, 16, 3, "[ STOP ]")
addWidget(btn2)

var btn3 = newButton("reset", 5, 14, 16, 3, "[ RESET ]")
addWidget(btn3)
```

```nim on:render
draw(0, 2, 1, "=== BUTTON DEMO ===", defaultStyle())
renderWidgets()
```
