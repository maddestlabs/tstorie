# Two Button Success Test

```nim on:init
var btn1 = newButton("start", 5, 5, 16, 3, "START")
addWidget(btn1)

var btn2 = newButton("stop", 25, 5, 16, 3, "STOP")
addWidget(btn2)
```

```nim on:render
renderWidgets()
```
