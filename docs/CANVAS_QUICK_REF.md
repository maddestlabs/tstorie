# Canvas System Quick Reference

## Setup

```nim
# In your global code block:
import lib/canvas
import lib/canvas_bridge

# Your state type
type GameState = ref object
  # your fields

var state = GameState()
```

## Section Metadata

```markdown
# section_name {"hidden": true}
# one_time {"removeAfterVisit": "true"}
# custom_pos {"x": 100, "y": 50}
# multiple {"hidden": true, "removeAfterVisit": "true"}
```

## Lifecycle Hooks

````markdown
```nim on:enter
# Runs when entering section
state.hasKey = true
hideSection("locked_door")
```

```nim on:exit
# Runs when leaving section
removeSection("temporary")
```
````

## Canvas API

```nim
# Section visibility
hideSection("section_name")      # Hide (show as "???")
removeSection("section_name")    # Remove completely
restoreSection("section_name")   # Restore removed section

# State checks
isVisited("section_name")        # Returns bool
markVisited("section_name")      # Manually mark visited
isHidden("section_name")         # Returns bool
isRemoved("section_name")        # Returns bool

# Navigation (done via links in markdown)
# [Link text](target_section)
```

## Keyboard Controls

| Key | Action |
|-----|--------|
| **Enter** | Follow focused link |
| **Tab** | Cycle through links (forward) |
| **Shift+Tab** | Cycle through links (backward) |
| **↑ / ↓** | Navigate links |
| **1-9** | Jump to section by index |
| **Q** | Quit |

## Mouse Controls

| Action | Result |
|--------|--------|
| **Click** link | Navigate to target |
| **Hover** link | Focus link |

## Link Formatting

```markdown
Normal link: [Go north](north_room)
With emphasis: [Take the **sword**](armory)
With italic: [Read *ancient* text](library)
```

## Common Patterns

### Hidden Room

```markdown
# secret_room {"hidden": true}
You found the secret! This was hidden until visited.
- [Continue](next_room)
```

### One-Time Event

```markdown
# tutorial {"removeAfterVisit": "true"}
This will disappear after you leave.
- [Got it!](main_hall)
```

### Conditional Content

````markdown
```nim on:enter
if not state.hasTorch:
  hideSection("dark_passage")
```
````

### Item Collection

````markdown
# treasure_chest {"removeAfterVisit": "true"}
You found a **golden key**!
- [Take it](inventory)

```nim on:enter
state.hasGoldenKey = true
```
````

### Gate/Lock Mechanism

````markdown
```nim on:enter
if state.hasKey:
  removeSection("locked_door")
  hideSection("need_key_message")
```
````

## Configuration (lib/canvas.nim)

```nim
const
  SECTION_WIDTH = 60         # Section box width
  SECTION_HEIGHT = 20        # Section box height
  SECTION_PADDING = 10       # Gap between sections
  MAX_SECTIONS_PER_ROW = 3   # Grid columns
  PAN_SPEED = 5.0            # Camera speed
  SMOOTH_SPEED = 8.0         # Smoothing factor
```

## Troubleshooting

**Link not working?**
- Target section exists?
- Target not removed?
- Correct ID/title?

**Section not showing?**
- Check `hidden` metadata
- Verify not removed
- Check `removeAfterVisit`

**"???" displayed?**
- Section has `hidden: true`
- Visit it to reveal

## Tips

1. **Use meaningful IDs**: `treasure_room` not `room_17`
2. **Hide spoilers**: Use `hidden: true` for discoveries
3. **Clean up**: Use `removeAfterVisit` for one-time events
4. **Track state**: Use Nimini objects for game state
5. **Test navigation**: Verify all links work
6. **Avoid orphans**: Every section should be reachable

## Example State Object

```nim
type
  PlayerState = ref object
    # Stats
    health: int
    mana: int
    
    # Inventory
    hasKey: bool
    hasSword: bool
    hasTorch: bool
    
    # Progress
    defeatedBoss: bool
    foundTreasure: bool
    
    # Flags
    talkedToWizard: bool
    visitedLibrary: bool

var player = PlayerState(
  health: 100,
  mana: 50,
  hasKey: false,
  # ... defaults
)
```

## See Also

- [CANVAS_SYSTEM.md](../CANVAS_SYSTEM.md) - Full documentation
- [depths_nim.md](../depths_nim.md) - Complete example
- [canvas_demo.md](canvas_demo.md) - Simple demo
