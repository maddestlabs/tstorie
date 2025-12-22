# Canvas Interactive Fiction - Quick Start

## What is This?

A **spatial navigation system** for interactive fiction in TStorie, written in Nim using Nimini. Navigate between story sections on a 2D canvas with smooth camera movement, hidden rooms, one-time events, and rich interactivity.

## 30-Second Start

1. **Create a markdown file:**

```markdown
---
title: "My Story"
---

```nim global
import lib/canvas
import lib/canvas_bridge
```

# start
Welcome! Choose your path:
- [Go left](left_room)
- [Go right](right_room)

# left_room {"hidden": true}
You went left!
- [Back](start)

# right_room {"hidden": true}
You went right!
- [Back](start)
```

2. **Run it:**
```bash
tstorie my_story.md
```

## Features at a Glance

| Feature | Code | Result |
|---------|------|--------|
| **Hidden room** | `# room {"hidden": true}` | Shows "???" until visited |
| **One-time event** | `# event {"removeAfterVisit": "true"}` | Disappears after leaving |
| **Custom position** | `# room {"x": 100, "y": 50}` | Place anywhere on canvas |
| **Item pickup** | ```` ```nim on:enter`<br>`state.hasKey = true` ```` | Run code on enter |
| **State check** | `if state.hasKey: ...` | Conditional behavior |

## Navigation

- **Enter** = Follow link
- **Tab** = Cycle links
- **Arrows** = Navigate
- **Click** = Follow link
- **1-9** = Jump to section
- **Q** = Quit

## Examples

- 📚 [canvas_demo.md](examples/canvas_demo.md) - Simple demo
- 🏰 [depths_nim.md](depths_nim.md) - Full dungeon adventure

## Documentation

- 📖 [CANVAS_SYSTEM.md](CANVAS_SYSTEM.md) - Complete docs
- ⚡ [CANVAS_QUICK_REF.md](CANVAS_QUICK_REF.md) - Quick reference
- 🔧 [CANVAS_IMPLEMENTATION.md](CANVAS_IMPLEMENTATION.md) - Implementation details

## Common Patterns

### Hidden Discovery
```markdown
# secret {"hidden": true}
You found the secret!
```

### Consumable Item
```markdown
# potion {"removeAfterVisit": "true"}
You drink the health potion.

```nim on:enter
player.health += 50
```
```

### Locked Door
````markdown
```nim on:enter
if player.hasKey:
  removeSection("locked_door")
```
````

## Need Help?

- ❓ Check [CANVAS_QUICK_REF.md](CANVAS_QUICK_REF.md) for common tasks
- 📚 Read [CANVAS_SYSTEM.md](CANVAS_SYSTEM.md) for deep dive
- 🎮 Study [depths_nim.md](depths_nim.md) for a complete example

## What's Included

```
lib/
  canvas.nim          - Core logic
  canvas_bridge.nim   - Rendering
  canvas_api.nim      - Simple API

examples/
  canvas_demo.md      - Basic demo

depths_nim.md         - Full adventure
CANVAS_SYSTEM.md      - Full documentation
CANVAS_QUICK_REF.md   - Quick reference
```

## Next Steps

1. Try the demo: `tstorie examples/canvas_demo.md`
2. Play the adventure: `tstorie depths_nim.md`
3. Create your own story!

Happy storytelling! ✨
