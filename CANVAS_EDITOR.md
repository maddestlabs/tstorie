# Canvas Editor Architecture

## Vision

Create `lib/canvased.nim` as a **generic visual node editor framework** that serves multiple use cases:
- Markdown section editing (immediate use case)
- Dataflow graph editing (graph.nim nodes)
- Future: Audio graphs, shader graphs, procgen workflows

## Core Insight

Both markdown sections and dataflow graphs are **spatial node editors**:

| Feature | Markdown Sections | Dataflow Graphs |
|---------|------------------|-----------------|
| Nodes | Sections | Processing nodes |
| Connections | Links/references | Data flow |
| Layout | Spatial positioning | Spatial positioning |
| Interaction | Pan/zoom/select/drag | Pan/zoom/select/drag |

## Architecture

### Generic Core (canvased.nim)

```nim
type
  EditorNode* = ref object of RootObj
    id*: int
    x*, y*: int          # Position in editor space
    width*, height*: int
    selected*: bool
    # Polymorphic - subclasses add specific data

  EditorConnection* = ref object
    id*: int
    source*, dest*: EditorNode
    # Optional: sourcePort, destPort for multi-input/output

  NodeEditor* = ref object
    nodes*: seq[EditorNode]
    connections*: seq[EditorConnection]
    # Viewport state (from canvas.nim)
    viewportX*, viewportY*: int
    zoom*: float
    # Selection/interaction
    selectedNodes*: seq[EditorNode]
    dragState*: DragState
```

### Specializations

```nim
# For Markdown editing
type
  MarkdownSectionNode* = ref object of EditorNode
    section*: Section  # from lib/canvas.nim
    markdownContent*: string

# For Graph editing  
type
  GraphProcessNode* = ref object of EditorNode
    graphNode*: Node   # from lib/graph.nim
    nodeKind*: NodeKind
```

## Implementation Phases

### Phase 1: Extract Canvas Navigation
- Take viewport/pan/zoom from `canvas.nim`
- Add node selection/dragging
- Basic rendering (boxes with labels)

### Phase 2: Node Editing
- Create/delete nodes
- Connect/disconnect nodes
- Property panels for node editing

### Phase 3: Markdown Specialization
- `MarkdownSectionNode` implementation
- Edit section content
- Preview rendering
- Save back to markdown file

### Phase 4: Graph Specialization
- `GraphProcessNode` implementation
- Visual dataflow editing
- Connection type checking (domain compatibility)
- Export to graph.nim structures

## Key Benefits

1. **Code Reuse**: 90% shared between markdown and graph editors
2. **Consistent UX**: Same interactions across all node types
3. **Literate Programming**: Document graphs IN markdown, edit visually
4. **Incremental**: Start with markdown, add graph later
5. **Extensible**: Audio nodes, shader nodes follow same pattern

## Integration with Existing Systems

### From canvas.nim (reuse)
- Viewport navigation (`navigateCanvas`, pan/zoom)
- Section positioning (adapt to generic nodes)
- Render loop integration

### With graph.nim (future)
- Visual editor → Graph structures
- Graph compiler integration
- Live evaluation preview

### With graph_compiler.nim (synergy)
- Compile markdown-defined graphs
- Visual editor saves to same format
- Documentation IS implementation

## Next Steps

1. Create `lib/canvased.nim` skeleton
2. Extract viewport/navigation from canvas.nim
3. Implement generic node dragging/selection
4. Add connection rendering (bezier curves?)
5. Build `MarkdownSectionNode` specialization
6. Create demo: `docs/demos/canvas_editor.md`

## API Sketch

```nim
# Core operations
proc newNodeEditor*(): NodeEditor
proc addNode*(editor: NodeEditor, node: EditorNode)
proc connectNodes*(editor: NodeEditor, source, dest: EditorNode)
proc render*(editor: NodeEditor, layer: Layer)
proc handleInput*(editor: NodeEditor, event: InputEvent): bool

# Markdown specialization
proc loadMarkdown*(editor: NodeEditor, doc: MarkdownDocument)
proc saveMarkdown*(editor: NodeEditor): string

# Graph specialization (future)
proc loadGraph*(editor: NodeEditor, graph: Graph)
proc exportGraph*(editor: NodeEditor): Graph
```

## Technical Notes

- Use canvas.nim's coordinate system (terminal cells)
- Connection rendering: ASCII art bezier-like curves or straight lines
- Multi-select with shift-click
- Drag-to-connect for creating connections
- Property panel: TUI widgets from tui_helpers.nim
- Undo/redo: Command pattern over node/connection operations

## Success Criteria

- ✅ Can visually edit markdown section layout
- ✅ Can create/delete/connect generic nodes
- ✅ Code shared between markdown and graph use cases
- ✅ Smooth 60fps interaction (native)
- ✅ Works in both terminal and WASM
