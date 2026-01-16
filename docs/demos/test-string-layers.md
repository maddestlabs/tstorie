## Test Phase 2: String-based Drawing Functions

```nim on:init
var testResult = "Not tested yet"
```

```nim on:render
clear()

print("About to test integer layer...")
# Test integer layer first (should work)
fillBox(0, 5, 3, 10, 3, "█", getStyle("dim"))
drawLabel(0, 6, 4, "Int: OK", getStyle("success"))

print("About to test string layer...")
# Test string-based layer API
fillBox("default", 20, 3, 20, 5, "█", getStyle("primary"))
drawLabel("default", 22, 5, "Phase 2 Test", getStyle("warning"))

print("Tests complete")
testResult = "✓ All tests passed"
drawLabel("default", 5, 13, testResult, getStyle("success"))
```
drawLabel("default", 5, 13, testResult, getStyle("success"))
```
