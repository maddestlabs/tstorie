---
title: "Canvas Editor Demo"
author: "Maddest Labs"
minWidth: 80
minHeight: 24
theme: "catppuccin"
---

```nim on:init
# Canvas Editor - Visual Node Graph Editor
# 
# Controls:
# - Left mouse on empty: Pan the canvas
# - Shift + Left mouse on node: Select and drag nodes
# - Middle mouse: Alternative panning (desktop)
# - Left click on node: Select node
# - Long press (hold 500ms): Context menu (future)
# - Arrow keys: Navigate viewport
# - Shift+click: Multi-select nodes
# - Delete: Remove selected nodes
# - A: Select all nodes
# - Escape: Deselect all
# - Home: Reset camera to origin

# Create node editor
var editor = newNodeEditor(termWidth, termHeight)

# Create some sample nodes for demonstration
var node1 = newEditorNode()
setNodePosition(node1, 10, 5)
setNodeSize(node1, 25, 8)
editor.addNode(node1)

var node2 = newEditorNode()
setNodePosition(node2, 50, 5)
setNodeSize(node2, 25, 8)
editor.addNode(node2)

var node3 = newEditorNode()
setNodePosition(node3, 30, 20)
setNodeSize(node3, 25, 8)
editor.addNode(node3)

# Connect nodes to show dataflow
editor.connectNodes(node1, node3)
editor.connectNodes(node2, node3)

# Variables for context menu and long-press
var showContextMenu = false
var contextMenuX = 0
var contextMenuY = 0
var longPressStartTime = 0.0
var longPressActive = false
var longPressThreshold = 0.5  # 500ms
var lastMouseX = 0
var lastMouseY = 0
```

```nim on:input
# Handle keyboard and mouse input for node editor
# The editor's built-in handlers manage most interactions

if event.type == "key":
  # Use named key constants (much clearer than magic numbers!)
  var keyStr = ""
  
  if event.keyCode == KEY_UP:
    keyStr = "Up"
  elif event.keyCode == KEY_DOWN:
    keyStr = "Down"
  elif event.keyCode == KEY_LEFT:
    keyStr = "Left"
  elif event.keyCode == KEY_RIGHT:
    keyStr = "Right"
  elif event.keyCode == KEY_ESCAPE:
    keyStr = "Escape"
  elif event.keyCode == KEY_DELETE or event.keyCode == KEY_BACKSPACE:
    keyStr = "Delete"
  
  # Pass to editor's key handler
  if keyStr != "":
    var handled = editorHandleKeyPress(editor, keyStr)
    if handled:
      return true

elif event.type == "text":
  # Handle text input for letter keys
  if event.text == "a" or event.text == "A":
    var handled = editorHandleKeyPress(editor, event.text)
    if handled:
      return true

elif event.type == "mouse":
  # Hide context menu on any mouse press
  if event.action == "press":
    showContextMenu = false
  
  # Convert button string to int (1=left, 2=middle, 3=right)
  var buttonInt = 0
  if event.button == "left":
    buttonInt = 1
  elif event.button == "middle":
    buttonInt = 2
  elif event.button == "right":
    buttonInt = 3
  
  # Check for shift modifier
  var shiftPressed = false
  var i = 0
  while i < len(event.mods):
    if event.mods[i] == "shift":
      shiftPressed = true
    i = i + 1
  
  if event.action == "press":
    # Start long-press tracking
    longPressStartTime = getTime()
    longPressActive = true
    showContextMenu = false
    lastMouseX = event.x
    lastMouseY = event.y
    
    var handled = editorHandleMouseDown(editor, event.x, event.y, buttonInt, shiftPressed, getTotalTime())
    if handled:
      return true
  
  elif event.action == "release":
    # Cancel long-press tracking
    longPressActive = false
    
    var handled = editorHandleMouseUp(editor, event.x, event.y, buttonInt, getTotalTime())
    if handled:
      return true

elif event.type == "mouse_move":
  var handled = editorHandleMouseMove(editor, event.x, event.y)
  if handled:
    return true

return false
```

```nim on:render
clear()

# Render the nodes first
var nodes = editorRenderSimple(editor)
for i in 0..<len(nodes):
  var node = nodes[i]
  var x = node[0]
  var y = node[1]
  var w = node[2]
  var h = node[3]
  var selected = node[4]
  
  # Determine color based on selection
  var style = defaultStyle()
  if selected:
    style.fg = rgb(255, 255, 255)
    style.bg = rgb(50, 50, 150)
    style.bold = true
  else:
    style.fg = rgb(200, 200, 200)
    style.bg = rgb(40, 40, 40)
  
  # Draw box borders
  var topLine = "┌"
  var midFill = ""
  var botLine = "└"
  var dx = 1
  while dx < w - 1:
    topLine = topLine & "─"
    midFill = midFill & " "
    botLine = botLine & "─"
    dx = dx + 1
  topLine = topLine & "┐"
  botLine = botLine & "┘"
  
  draw(0, x, y, topLine, style)
  
  var dy = 1
  while dy < h - 1:
    draw(0, x, y + dy, "│" & midFill & "│", style)
    dy = dy + 1
  
  draw(0, x, y + h - 1, botLine, style)

# Draw context menu if active
if showContextMenu:
  var menuStyle = defaultStyle()
  menuStyle.fg = rgb(255, 255, 255)
  menuStyle.bg = rgb(60, 60, 60)
  
  var menuX = contextMenuX
  var menuY = contextMenuY
  
  draw(0, menuX, menuY, "┌────────────────┐", menuStyle)
  draw(0, menuX, menuY + 1, "│ Add Node       │", menuStyle)
  draw(0, menuX, menuY + 2, "│ Delete Node    │", menuStyle)
  draw(0, menuX, menuY + 3, "│ Properties...  │", menuStyle)
  draw(0, menuX, menuY + 4, "└────────────────┘", menuStyle)

# Draw help text
var helpStyle = defaultStyle()
helpStyle.fg = rgb(150, 150, 150)
helpStyle.dim = true

draw(0, 2, termHeight - 4, "Left mouse: Pan | Shift+Left on node: Drag | Long press: Context menu", helpStyle)
draw(0, 2, termHeight - 3, "Arrow keys: Navigate | A: Select all | Escape: Deselect | Delete: Remove", helpStyle)

# Show camera position
var infoStyle = defaultStyle()
infoStyle.fg = rgb(200, 200, 100)
var camX = getEditorCameraX(editor)
var camY = getEditorCameraY(editor)
var camInfo = "Camera: (" & str(int(camX)) & ", " & str(int(camY)) & ")"
draw(0, termWidth - len(camInfo) - 2, 1, camInfo, infoStyle)

# Show node count and selection
var nodeCount = getEditorNodeCount(editor)
var selectedCount = getEditorSelectedCount(editor)
var nodeInfo = "Nodes: " & str(nodeCount) & " | Selected: " & str(selectedCount)
draw(0, termWidth - len(nodeInfo) - 2, 2, nodeInfo, infoStyle)

# Show time for debugging
var fps = 60
if deltaTime > 0.0:
  fps = int(1.0 / deltaTime)
var timeInfo = "Time: " & str(int(getTime() * 1000)) & "ms | FPS: " & str(fps)
draw(0, 2, 1, timeInfo, infoStyle)
```

```nim on:update
# Update camera position using real deltaTime (frame-independent!)
editorUpdateCamera(editor, deltaTime)

# Check for long-press (if mouse is still held down)
if longPressActive:
  var currentTime = getTime()
  if currentTime - longPressStartTime >= longPressThreshold:
    # Long press threshold reached!
    showContextMenu = true
    contextMenuX = lastMouseX
    contextMenuY = lastMouseY
    longPressActive = false  # Prevent retriggering
```

# 🎨 Canvas Editor - Visual Node Graph System

Welcome to the **Canvas Editor** - a generic visual node editor framework for TStorie!

This editor provides an intuitive way to create, connect, and manipulate nodes in a spatial graph.

## ✨ Features

### Edit-Focused Design

The canvas editor is designed from the ground up for **efficient editing**:

- **Middle mouse button** for instant canvas panning
- **Arrow keys** override canvas.nim defaults for viewport navigation
- **Smooth camera** interpolation for fluid movement
- **Multi-select** with Shift+click for batch operations

### Node Operations

- ✅ **Create nodes** programmatically (interactive creation coming soon)
- ✅ **Select nodes** with left mouse click
- ✅ **Drag nodes** to reposition them
- ✅ **Multi-select** with Shift+click
- ✅ **Delete nodes** with Delete or Backspace key
- ✅ **Connect nodes** to show dataflow relationships

### Navigation

- **Arrow keys**: Pan viewport (10 cells per press by default)
- **Middle mouse drag**: Smooth panning
- **Home key**: Reset camera to origin (0, 0)
- **Smooth interpolation**: Camera moves fluidly to targets

## 🎯 Use Cases

### Markdown Section Editing

The immediate use case is **spatial markdown editing**:

```nim
# Load markdown sections as visual nodes
var sections = getSections()
editor.loadMarkdownSections(sections)

# Users can then:
# - Rearrange sections spatially
# - See connections between linked sections
# - Edit section content in-place
```

### Dataflow Graph Editing (Future)

The same editor will support **visual graph programming**:

```nim
# Load graph.nim nodes as visual nodes
var graph = newGraph()
editor.loadGraph(graph)

# Users can then:
# - Create processing nodes visually
# - Connect nodes to define dataflow
# - See data flowing through the graph
# - Export back to graph.nim structures
```

### More Possibilities

- **Audio graphs** - Visual Web Audio-style node editing
- **Shader graphs** - Material/effect composition
- **Procedural generation** - Visual workflow building
- **State machines** - Visual behavior design

## 🏗️ Architecture

### Generic Core

The editor uses **polymorphic nodes**:

```nim
type
  EditorNode* = ref object of RootObj
    id*, x*, y*: int
    width*, height*: int
    selected*, hovered*: bool
```

Specialized nodes inherit from this base:

```nim
type
  MarkdownSectionNode* = ref object of EditorNode
    section*: Section
    contentLines*: seq[string]
  
  GraphProcessNode* = ref object of EditorNode
    graphNode*: Node
    nodeKind*: NodeKind
```

### Viewport System

Reuses proven patterns from `canvas.nim`:

- Camera with smooth interpolation
- World ↔ Screen coordinate conversion
- Viewport clipping for performance

### Connection Rendering

ASCII art connections with right-angle routing:

```
Node 1 ───┐
          │
          └─→ Node 3
          ┌─↗
Node 2 ───┘
```

## 🚀 Implementation Status

✅ **Phase 1: Core Editor** (Complete)
- Viewport navigation and camera
- Node selection and dragging
- Connection rendering
- Multi-select support

🚧 **Phase 2: Node Editing** (In Progress)
- Create/delete nodes interactively
- Property panels for editing
- Undo/redo system

📋 **Phase 3: Markdown Specialization** (Planned)
- Edit section content
- Preview rendering
- Save back to markdown

📋 **Phase 4: Graph Specialization** (Planned)
- Visual dataflow editing
- Connection type checking
- Export to graph.nim

## 🎓 Technical Details

### Coordinate Systems

- **World space**: Infinite 2D grid (terminal cells)
- **Screen space**: Visible viewport (0 to termWidth/Height)
- **Conversion**: `screenToWorld()` and `worldToScreen()`

### Mouse Button Handling

```nim
type MouseButton = enum
  mbNone, mbLeft, mbMiddle, mbRight

# Left: Select and drag nodes
# Middle: Pan canvas (edit-focused!)
# Right: Reserved for context menus
```

### Drag States

```nim
type DragState = enum
  dsNone
  dsDraggingNode
  dsDraggingConnection
  dsPanningMiddleMouse
```

### Keyboard Overrides

The editor **overrides canvas.nim key handling** for arrow keys:

```nim
proc handleKeyPress*(editor: NodeEditor, key: string): bool =
  case key
  of "Up", "ArrowUp":
    editor.panCamera(0, -editor.arrowKeyPanSpeed)
    return true  # Prevents canvas.nim from handling
  # ... etc
```

## 💡 Design Philosophy

### 90% Code Reuse

The same editor core works for:
- Markdown sections
- Dataflow graphs  
- Audio nodes
- Shader graphs
- Anything spatial!

### Consistent UX

Same interactions across all node types:
- Pan with middle mouse
- Select with left mouse
- Navigate with arrows
- Connect by dragging

### Progressive Enhancement

Start simple, add features incrementally:
1. Basic nodes and connections ✅
2. Interactive creation 🚧
3. Specialized rendering 📋
4. Domain-specific features 📋

## 🔧 Try It Yourself!

This demo shows the basic editor in action. Try:

1. **Left-click nodes** to select them
2. **Drag selected nodes** around
3. **Middle-mouse drag** to pan the canvas
4. **Press arrow keys** to navigate
5. **Press Home** to return to origin

The editor is fully functional and ready for integration!

---

*For implementation details, see `/lib/canvased.nim` and `CANVAS_EDITOR.md`*
