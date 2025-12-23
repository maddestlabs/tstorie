---
title: "Canvas System Demo"
author: "TStorie Canvas Demo"
minWidth: 80
minHeight: 24
---

```nim global
# Simple Canvas Demo
# This demonstrates basic canvas navigation features

import lib/canvas
import lib/canvas_bridge

# Simple state tracking
type DemoState = ref object
  visited: int
  score: int

var demo = DemoState(visited: 0, score: 0)

proc visit() =
  demo.visited += 1
  demo.score += 10

echo "Canvas Demo Loaded!"
echo "Use arrows/tab to navigate, Enter to follow links"
```

# start {"hidden": false}

# Welcome to Canvas Demo

This is a simple demonstration of the TStorie Canvas Navigation System.

**Features:**
- Spatial section layout
- Interactive link navigation
- Hidden sections revealed by visiting
- Sections that disappear after use
- State tracking

**Where would you like to go?**

- [Explore the **hidden** room](hidden_room)
- [Visit the **temporary** event](temp_event)
- [Go to the **treasure** room](treasure)
- [Read about the system](info)

```nim on:enter
visit()
```

# hidden_room {"hidden": true}

## The Hidden Room

You've discovered a secret room! It was hidden until you visited it.

This demonstrates the `{"hidden": true}` metadata feature. Sections marked as hidden show "???" until visited.

**Great job exploring!**

- [Return to start](start)
- [Continue to treasure](treasure)

```nim on:enter
visit()
demo.score += 20
echo "Bonus points for finding the hidden room!"
```

# temp_event {"hidden": true, "removeAfterVisit": "true"}

## A Temporary Event

This is a **one-time event** that will disappear after you leave!

Notice the `{"removeAfterVisit": "true"}` metadata. When you navigate away, this section will be removed from the canvas, and links to it will automatically be filtered out.

This is perfect for:
- One-time story events
- Consumable items
- Temporary choices
- Tutorial messages

**Take note before you leave!**

- [Continue your journey](treasure)
- [Go back to start](start)

```nim on:enter
visit()
demo.score += 15
echo "This event will vanish when you leave..."
```

# treasure {"hidden": true}

## The Treasure Room

Congratulations! You found the treasure!

**Your Stats:**
- Sections visited: [You'd see the count here]
- Current score: [Score would display here]

This demonstrates state tracking across sections. In a real game, you could:
- Track inventory
- Manage health/stats
- Store quest progress
- Remember player choices

**Where next?**

- [Return to start](start)
- [Learn more about the system](info)

```nim on:enter
visit()
demo.score += 50
echo "Treasure found! Score: ", demo.score
```

# info {"hidden": false}

## About the Canvas System

The Canvas Navigation System for TStorie provides:

### **Spatial Navigation**
Sections are arranged in a 2D space with smooth camera movement.

### **Interactive Links**
- Click or press Enter to follow
- Tab to cycle through links
- Arrow keys to navigate
- Mouse hover for focus

### **Section States**
- **Hidden**: Shows "???" until visited
- **Removed**: Completely hidden after use
- **Normal**: Always visible

### **Smart Link Filtering**
Links to removed sections are automatically hidden, and list items containing only removed links disappear entirely.

### **Metadata Control**
Use JSON in headings:
```
# my_section {"hidden": true, "removeAfterVisit": true}
```

### **Lifecycle Hooks**
Nimini code blocks with `on:enter` and `on:exit` lifecycle hooks.

**Ready to explore more?**

- [Back to start](start)
- [Try the hidden room](hidden_room)
- [Check the treasure](treasure)

```nim on:enter
visit()
```
