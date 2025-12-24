---
title: Button Click Test
---

# Button Click Debug Test

```nim on:init
var clicks = 0
nimini_newWidgetManager()
nimini_enableMouse()
nimini_newButton("btn", 5, 5, 10, 3, "Click")
```

```nim on:update
nimini_widgetManagerUpdate(deltaTime)
if nimini_widgetWasClicked("btn"):
  clicks = clicks + 1
```

```nim on:render
bgClear()
fgClear()
bgWriteText(2, 2, "Clicks: " & str(clicks))
bgWriteText(2, 10, "Press Q to quit")
nimini_widgetManagerRender("foreground")
```

```nim on:input
# Pass ALL events to widget manager
var handled = nimini_widgetManagerHandleInput()
if handled:
  return 1
return 0
```
