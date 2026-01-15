## Visual Node Editor Framework
## Generic spatial node editor for markdown sections, dataflow graphs, etc.
##
## Edit-focused design:
## - Middle mouse button: Pan canvas
## - Arrow keys: Navigate viewport
## - Left mouse: Select and drag nodes
## - Shift+click: Multi-select

import std/[tables, sequtils, math, sets]
import canvas      # Reuse Camera, viewport navigation
import graph       # For future Graph node editing
import section_manager  # For markdown sections
import tui_helpers # For drawing boxes, connections
import ../src/types
import ../src/layers

# Import nimini for binding registration
when not declared(exportNiminiProcs):
  import ../nimini

import ../nimini/auto_pointer  # For auto-pointer support

# ================================================================
# CORE TYPES
# ================================================================

type
  DragState = enum
    dsNone
    dsDraggingNode
    dsDraggingConnection
    dsPanningMiddleMouse     # Middle mouse panning
  
  MouseButton = enum
    mbNone
    mbLeft
    mbMiddle
    mbRight
  
  EditorNode* = ref object of RootObj
    ## Base node type - polymorphic for different editor types
    id*: int
    x*, y*: int              # World space position (terminal cells)
    width*, height*: int     # Visual size
    selected*: bool
    hovered*: bool
    # Subclasses add specific data via inheritance
  
  EditorConnection* = ref object
    ## Connection between two nodes
    id*: int
    source*, dest*: EditorNode
    sourcePort*: int         # Port index on source (0 = default)
    destPort*: int           # Port index on dest (0 = default)
    selected*: bool
  
  NodeEditor* = ref object
    ## The node editor - manages nodes, connections, viewport
    nodes*: seq[EditorNode]
    connections*: seq[EditorConnection]
    
    # Viewport (reuse Canvas system)
    camera*: Camera          # From canvas.nim
    viewportWidth*, viewportHeight*: int
    
    # Selection/interaction
    selectedNodes*: seq[EditorNode]
    selectedConnections*: seq[EditorConnection]
    hoveredNode*: EditorNode
    
    # Drag state
    dragState*: DragState
    dragStartX*, dragStartY*: int       # Mouse position when drag started
    dragNodeStartX*, dragNodeStartY*: int  # Node position when drag started
    dragSourceNode*: EditorNode         # For creating connections
    dragCameraStartX*, dragCameraStartY*: float  # Camera position when pan started
    
    # ID generation
    nextNodeId*, nextConnectionId*: int
    
    # Input state
    mouseX*, mouseY*: int    # Current mouse position (screen space)
    activeMouseButton*: MouseButton
    shiftPressed*: bool
    
    # Keyboard navigation speed
    arrowKeyPanSpeed*: float  # Cells per arrow key press

# Set up auto-pointer system for NodeEditor
# Note: Manual pointer table approach used (like graph.nim)
# autoPointer(NodeEditor)
# autoPointer(EditorNode)

# Global pointer tables for nimini bindings
var gEditorPtrTable {.global.} = initTable[int, pointer]()
var gEditorNextId {.global.} = 1
var gNodePtrTable {.global.} = initTable[int, pointer]()
var gNodeNextId {.global.} = 1

# ================================================================
# SPECIALIZED NODE TYPES
# ================================================================

type
  # For Markdown section editing
  MarkdownSectionNode* = ref object of EditorNode
    section*: Section       # From section_manager
    contentLines*: seq[string]  # Actual markdown content
  
  # For Graph dataflow editing (future)
  GraphProcessNode* = ref object of EditorNode
    graphNode*: Node        # From graph.nim
    nodeKind*: NodeKind
    inputs*: seq[tuple[label: string, connected: bool]]
    outputs*: seq[tuple[label: string, connected: bool]]

# ================================================================
# CONSTRUCTOR
# ================================================================

proc newNodeEditor*(viewportWidth, viewportHeight: int): NodeEditor =
  ## Create a new node editor
  result = NodeEditor(
    nodes: @[],
    connections: @[],
    camera: Camera(x: 0.0, y: 0.0, targetX: 0.0, targetY: 0.0),
    viewportWidth: viewportWidth,
    viewportHeight: viewportHeight,
    selectedNodes: @[],
    selectedConnections: @[],
    dragState: dsNone,
    nextNodeId: 0,
    nextConnectionId: 0,
    activeMouseButton: mbNone,
    arrowKeyPanSpeed: 5.0  # Default: 5 cells per arrow key press
  )

# ================================================================
# NODE MANAGEMENT
# ================================================================

proc addNode*(editor: NodeEditor, node: EditorNode) =
  ## Add a node to the editor
  node.id = editor.nextNodeId
  inc editor.nextNodeId
  editor.nodes.add(node)

proc removeNode*(editor: NodeEditor, node: EditorNode) =
  ## Remove a node and all its connections
  # Remove connections
  editor.connections.keepItIf(it.source != node and it.dest != node)
  # Remove from selection
  editor.selectedNodes.keepItIf(it != node)
  # Remove node
  editor.nodes.keepItIf(it != node)

proc findNodeAt*(editor: NodeEditor, worldX, worldY: int): EditorNode =
  ## Find node at world coordinates (for mouse picking)
  # Check in reverse order (top node first)
  for i in countdown(editor.nodes.len - 1, 0):
    let node = editor.nodes[i]
    if worldX >= node.x and worldX < node.x + node.width and
       worldY >= node.y and worldY < node.y + node.height:
      return node
  return nil

# ================================================================
# CONNECTION MANAGEMENT
# ================================================================

proc connectNodes*(editor: NodeEditor, source, dest: EditorNode, 
                   sourcePort: int = 0, destPort: int = 0) =
  ## Connect two nodes
  let conn = EditorConnection(
    id: editor.nextConnectionId,
    source: source,
    dest: dest,
    sourcePort: sourcePort,
    destPort: destPort
  )
  inc editor.nextConnectionId
  editor.connections.add(conn)

proc disconnectNodes*(editor: NodeEditor, source, dest: EditorNode) =
  ## Disconnect two nodes
  editor.connections.keepItIf(not (it.source == source and it.dest == dest))

proc findConnectionsFrom*(editor: NodeEditor, node: EditorNode): seq[EditorConnection] =
  ## Find all connections originating from a node
  result = editor.connections.filterIt(it.source == node)

proc findConnectionsTo*(editor: NodeEditor, node: EditorNode): seq[EditorConnection] =
  ## Find all connections ending at a node
  result = editor.connections.filterIt(it.dest == node)

# ================================================================
# COORDINATE CONVERSION
# ================================================================

proc screenToWorld*(editor: NodeEditor, screenX, screenY: int): tuple[x, y: int] =
  ## Convert screen coordinates to world coordinates
  result.x = screenX + int(editor.camera.x)
  result.y = screenY + int(editor.camera.y)

proc worldToScreen*(editor: NodeEditor, worldX, worldY: int): tuple[x, y: int] =
  ## Convert world coordinates to screen coordinates
  result.x = worldX - int(editor.camera.x)
  result.y = worldY - int(editor.camera.y)

# ================================================================
# VIEWPORT/CAMERA (reuse canvas.nim patterns)
# ================================================================

proc panCamera*(editor: NodeEditor, dx, dy: float) =
  ## Pan the camera by delta (immediate)
  editor.camera.targetX += dx
  editor.camera.targetY += dy

proc setCameraTarget*(editor: NodeEditor, x, y: float) =
  ## Set camera target position (will smooth interpolate)
  editor.camera.targetX = x
  editor.camera.targetY = y

proc updateCamera*(editor: NodeEditor, deltaTime: float) =
  ## Smooth camera interpolation (from canvas.nim)
  const SMOOTH_SPEED = 8.0
  let t = min(1.0, SMOOTH_SPEED * deltaTime)
  editor.camera.x = editor.camera.x + (editor.camera.targetX - editor.camera.x) * t
  editor.camera.y = editor.camera.y + (editor.camera.targetY - editor.camera.y) * t

proc centerOnNode*(editor: NodeEditor, node: EditorNode) =
  ## Center camera on a specific node
  editor.setCameraTarget(
    float(node.x + node.width div 2 - editor.viewportWidth div 2),
    float(node.y + node.height div 2 - editor.viewportHeight div 2)
  )

# ================================================================
# SELECTION
# ================================================================

proc selectNode*(editor: NodeEditor, node: EditorNode, addToSelection: bool = false) =
  ## Select a node
  if not addToSelection:
    for n in editor.selectedNodes:
      n.selected = false
    editor.selectedNodes.setLen(0)
  
  node.selected = true
  if node notin editor.selectedNodes:
    editor.selectedNodes.add(node)

proc deselectAll*(editor: NodeEditor) =
  ## Clear all selections
  for node in editor.selectedNodes:
    node.selected = false
  editor.selectedNodes.setLen(0)
  
  for conn in editor.selectedConnections:
    conn.selected = false
  editor.selectedConnections.setLen(0)

# ================================================================
# INPUT HANDLING
# ================================================================

proc handleMouseDown*(editor: NodeEditor, screenX, screenY: int, 
                     button: MouseButton, shift: bool): bool =
  ## Handle mouse down event. Returns true if handled.
  editor.activeMouseButton = button
  editor.mouseX = screenX
  editor.mouseY = screenY
  editor.shiftPressed = shift
  
  case button
  of mbLeft:
    # Left mouse: Select and drag nodes
    let (worldX, worldY) = editor.screenToWorld(screenX, screenY)
    let hitNode = editor.findNodeAt(worldX, worldY)
    
    if hitNode != nil:
      # Clicked on a node
      editor.selectNode(hitNode, addToSelection = shift)
      editor.dragState = dsDraggingNode
      editor.dragStartX = screenX
      editor.dragStartY = screenY
      editor.dragNodeStartX = hitNode.x
      editor.dragNodeStartY = hitNode.y
      return true
    else:
      # Clicked on empty space - clear selection
      if not shift:
        editor.deselectAll()
      return true
  
  of mbMiddle:
    # Middle mouse: Pan canvas
    editor.dragState = dsPanningMiddleMouse
    editor.dragStartX = screenX
    editor.dragStartY = screenY
    editor.dragCameraStartX = editor.camera.targetX
    editor.dragCameraStartY = editor.camera.targetY
    return true
  
  of mbRight:
    # Right mouse: Reserved for context menu (future)
    return true
  
  else:
    return false

proc handleMouseMove*(editor: NodeEditor, screenX, screenY: int): bool =
  ## Handle mouse move event. Returns true if handled.
  let oldMouseX = editor.mouseX
  let oldMouseY = editor.mouseY
  editor.mouseX = screenX
  editor.mouseY = screenY
  
  if editor.activeMouseButton != mbNone:
    let dx = screenX - oldMouseX
    let dy = screenY - oldMouseY
    
    case editor.dragState
    of dsDraggingNode:
      # Move selected nodes
      for node in editor.selectedNodes:
        node.x += dx
        node.y += dy
      return true
    
    of dsPanningMiddleMouse:
      # Pan camera (middle mouse drag)
      # Note: We use dragStart to calculate total delta from initial position
      let totalDx = screenX - editor.dragStartX
      let totalDy = screenY - editor.dragStartY
      editor.camera.targetX = editor.dragCameraStartX - float(totalDx)
      editor.camera.targetY = editor.dragCameraStartY - float(totalDy)
      # For immediate feel, also update current position
      editor.camera.x = editor.camera.targetX
      editor.camera.y = editor.camera.targetY
      return true
    
    else:
      discard
  else:
    # Update hover state
    let (worldX, worldY) = editor.screenToWorld(screenX, screenY)
    let hitNode = editor.findNodeAt(worldX, worldY)
    
    if editor.hoveredNode != hitNode:
      if editor.hoveredNode != nil:
        editor.hoveredNode.hovered = false
      editor.hoveredNode = hitNode
      if editor.hoveredNode != nil:
        editor.hoveredNode.hovered = true
  
  return false

proc handleMouseUp*(editor: NodeEditor, screenX, screenY: int, button: MouseButton): bool =
  ## Handle mouse up event. Returns true if handled.
  if button == editor.activeMouseButton:
    editor.activeMouseButton = mbNone
    let wasHandled = editor.dragState != dsNone
    editor.dragState = dsNone
    return wasHandled
  return false

proc handleKeyPress*(editor: NodeEditor, key: string): bool =
  ## Handle keyboard input. Returns true if handled.
  ## Arrow keys move the viewport, overriding canvas.nim defaults.
  case key
  of "Delete", "Backspace":
    # Delete selected nodes
    for node in editor.selectedNodes:
      editor.removeNode(node)
    editor.selectedNodes.setLen(0)
    return true
  
  of "a", "A":
    # Select all nodes
    editor.selectedNodes.setLen(0)
    for node in editor.nodes:
      node.selected = true
      editor.selectedNodes.add(node)
    return true
  
  # Arrow keys: Pan viewport (override canvas.nim defaults)
  of "Up", "ArrowUp":
    editor.panCamera(0, -editor.arrowKeyPanSpeed)
    return true
  
  of "Down", "ArrowDown":
    editor.panCamera(0, editor.arrowKeyPanSpeed)
    return true
  
  of "Left", "ArrowLeft":
    editor.panCamera(-editor.arrowKeyPanSpeed, 0)
    return true
  
  of "Right", "ArrowRight":
    editor.panCamera(editor.arrowKeyPanSpeed, 0)
    return true
  
  # Home: Reset to origin
  of "Home":
    editor.setCameraTarget(0, 0)
    return true
  
  # Escape: Deselect all
  of "Escape":
    editor.deselectAll()
    return true
  
  else:
    return false

# ================================================================
# RENDERING
# ================================================================

proc renderConnection*(editor: NodeEditor, conn: EditorConnection, 
                      buffer: var TermBuffer, layer: int) =
  ## Render a connection between two nodes (ASCII line art)
  let (srcScreenX, srcScreenY) = editor.worldToScreen(
    conn.source.x + conn.source.width, 
    conn.source.y + conn.source.height div 2
  )
  let (dstScreenX, dstScreenY) = editor.worldToScreen(
    conn.dest.x,
    conn.dest.y + conn.dest.height div 2
  )
  
  # Simple line drawing (can be enhanced with bezier curves)
  let style = if conn.selected: 
    Style(fg: rgb(255, 200, 0), bg: black())
  else:
    Style(fg: rgb(150, 150, 150), bg: black())
  
  # Use right-angle connections (more readable than diagonal)
  # Route: source → midpoint X → midpoint Y → dest
  let midX = (srcScreenX + dstScreenX) div 2
  
  # Horizontal line from source to midpoint
  let startX = min(srcScreenX, midX)
  let endX = max(srcScreenX, midX)
  if srcScreenY >= 0 and srcScreenY < editor.viewportHeight:
    for x in startX .. endX:
      if x >= 0 and x < editor.viewportWidth:
        buffer.writeText(x, srcScreenY, "─", style)
  
  # Vertical line at midpoint
  let startY = min(srcScreenY, dstScreenY)
  let endY = max(srcScreenY, dstScreenY)
  if midX >= 0 and midX < editor.viewportWidth:
    for y in startY .. endY:
      if y >= 0 and y < editor.viewportHeight:
        buffer.writeText(midX, y, "│", style)
  
  # Horizontal line from midpoint to dest
  let startX2 = min(midX, dstScreenX)
  let endX2 = max(midX, dstScreenX)
  if dstScreenY >= 0 and dstScreenY < editor.viewportHeight:
    for x in startX2 .. endX2:
      if x >= 0 and x < editor.viewportWidth:
        buffer.writeText(x, dstScreenY, "─", style)
  
  # Connection corners
  if midX >= 0 and midX < editor.viewportWidth:
    if srcScreenY >= 0 and srcScreenY < editor.viewportHeight:
      let corner = if dstScreenY > srcScreenY: "┐" else: "┘"
      buffer.writeText(midX, srcScreenY, corner, style)
    if dstScreenY >= 0 and dstScreenY < editor.viewportHeight:
      let corner = if dstScreenY > srcScreenY: "└" else: "┌"
      buffer.writeText(midX, dstScreenY, corner, style)

proc renderNode*(editor: NodeEditor, node: EditorNode, 
                buffer: var TermBuffer, layer: int) =
  ## Render a node (can be overridden for specialized nodes)
  let (screenX, screenY) = editor.worldToScreen(node.x, node.y)
  
  # Skip if off-screen
  if screenX + node.width < 0 or screenX >= editor.viewportWidth:
    return
  if screenY + node.height < 0 or screenY >= editor.viewportHeight:
    return
  
  # Determine style based on state
  var style = if node.selected:
    Style(fg: rgb(255, 255, 255), bg: rgb(50, 50, 150), bold: true)
  elif node.hovered:
    Style(fg: rgb(255, 255, 255), bg: rgb(80, 80, 80))
  else:
    Style(fg: rgb(200, 200, 200), bg: rgb(40, 40, 40))
  
  # Draw box using Unicode box drawing characters
  # Top border
  for dx in 0 ..< node.width:
    let x = screenX + dx
    if x >= 0 and x < editor.viewportWidth and screenY >= 0 and screenY < editor.viewportHeight:
      let ch = if dx == 0: "┌" elif dx == node.width-1: "┐" else: "─"
      buffer.writeText(x, screenY, ch, style)
  
  # Bottom border
  let by = screenY + node.height - 1
  for dx in 0 ..< node.width:
    let x = screenX + dx
    if x >= 0 and x < editor.viewportWidth and by >= 0 and by < editor.viewportHeight:
      let ch = if dx == 0: "└" elif dx == node.width-1: "┘" else: "─"
      buffer.writeText(x, by, ch, style)
  
  # Side borders and fill
  for dy in 1 ..< node.height - 1:
    let y = screenY + dy
    if y >= 0 and y < editor.viewportHeight:
      # Left border
      if screenX >= 0 and screenX < editor.viewportWidth:
        buffer.writeText(screenX, y, "│", style)
      # Right border
      let rx = screenX + node.width - 1
      if rx >= 0 and rx < editor.viewportWidth:
        buffer.writeText(rx, y, "│", style)
      # Fill interior with background color
      for dx in 1 ..< node.width - 1:
        let x = screenX + dx
        if x >= 0 and x < editor.viewportWidth:
          buffer.writeText(x, y, " ", style)
  
  # Label (center of box, truncated)
  let label = "Node " & $node.id
  let labelY = screenY + node.height div 2
  let labelX = screenX + max(1, (node.width - label.len) div 2)
  if labelY >= 0 and labelY < editor.viewportHeight and labelX >= 0:
    let availableWidth = min(node.width - 2, editor.viewportWidth - labelX)
    let displayLabel = if label.len > availableWidth:
      label[0 ..< availableWidth]
    else:
      label
    buffer.writeText(labelX, labelY, displayLabel, style)

proc render*(editor: NodeEditor, buffer: var TermBuffer, layer: int = 0) =
  ## Render the entire node editor
  # Update camera (smooth interpolation)
  editor.updateCamera(0.016)  # Assume 60fps for now
  
  # Render connections first (under nodes)
  for conn in editor.connections:
    editor.renderConnection(conn, buffer, layer)
  
  # Render nodes
  for node in editor.nodes:
    editor.renderNode(node, buffer, layer)

# ================================================================
# MARKDOWN SPECIALIZATION
# ================================================================

proc extractTextFromSection(section: Section): seq[string] =
  ## Extract text lines from a section's blocks
  result = @[]
  for blk in section.blocks:
    case blk.kind
    of TextBlock:
      result.add(blk.text)
    of HeadingBlock:
      result.add("#".repeat(blk.level) & " " & blk.title)
    of PreformattedBlock:
      result.add(blk.content)
    else:
      discard  # Skip code blocks and other content

proc newMarkdownSectionNode*(section: Section, x, y: int): MarkdownSectionNode =
  ## Create a markdown section node
  result = MarkdownSectionNode(
    section: section,
    x: x,
    y: y,
    width: 40,
    height: 15,
    contentLines: extractTextFromSection(section)
  )

proc renderMarkdownNode*(editor: NodeEditor, node: MarkdownSectionNode,
                        buffer: var TermBuffer, layer: int) =
  ## Render a markdown section node (specialized rendering)
  # First render base node
  editor.renderNode(node, buffer, layer)
  
  let (screenX, screenY) = editor.worldToScreen(node.x, node.y)
  
  # Skip if off-screen
  if screenX + node.width < 0 or screenX >= editor.viewportWidth:
    return
  if screenY + node.height < 0 or screenY >= editor.viewportHeight:
    return
  
  # Determine style
  var titleStyle = if node.selected:
    Style(fg: rgb(255, 255, 100), bg: rgb(50, 50, 150), bold: true)
  elif node.hovered:
    Style(fg: rgb(255, 255, 100), bg: rgb(80, 80, 80), bold: true)
  else:
    Style(fg: rgb(255, 255, 100), bg: rgb(40, 40, 40), bold: true)
  
  var contentStyle = if node.selected:
    Style(fg: rgb(220, 220, 220), bg: rgb(50, 50, 150))
  elif node.hovered:
    Style(fg: rgb(220, 220, 220), bg: rgb(80, 80, 80))
  else:
    Style(fg: rgb(180, 180, 180), bg: rgb(40, 40, 40))
  
  # Render title (line 1 inside box)
  let titleY = screenY + 1
  let titleX = screenX + 2
  if titleY >= 0 and titleY < editor.viewportHeight and titleX >= 0:
    let title = node.section.title
    let availableWidth = min(node.width - 4, editor.viewportWidth - titleX)
    let displayTitle = if title.len > availableWidth:
      title[0 ..< availableWidth]
    else:
      title
    buffer.writeText(titleX, titleY, displayTitle, titleStyle)
  
  # Render content preview (next few lines)
  let maxContentLines = min(node.height - 4, node.contentLines.len)
  for i in 0 ..< maxContentLines:
    let contentY = screenY + 3 + i
    let contentX = screenX + 2
    if contentY >= 0 and contentY < editor.viewportHeight and contentX >= 0:
      let line = node.contentLines[i]
      let availableWidth = min(node.width - 4, editor.viewportWidth - contentX)
      let displayLine = if line.len > availableWidth:
        line[0 ..< availableWidth]
      else:
        line
      buffer.writeText(contentX, contentY, displayLine, contentStyle)

proc loadMarkdownSections*(editor: NodeEditor, sections: seq[Section]) =
  ## Load markdown sections as nodes (spatial layout)
  const COL_WIDTH = 50
  const ROW_HEIGHT = 20
  
  for i, section in sections:
    let col = i mod 3
    let row = i div 3
    let node = newMarkdownSectionNode(
      section,
      x = col * COL_WIDTH,
      y = row * ROW_HEIGHT
    )
    editor.addNode(node)

# ================================================================
# GRAPH SPECIALIZATION (future)
# ================================================================

proc newGraphProcessNode*(graphNode: Node, x, y: int): GraphProcessNode =
  ## Create a graph processing node
  result = GraphProcessNode(
    graphNode: graphNode,
    nodeKind: graphNode.kind,
    x: x,
    y: y,
    width: 20,
    height: 8,
    inputs: @[],
    outputs: @[]
  )
  
  # Populate input/output ports based on node type
  case graphNode.kind
  of nkConstant:
    result.outputs.add(("value", false))
  of nkMath:
    result.inputs.add(("a", false))
    result.inputs.add(("b", false))
    result.outputs.add(("result", false))
  of nkOscillator:
    result.outputs.add(("audio", false))
  of nkWave:
    result.inputs.add(("in", false))
    result.outputs.add(("out", false))
  of nkColor:
    result.inputs.add(("value", false))
    result.outputs.add(("color", false))
  else:
    # Generic: single input and output
    result.inputs.add(("in", false))
    result.outputs.add(("out", false))

proc loadGraph*(editor: NodeEditor, graph: Graph) =
  ## Load a graph.nim graph as visual nodes (future)
  ## TODO: Convert graph nodes to editor nodes with proper layout
  ## This will use a force-directed or hierarchical layout algorithm
  discard

proc exportGraph*(editor: NodeEditor): Graph =
  ## Export editor nodes back to graph.nim Graph (future)
  ## TODO: Convert editor nodes back to graph structure
  result = newGraph()

# ================================================================
# NIMINI BINDINGS (scripting API)
# ================================================================

proc nimini_newNodeEditor*(env: ref Env; args: seq[Value]): Value {.nimini.} =
  ## Create a new node editor
  ## Usage: var editor = newNodeEditor(width, height)
  if args.len < 2:
    return valInt(0)
  
  let width = args[0].i
  let height = args[1].i
  let editor = newNodeEditor(width, height)
  
  # Store in pointer table and return ID
  let editorId = gEditorNextId
  inc gEditorNextId
  GC_ref(editor)
  gEditorPtrTable[editorId] = cast[pointer](editor)
  result = valInt(editorId)

proc nimini_addNode*(env: ref Env; args: seq[Value]): Value {.nimini.} =
  ## Add a node to the editor
  ## Usage: editor.addNode(node)
  if args.len < 2:
    return valNil()
  
  let editorId = args[0].i
  let nodeId = args[1].i
  
  if not gEditorPtrTable.hasKey(editorId) or not gNodePtrTable.hasKey(nodeId):
    return valNil()
  
  let editor = cast[NodeEditor](gEditorPtrTable[editorId])
  let node = cast[EditorNode](gNodePtrTable[nodeId])
  
  editor.addNode(node)
  result = valNil()

proc nimini_removeNode*(env: ref Env; args: seq[Value]): Value {.nimini.} =
  ## Remove a node from the editor
  ## Usage: editor.removeNode(node)
  if args.len < 2:
    return valNil()
  
  let editorId = args[0].i
  let nodeId = args[1].i
  
  if not gEditorPtrTable.hasKey(editorId) or not gNodePtrTable.hasKey(nodeId):
    return valNil()
  
  let editor = cast[NodeEditor](gEditorPtrTable[editorId])
  let node = cast[EditorNode](gNodePtrTable[nodeId])
  
  editor.removeNode(node)
  result = valNil()

proc nimini_connectNodes*(env: ref Env; args: seq[Value]): Value {.nimini.} =
  ## Connect two nodes
  ## Usage: editor.connectNodes(source, dest)
  if args.len < 3:
    return valNil()
  
  let editorId = args[0].i
  let sourceId = args[1].i
  let destId = args[2].i
  
  if not gEditorPtrTable.hasKey(editorId) or not gNodePtrTable.hasKey(sourceId) or not gNodePtrTable.hasKey(destId):
    return valNil()
  
  let editor = cast[NodeEditor](gEditorPtrTable[editorId])
  let source = cast[EditorNode](gNodePtrTable[sourceId])
  let dest = cast[EditorNode](gNodePtrTable[destId])
  
  editor.connectNodes(source, dest)
  result = valNil()

proc nimini_editorHandleMouseDown*(env: ref Env; args: seq[Value]): Value {.nimini.} =
  ## Handle mouse down event
  ## Usage: var handled = handleMouseDown(editor, x, y, button, shift)
  if args.len < 5:
    return valBool(false)
  
  let editorId = args[0].i
  let x = args[1].i
  let y = args[2].i
  let buttonInt = args[3].i
  let shift = args[4].b
  
  if not gEditorPtrTable.hasKey(editorId):
    return valBool(false)
  
  let editor = cast[NodeEditor](gEditorPtrTable[editorId])
  
  # Convert button int to MouseButton
  var button = mbNone
  case buttonInt
  of 1: button = mbLeft
  of 2: button = mbMiddle
  of 3: button = mbRight
  else: button = mbNone
  
  let handled = editor.handleMouseDown(x, y, button, shift)
  result = valBool(handled)

proc nimini_editorHandleMouseMove*(env: ref Env; args: seq[Value]): Value {.nimini.} =
  ## Handle mouse move event
  ## Usage: var handled = handleMouseMove(editor, x, y)
  if args.len < 3:
    return valBool(false)
  
  let editorId = args[0].i
  let x = args[1].i
  let y = args[2].i
  
  if not gEditorPtrTable.hasKey(editorId):
    return valBool(false)
  
  let editor = cast[NodeEditor](gEditorPtrTable[editorId])
  let handled = editor.handleMouseMove(x, y)
  result = valBool(handled)

proc nimini_editorHandleMouseUp*(env: ref Env; args: seq[Value]): Value {.nimini.} =
  ## Handle mouse up event
  ## Usage: var handled = handleMouseUp(editor, x, y, button)
  if args.len < 4:
    return valBool(false)
  
  let editorId = args[0].i
  let x = args[1].i
  let y = args[2].i
  let buttonInt = args[3].i
  
  if not gEditorPtrTable.hasKey(editorId):
    return valBool(false)
  
  let editor = cast[NodeEditor](gEditorPtrTable[editorId])
  
  # Convert button int to MouseButton
  var button = mbNone
  case buttonInt
  of 1: button = mbLeft
  of 2: button = mbMiddle
  of 3: button = mbRight
  else: button = mbNone
  
  let handled = editor.handleMouseUp(x, y, button)
  result = valBool(handled)

proc nimini_editorHandleKeyPress*(env: ref Env; args: seq[Value]): Value {.nimini.} =
  ## Handle key press event
  ## Usage: var handled = handleKeyPress(editor, key)
  if args.len < 2:
    return valBool(false)
  
  let editorId = args[0].i
  let key = args[1].s
  
  if not gEditorPtrTable.hasKey(editorId):
    return valBool(false)
  
  let editor = cast[NodeEditor](gEditorPtrTable[editorId])
  let handled = editor.handleKeyPress(key)
  result = valBool(handled)

proc nimini_editorRender*(env: ref Env; args: seq[Value]): Value {.nimini.} =
  ## Render the node editor
  ## Usage: editor.render(buffer, layer)
  # TODO: This needs proper buffer access from nimini
  result = valNil()

proc nimini_editorUpdateCamera*(env: ref Env; args: seq[Value]): Value {.nimini.} =
  ## Update camera smooth interpolation
  ## Usage: updateCamera(editor, deltaTime)
  if args.len < 2:
    return valNil()
  
  let editorId = args[0].i
  let deltaTime = args[1].f
  
  if not gEditorPtrTable.hasKey(editorId):
    return valNil()
  
  let editor = cast[NodeEditor](gEditorPtrTable[editorId])
  editor.updateCamera(deltaTime)
  result = valNil()

proc nimini_newEditorNode*(env: ref Env; args: seq[Value]): Value {.nimini.} =
  ## Create a new base editor node
  ## Usage: var node = newEditorNode()
  let node = EditorNode()
  
  # Store in pointer table and return ID
  let nodeId = gNodeNextId
  inc gNodeNextId
  GC_ref(node)
  gNodePtrTable[nodeId] = cast[pointer](node)
  result = valInt(nodeId)

proc nimini_setNodePosition*(env: ref Env; args: seq[Value]): Value {.nimini.} =
  ## Set node position
  ## Usage: setNodePosition(node, x, y)
  if args.len < 3:
    return valNil()
  
  let nodeId = args[0].i
  let x = args[1].i
  let y = args[2].i
  
  if not gNodePtrTable.hasKey(nodeId):
    return valNil()
  
  let node = cast[EditorNode](gNodePtrTable[nodeId])
  node.x = x
  node.y = y
  result = valNil()

proc nimini_setNodeSize*(env: ref Env; args: seq[Value]): Value {.nimini.} =
  ## Set node size
  ## Usage: setNodeSize(node, width, height)
  if args.len < 3:
    return valNil()
  
  let nodeId = args[0].i
  let width = args[1].i
  let height = args[2].i
  
  if not gNodePtrTable.hasKey(nodeId):
    return valNil()
  
  let node = cast[EditorNode](gNodePtrTable[nodeId])
  node.width = width
  node.height = height
  result = valNil()

proc nimini_getEditorNodeCount*(env: ref Env; args: seq[Value]): Value {.nimini.} =
  ## Get number of nodes in editor
  ## Usage: var count = getNodeCount(editor)
  if args.len < 1:
    return valInt(0)
  
  let editorId = args[0].i
  
  if not gEditorPtrTable.hasKey(editorId):
    return valInt(0)
  
  let editor = cast[NodeEditor](gEditorPtrTable[editorId])
  result = valInt(editor.nodes.len)

proc nimini_getEditorSelectedCount*(env: ref Env; args: seq[Value]): Value {.nimini.} =
  ## Get number of selected nodes
  ## Usage: var count = getSelectedCount(editor)
  if args.len < 1:
    return valInt(0)
  
  let editorId = args[0].i
  
  if not gEditorPtrTable.hasKey(editorId):
    return valInt(0)
  
  let editor = cast[NodeEditor](gEditorPtrTable[editorId])
  result = valInt(editor.selectedNodes.len)

proc nimini_getEditorCameraX*(env: ref Env; args: seq[Value]): Value {.nimini.} =
  ## Get camera X position
  ## Usage: var x = getCameraX(editor)
  if args.len < 1:
    return valFloat(0.0)
  
  let editorId = args[0].i
  
  if not gEditorPtrTable.hasKey(editorId):
    return valFloat(0.0)
  
  let editor = cast[NodeEditor](gEditorPtrTable[editorId])
  result = valFloat(editor.camera.x)

proc nimini_getEditorCameraY*(env: ref Env; args: seq[Value]): Value {.nimini.} =
  ## Get camera Y position
  ## Usage: var y = getCameraY(editor)
  if args.len < 1:
    return valFloat(0.0)
  
  let editorId = args[0].i
  
  if not gEditorPtrTable.hasKey(editorId):
    return valFloat(0.0)
  
  let editor = cast[NodeEditor](gEditorPtrTable[editorId])
  result = valFloat(editor.camera.y)

proc nimini_editorPanCamera*(env: ref Env; args: seq[Value]): Value {.nimini.} =
  ## Pan camera by delta
  ## Usage: panCamera(editor, dx, dy)
  if args.len < 3:
    return valNil()
  
  let editorId = args[0].i
  let dx = args[1].f
  let dy = args[2].f
  
  if not gEditorPtrTable.hasKey(editorId):
    return valNil()
  
  let editor = cast[NodeEditor](gEditorPtrTable[editorId])
  editor.panCamera(dx, dy)
  result = valNil()

proc nimini_editorDeselectAll*(env: ref Env; args: seq[Value]): Value {.nimini.} =
  ## Deselect all nodes
  ## Usage: deselectAll(editor)
  if args.len < 1:
    return valNil()
  
  let editorId = args[0].i
  
  if not gEditorPtrTable.hasKey(editorId):
    return valNil()
  
  let editor = cast[NodeEditor](gEditorPtrTable[editorId])
  editor.deselectAll()
  result = valNil()

proc nimini_editorRenderSimple*(env: ref Env; args: seq[Value]): Value {.nimini.} =
  ## Get node positions for rendering (to be called from nimini with draw())
  ## Returns array of node render info: [[x, y, width, height, selected], ...]
  ## Usage: var nodes = editorGetNodesForRender(editor)
  if args.len < 1:
    return valNil()
  
  let editorId = args[0].i
  
  if not gEditorPtrTable.hasKey(editorId):
    return valArray(@[])
  
  let editor = cast[NodeEditor](gEditorPtrTable[editorId])
  
  var nodeData = newSeq[Value]()
  for node in editor.nodes:
    let (screenX, screenY) = editor.worldToScreen(node.x, node.y)
    
    # Skip if completely off-screen
    if screenX + node.width < 0 or screenX >= editor.viewportWidth:
      continue
    if screenY + node.height < 0 or screenY >= editor.viewportHeight:
      continue
    
    # Create array: [x, y, width, height, selected]
    var info = newSeq[Value]()
    info.add(valInt(screenX))
    info.add(valInt(screenY))
    info.add(valInt(node.width))
    info.add(valInt(node.height))
    info.add(valBool(node.selected))
    nodeData.add(valArray(info))
  
  result = valArray(nodeData)

proc registerCanvasEditorBindings*() =
  ## Register canvas editor bindings with the nimini runtime
  ## Call this during initialization after creating the nimini context
  
  # Export all nimini wrapper functions with automatic prefix stripping
  # nimini_newNodeEditor becomes "newNodeEditor" in scripts, etc.
  exportNiminiProcsClean(
    nimini_newNodeEditor,
    nimini_addNode, nimini_removeNode, nimini_connectNodes,
    nimini_editorHandleMouseDown, nimini_editorHandleMouseMove,
    nimini_editorHandleMouseUp, nimini_editorHandleKeyPress,
    nimini_editorRender, nimini_editorUpdateCamera,
    nimini_newEditorNode, nimini_setNodePosition, nimini_setNodeSize,
    nimini_getEditorNodeCount, nimini_getEditorSelectedCount,
    nimini_getEditorCameraX, nimini_getEditorCameraY,
    nimini_editorPanCamera, nimini_editorDeselectAll,
    nimini_editorRenderSimple
  )

# ================================================================
# EXPORTS
# ================================================================

# Export main types
export EditorNode, EditorConnection, NodeEditor
export MarkdownSectionNode, GraphProcessNode
export DragState, MouseButton

# Export core functions
export newNodeEditor, addNode, removeNode, findNodeAt
export connectNodes, disconnectNodes
export screenToWorld, worldToScreen
export panCamera, setCameraTarget, updateCamera, centerOnNode
export selectNode, deselectAll
export handleMouseDown, handleMouseMove, handleMouseUp, handleKeyPress
export render, renderNode, renderConnection
export newMarkdownSectionNode, renderMarkdownNode, loadMarkdownSections
export newGraphProcessNode, loadGraph, exportGraph

# Export nimini registration
export registerCanvasEditorBindings
