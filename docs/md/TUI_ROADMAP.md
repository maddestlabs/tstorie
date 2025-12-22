# TUI Integration Roadmap

This document outlines how the transition system integrates with future TUI components.

## Architecture Overview

```
┌─────────────────────────────────────────┐
│     lib/transitions.nim (CORE)          │
│  ✓ Transition engine                    │
│  ✓ Effect library                       │
│  ✓ Event system                          │
│  ✓ Buffer interpolation                 │
└─────────────────────────────────────────┘
              ▲
              │
┌─────────────┴─────────────────────────┐
│  lib/transition_helpers.nim           │
│  ✓ Buffer capture helpers             │
│  ✓ Rendering helpers                   │
│  ✓ Convenience functions               │
└───────────────────────────────────────┘
              ▲
              │
┌─────────────┴─────────────────────────┐
│  lib/ui.nim (TODO - Phase 2)          │
│  - Widget base class                   │
│  - Button, Panel, Menu, etc.           │
│  - Built-in transition support         │
└───────────────────────────────────────┘
```

## Widget Base Class Design

```nim
type
  Widget* = ref object of RootObj
    x*, y*: int
    width*, height*: int
    visible*: bool
    transitionEnabled*: bool
    defaultTransition*: TransitionEffect
    
  Button* = ref object of Widget
    text*: string
    onClick*: proc()
    
  Panel* = ref object of Widget
    title*: string
    content*: seq[Widget]
```

## Transition-Aware Widget Methods

```nim
proc show*(widget: Widget, transEngine: TransitionEngine) =
  ## Show widget with transition
  if widget.transitionEnabled:
    let before = captureWidgetRegion(widget)
    widget.visible = true
    renderWidget(widget)
    let after = captureWidgetRegion(widget)
    
    let effect = regionalEffect(
      widget.defaultTransition,
      widget.x, widget.y, widget.width, widget.height
    )
    transEngine.startTransition(before, after, effect)
  else:
    widget.visible = true

proc hide*(widget: Widget, transEngine: TransitionEngine) =
  ## Hide widget with transition
  if widget.transitionEnabled:
    let before = captureWidgetRegion(widget)
    widget.visible = false
    clearWidgetRegion(widget)
    let after = captureWidgetRegion(widget)
    
    let effect = regionalEffect(
      widget.defaultTransition,
      widget.x, widget.y, widget.width, widget.height
    )
    transEngine.startTransition(before, after, effect)
  else:
    widget.visible = false
```

## Example: Transition-Aware Button

```nim
type
  TransitionButton* = ref object of Button
    hoverTransition*: TransitionEffect
    clickTransition*: TransitionEffect

proc onHover*(btn: TransitionButton, transEngine: TransitionEngine) =
  ## Animate button on hover
  let before = captureButtonState(btn)
  btn.style = btn.hoverStyle
  let after = captureButtonState(btn)
  
  let effect = regionalEffect(
    btn.hoverTransition,
    btn.x, btn.y, btn.width, btn.height
  )
  transEngine.startTransition(before, after, effect)

proc onClick*(btn: TransitionButton, transEngine: TransitionEngine) =
  ## Animate button on click
  let before = captureButtonState(btn)
  btn.style = btn.activeStyle
  let after = captureButtonState(btn)
  
  let effect = regionalEffect(
    btn.clickTransition,
    btn.x, btn.y, btn.width, btn.height
  )
  
  let trans = transEngine.startTransition(before, after, effect)
  
  # Return to normal after transition
  trans.registerCallback(teComplete) do (t: Transition, p: float):
    btn.style = btn.normalStyle
```

## Example: Sliding Panel

```nim
proc slideInPanel*(
  panel: Panel,
  transEngine: TransitionEngine,
  direction: TransitionDirection = tdRight
) =
  ## Slide panel into view
  panel.visible = true
  
  # Create offscreen starting position
  let offscreenX = case direction
    of tdRight: -panel.width
    of tdLeft: screenWidth
    else: panel.x
  
  let beforeBuf = createOffscreenBuffer(offscreenX, panel.y, panel.width, panel.height)
  renderPanelToBuffer(panel, beforeBuf)
  
  let afterBuf = createBuffer(panel.x, panel.y, panel.width, panel.height)
  renderPanelToBuffer(panel, afterBuf)
  
  transEngine.startTransition(
    beforeBuf,
    afterBuf,
    slideEffect(0.5, direction, easeOutCubic)
  )
```

## Example: Menu with Transitions

```nim
type
  Menu* = ref object of Widget
    items*: seq[MenuItem]
    selectedIdx*: int
    itemTransition*: TransitionEffect

proc selectItem*(
  menu: Menu,
  idx: int,
  transEngine: TransitionEngine
) =
  ## Select menu item with highlight transition
  if idx < 0 or idx >= menu.items.len:
    return
  
  # Capture old selection
  let oldItem = menu.items[menu.selectedIdx]
  let beforeOld = captureMenuItem(oldItem)
  
  # Capture new selection
  let newItem = menu.items[idx]
  let beforeNew = captureMenuItem(newItem)
  
  # Update selection
  menu.selectedIdx = idx
  oldItem.selected = false
  newItem.selected = true
  
  # Capture after states
  let afterOld = captureMenuItem(oldItem)
  let afterNew = captureMenuItem(newItem)
  
  # Transition both items
  transEngine.startTransition(beforeOld, afterOld, menu.itemTransition)
  transEngine.startTransition(beforeNew, afterNew, menu.itemTransition)
```

## Integration Points

### 1. Widget Lifecycle Hooks

```nim
method beforeRender*(widget: Widget, transEngine: TransitionEngine) {.base.} =
  ## Called before widget renders - capture state for transitions
  if widget.transitionEnabled:
    widget.beforeState = captureWidgetState(widget)

method afterRender*(widget: Widget, transEngine: TransitionEngine) {.base.} =
  ## Called after widget renders - apply transition if state changed
  if widget.transitionEnabled and widget.stateChanged():
    let afterState = captureWidgetState(widget)
    transEngine.startTransition(
      widget.beforeState,
      afterState,
      widget.defaultTransition
    )
```

### 2. Layout Manager Integration

```nim
type
  LayoutManager* = object
    widgets*: seq[Widget]
    transEngine*: TransitionEngine
    layoutTransition*: TransitionEffect

proc reflow*(layout: LayoutManager) =
  ## Reflow layout with transition
  let before = captureLayout(layout)
  
  # Recalculate positions
  calculateWidgetPositions(layout.widgets)
  
  let after = captureLayout(layout)
  
  layout.transEngine.startTransition(
    before,
    after,
    layout.layoutTransition
  )
```

### 3. Dialog/Modal Transitions

```nim
proc showModal*(
  dialog: Dialog,
  transEngine: TransitionEngine
) =
  ## Show modal with fade + scale effect
  
  # Darken background
  let beforeBg = captureScreen()
  applyOverlay(0.5)  # 50% dark overlay
  let afterBg = captureScreen()
  
  transEngine.startTransition(
    beforeBg,
    afterBg,
    fadeEffect(0.2)
  )
  
  # Slide in dialog
  let beforeDialog = createEmptyBuffer(dialog.region)
  renderDialog(dialog)
  let afterDialog = captureDialog(dialog)
  
  transEngine.startTransition(
    beforeDialog,
    afterDialog,
    regionalEffect(
      slideEffect(0.3, tdDown, easeOutCubic),
      dialog.x, dialog.y, dialog.width, dialog.height
    )
  )
```

## Metadata-Driven Transitions

Widgets can specify transitions via configuration:

```nim
let button = newButton(
  text = "Click Me",
  transition = {
    "hover": "fade:0.2",
    "click": "push:0.1:down",
    "show": "slide:0.4:right"
  }.toTable
)
```

## Performance Considerations

1. **Batch Transitions**: Multiple widget updates can share one transition
2. **Region Clipping**: Only transition visible portions
3. **Lazy Capture**: Only capture state when needed
4. **Transition Pooling**: Reuse transition objects

## Next Steps for TUI Development

1. **Define Widget Base Classes** (1-2 days)
   - Widget, Button, Panel, Label
   - Basic rendering and layout

2. **Add Transition Support** (1 day)
   - Integrate transition_helpers
   - Add lifecycle hooks
   - Test with transitions

3. **Build Common Widgets** (1 week)
   - Menu, ScrollArea, TextInput
   - Dialog, Modal, Tooltip
   - All with optional transitions

4. **Layout System** (2-3 days)
   - Flexbox-style layout
   - Grid layout
   - Transition-aware reflow

5. **Event System** (1-2 days)
   - Mouse/keyboard handling
   - Focus management
   - Event bubbling

## Benefits of Transition-First Design

By building TUI on top of the transition system:

- ✅ **Polished from day 1**: All widgets support smooth animations
- ✅ **Consistent UX**: Standard transition patterns across all components
- ✅ **Optional**: Can disable transitions for performance
- ✅ **Extensible**: Easy to add custom widget transitions
- ✅ **Professional**: Modern, smooth UI feel

## See Also

- [transitions.nim](../lib/transitions.nim) - Core transition system
- [transition_helpers.nim](../lib/transition_helpers.nim) - Integration helpers
- [TRANSITIONS.md](TRANSITIONS.md) - Full documentation
- [TRANSITIONS_QUICK_REF.md](TRANSITIONS_QUICK_REF.md) - Quick reference
