---
title: "Code Block Access Test"
author: "Maddest Labs"
minWidth: 60
minHeight: 18
theme: "default"
---

```nim on:init
# Test code block access functions
var testResults = ""
```

```nim on:render
clear()

# Get the current section index
var currentIdx = getCurrentSectionIndex()
testResults = "Current section: " & $currentIdx & "\n\n"

# Get all code blocks from current section filtered by "data" language
var dataBlocks = getCurrentSectionCodeBlocks("data")
testResults = testResults & "Found " & $len(dataBlocks) & " 'data' blocks\n\n"

# Display content of each data block
var i = 0
for block in dataBlocks:
  testResults = testResults & "Block " & $i & ":\n"
  testResults = testResults & block["code"] & "\n\n"
  i = i + 1

# Draw results
draw(0, 2, 2, testResults)
```

# Test Section

This section contains some data blocks that we'll read from the script:

```data
Level 1 Data:
############
#  @    . #
############
```

```data
Level 2 Data:
##########
# @  .  #
##########
```

Some regular text between blocks.

```data
Level 3 Data:
#######
# @ . #
#######
```
