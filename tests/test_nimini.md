# Test Nimini Functions

Test if nimini functions are available.

```nim on:render
bgClear()
bgWriteText(2, 2, "Basic functions work!")
bgWriteText(2, 4, "Now testing TUI...")
```

```nim on:init
# Try calling TUI function
newWidgetManager()
```
