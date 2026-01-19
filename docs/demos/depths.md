---
title: "Depths Beckon"
author: "Maddest Labs"
theme: "coffee"
shaders: "ruledlines+sand+nightlight+gradualblur"
font: "Courier+Prime"
---

```nim on:init
# Canvas-based Interactive Fiction using Nimini
# The Depths of Khel-Daran - A dungeon adventure

# Track player state with simple variables
var hasTorch = false
var hasKey = false
var hasAmulet = false
var hasEssence = false
var hasWeapon = false
var visitedLibrary = false
var torchQuality = "dim"

# Bug effect tracking
var bugTimer = 0.0
var bugSpawnInterval = 3.0  # Spawn bugs every 3 seconds

# Initialize canvas system with all sections
# Start at section 1 (entrance - section 0 is the code blocks)
initCanvas(1)

# Initialize bug particle system
var bgStyle = getStyle("default")
var bgR = int(bgStyle.bg.r)
var bgG = int(bgStyle.bg.g)
var bgB = int(bgStyle.bg.b)
var fgR = int(bgStyle.fg.r)
var fgG = int(bgStyle.fg.g)
var fgB = int(bgStyle.fg.b)

particleInit("bugs", 50)
particleSetBackgroundColor("bugs", bgR, bgG, bgB)

# Configure base bug settings
particleSetEmitRate("bugs", 0.0)  # Manual emission only
particleSetChars("bugs", "o0@●")  # Bug head characters
particleSetColorRange("bugs", fgR, fgG, fgB, fgR, fgG, fgB)  # Use theme foreground color

# Enable trails for segmented body
particleSetTrailEnabled("bugs", true)
particleSetTrailLength("bugs", 4)  # 4-segment body
particleSetTrailSpacing("bugs", 0.8)  # Tight spacing
particleSetTrailFade("bugs", false)  # Solid body segments
particleSetTrailChars("bugs", "/\\.-|*")  # Random body segment chars

# Short lifetime - bugs disappear after crossing
particleSetLifeRange("bugs", 3.0, 5.0)

# Light turbulence for slight wobble
particleSetTurbulence("bugs", 3.0)
particleSetDamping("bugs", 0.98)

# Initialize bug splat particle system
particleInit("splat", 50)  # More particles for bigger splats
particleSetBackgroundColor("splat", bgR, bgG, bgB)
particleSetEmitRate("splat", 0.0)  # Manual only
particleSetChars("splat", "X*+#.:,`")  # Splat characters with debris
particleSetColorRange("splat", fgR, fgG, fgB, fgR, fgG, fgB)  # Same color as bugs
particleSetLifeRange("splat", 1.5, 2.5)  # Fade after 1.5-2.5 seconds
particleSetFadeOut("splat", true)  # Fade to nothing
particleSetVelocityRange("splat", -15.0, -15.0, 15.0, 15.0)  # Wider spread for debris
particleSetGravity("splat", 0.0)
particleSetDamping("splat", 0.75)  # Slow down quickly
```

```nim on:input
# Handle keyboard and mouse input for canvas navigation

if event.type == "key":
  if event.action == "press":
    # Pass key events to canvas system
    var handled = canvasHandleKey(event.keyCode, 0)
    if handled:
      return true
  return false

elif event.type == "mouse":
  if event.action == "press":
    # Check if we clicked on a bug!
    var hitBug = particleCheckHit("bugs", event.x, event.y, 2.0)
    if hitBug:
      # Spawn splat particles at click location
      particleSetEmitterPos("splat", float(event.x), float(event.y))
      particleEmit("splat", rand(10) + 12)  # 12-21 particles for bigger splat
  
  # Pass mouse release events to canvas system for link navigation
  if event.action == "release":
    var handled = canvasHandleMouse(event.x, event.y, event.button, false)
    if handled:
      return true
  
  return false

return false
```

```nim on:render
clear()
canvasRender()

# Render bugs behind text (layer 0 = behind canvas content)
particleRender("bugs", 0)

# Render splats on top of bugs but still behind text
particleRender("splat", 0)

# Top border with cracks
var x = 0
while x < termWidth:
  var char = "─"
  # Add random cracks and branches
  if x % 7 == 3:
    char = "╌"
  elif x % 11 == 5:
    char = "┬"
  elif x % 13 == 2:
    char = "╥"
  elif x % 17 == 8:
    char = "┴"
  draw(0, x, 0, char)
  x = x + 1

# Bottom border with cracks
x = 0
while x < termWidth:
  var char = "─"
  # Different crack pattern on bottom
  if x % 8 == 2:
    char = "╌"
  elif x % 12 == 7:
    char = "┴"
  elif x % 15 == 4:
    char = "╨"
  elif x % 19 == 11:
    char = "┬"
  draw(0, x, termHeight - 1, char)
  x = x + 1

# Left border with vertical cracks
var y = 1
while y < termHeight - 1:
  var char = "│"
  # Add cracks and branches
  if y % 6 == 2:
    char = "╎"
  elif y % 9 == 4:
    char = "├"
  elif y % 13 == 7:
    char = "╞"
  elif y % 16 == 10:
    char = "┤"
  draw(0, 0, y, char)
  y = y + 1

# Right border with vertical cracks
y = 1
while y < termHeight - 1:
  var char = "│"
  # Different crack pattern on right
  if y % 7 == 3:
    char = "╎"
  elif y % 10 == 5:
    char = "┤"
  elif y % 14 == 8:
    char = "╡"
  elif y % 17 == 11:
    char = "├"
  draw(0, termWidth - 1, y, char)
  y = y + 1

# Corner pieces - weathered and broken
draw(0, 0, 0, "╔")
draw(0, termWidth - 1, 0, "╗")
draw(0, 0, termHeight - 1, "╚")
draw(0, termWidth - 1, termHeight - 1, "╝")

# Add some additional crack details
# Top left area cracks
if termWidth > 10:
  draw(0, 5, 0, "┯")
  draw(0, 5, 1, "╽")
  
# Top right area cracks
if termWidth > 10:
  draw(0, termWidth - 6, 0, "┯")
  draw(0, termWidth - 6, 1, "╽")

# Bottom left area cracks
if termHeight > 5:
  draw(0, 4, termHeight - 1, "┷")
  draw(0, 4, termHeight - 2, "╿")

# Bottom right area cracks
if termWidth > 10 and termHeight > 5:
  draw(0, termWidth - 7, termHeight - 1, "┷")
  draw(0, termWidth - 7, termHeight - 2, "╿")
```

```nim on:update
canvasUpdate()

# Update bug particles
particleUpdate("bugs", deltaTime)

# Update splat particles
particleUpdate("splat", deltaTime)

# Bug spawning timer
bugTimer += deltaTime
if bugTimer >= bugSpawnInterval:
  bugTimer = 0.0
  
  # Randomly select which edge to spawn from (0=top, 1=right, 2=bottom, 3=left)
  var edge = rand(4)
  
  # Spawn position and velocity depend on edge
  # Random arc direction for variety
  var arcDir = float(rand(2) * 2 - 1)  # -1 or 1 (arc up or down)
  var gravityStrength = 12.0 + float(rand(10))  # 12-21 for varied arc curves
  
  if edge == 0:
    # Spawn from TOP edge, move downward with random arc
    var spawnX = float(rand(termWidth - 4) + 2)
    particleSetEmitterPos("bugs", spawnX, 1.0)
    # Move down and either left or right
    var horizontalDir = float(rand(3) - 1) * 40.0  # -40, 0, or 40
    particleSetVelocityRange("bugs", horizontalDir - 15.0, 80.0, horizontalDir + 15.0, 80.0)
    particleSetGravity("bugs", gravityStrength * arcDir)  # Random arc direction
    
  elif edge == 1:
    # Spawn from RIGHT edge, move leftward with random arc
    var spawnY = float(rand(termHeight - 4) + 2)
    particleSetEmitterPos("bugs", float(termWidth - 2), spawnY)
    particleSetVelocityRange("bugs", -80.0, -15.0, -80.0, 15.0)
    particleSetGravity("bugs", gravityStrength * arcDir)  # Random arc direction
    
  elif edge == 2:
    # Spawn from BOTTOM edge, move upward with random arc
    var spawnX = float(rand(termWidth - 4) + 2)
    particleSetEmitterPos("bugs", spawnX, float(termHeight - 2))
    var horizontalDir = float(rand(3) - 1) * 40.0
    particleSetVelocityRange("bugs", horizontalDir - 15.0, -80.0, horizontalDir + 15.0, -80.0)
    particleSetGravity("bugs", gravityStrength * arcDir)  # Random arc direction
    
  else:
    # Spawn from LEFT edge, move rightward with random arc
    var spawnY = float(rand(termHeight - 4) + 2)
    particleSetEmitterPos("bugs", 1.0, spawnY)
    particleSetVelocityRange("bugs", 80.0, -15.0, 80.0, 15.0)
    particleSetGravity("bugs", gravityStrength * arcDir)  # Random arc direction
  
  # Emit 1 bug at a time for individual randomization
  particleEmit("bugs", 1)
  
  # Vary spawn interval for natural randomness
  bugSpawnInterval = 2.0 + (float(rand(100)) / 80.0) * 2.5  # 2.0-4.5 seconds
```

# entrance
⠀
You stand before the ancient ruins of **Khel-Daran**, a fortress swallowed by time and shadow. The stone archway before you exhales cold, stale air. Moss clings to the weathered pillars, and somewhere deep within, you hear the faint echo of water dripping.
⠀
Your torch flickers in the darkness. The adventure begins here.
⠀
**What do you do?**
⠀
- [Enter the ruins](#hall-of-statues)  
- [Examine the entrance more carefully](#entrance-examine)  
- [Light a better torch](#prepare-torch)

# entrance_examine {"hidden": true, "removeAfterVisit": "true"}
⠀
You take a moment to inspect the entrance more carefully. Ancient runes are carved into the archway, worn smooth by centuries of wind and rain. You can barely make out what appears to be a warning:
⠀
*"Beware the guardian of the depths. Only the wise may pass."*
⠀
Beside the entrance, you notice an old iron sconce. It's empty, but appears functional.
⠀
- [Enter the ruins](#hall-of-statues)  
- [Take the sconce](#take-sconce)  
- [Go back](#entrance)

# prepare_torch {"hidden": true, "removeAfterVisit": "true"}
⠀
You take time to properly prepare your torch, wrapping it with oil-soaked cloth from your pack. The flame burns brighter now, casting long shadows across the ancient stone.
⠀
*You feel more confident with better light.*
⠀
- [Enter the ruins](#hall-of-statues)  
- [Return to the entrance](#entrance)

```nim on:enter
hasTorch = true
torchQuality = "bright"
```

# hall_of_statues {"hidden": true}
⠀
You step into a vast hall supported by crumbling pillars. **Three stone statues** stand guard, each depicting a different warrior from a forgotten age. Their hollow eyes seem to follow you as you move.
⠀
Passages branch off in three directions:
- To the **north**, you hear the sound of rushing water
- To the **east**, a faint blue glow emanates from the darkness  
- To the **west**, you smell something acrid and unpleasant
⠀
The main entrance lies behind you.
⠀
- [Go north toward the water](#underground-river)  
- [Go east toward the blue glow](#crystal-chamber)  
- [Go west toward the smell](#alchemist-lab)  
- [Examine the statues](#examine-statues)  
- [Return to entrance](#entrance)

# examine_statues {"hidden": true}
⠀
You approach the statues carefully. Each warrior is carved in exquisite detail:
⠀
The **first statue** holds a sword pointed downward, its face serene.  
The **second statue** clutches a shield, face twisted in rage.  
The **third statue** bears a broken chain, face sorrowful.
⠀
At the base of the third statue, you notice something glinting in the torchlight.
⠀
- [Take the glinting object](#find-key)  
- [Return to the hall](#hall-of-statues)

# find_key {"hidden": true, "removeAfterVisit": "true"}
⠀
You reach down and pick up a small, tarnished **brass key**. It's surprisingly heavy for its size, and covered in the same ancient runes you saw at the entrance.
⠀
*This might unlock something important.*
⠀
[Return to the hall](#hall-of-statues)

```nim on:enter
hasKey = true
```

# underground_river {"hidden": true}
⠀
The passage opens into a cavern split by a **rushing underground river**. The water is black as ink and moves with frightening speed. A narrow stone bridge crosses the chasm, but it looks ancient and unstable.
⠀
On the far side, you can see a doorway carved into the rock.
⠀
- [Cross the bridge carefully](#cross-bridge)  
- [Search for another way](#search-riverbank)  
- [Return to the hall](#hall-of-statues)

# cross_bridge {"hidden": true}
⠀
You step onto the stone bridge. It groans under your weight, and small chunks of stone crumble into the dark water below. Halfway across, you freeze as a loud **CRACK** echoes through the cavern.
⠀
But the bridge holds. Barely.
⠀
You make it to the other side, heart pounding.
⠀
- [Enter the carved doorway](#treasure-vault)  
- [Go back across (carefully)](#underground-river)

# search_riverbank {"hidden": true}
⠀
You search along the riverbank, looking for another way across. Behind a fallen column, you discover an old rope tied to an iron ring. Following it up, you see it leads to a natural rock shelf that crosses above the river.
⠀
A safer path, if you're willing to climb.
⠀
- [Take the high route](#treasure-vault)  
- [Just use the bridge](#cross-bridge)  
- [Go back](#underground-river)

# crystal_chamber {"hidden": true}
⠀
You follow the blue glow into a chamber filled with **luminescent crystals** growing from the walls and ceiling. They pulse with an eerie inner light, casting everything in shades of azure and violet.
⠀
In the center of the room stands a stone pedestal. Resting atop it is a beautiful **silver amulet**, set with a matching blue crystal.
⠀
The chamber has two other exits: one to the north and one continuing east.
⠀
- [Take the amulet](#take-amulet)  
- [Go north](#library)  
- [Continue east](#guardian-chamber)  
- [Return to the hall](#hall-of-statues)

# take_amulet {"hidden": true, "removeAfterVisit": "true"}
⠀
You reach for the amulet. The moment your fingers touch the cold silver, the crystals around you **flare brilliantly**. You feel a surge of warmth spread through your body.
⠀
*The amulet pulses with protective magic.*
⠀
- [Go north](#library)  
- [Continue east](#guardian-chamber)  
- [Return to crystal chamber](#crystal-chamber)

```nim on:enter
hasAmulet = true
```

# library {"hidden": true}
⠀
You enter what must have once been a library. Ancient books line rotting shelves, most crumbling to dust. In the center of the room, a single tome rests on a reading stand, somehow preserved.
⠀
You open the book. The pages are filled with riddles and wisdom of the ancients. One passage catches your eye:
⠀
*"The guardian seeks not strength, but humility. The warrior who bows is greater than one who strikes."*
⠀
- [Study more of the book](#library)  
- [Go south](#crystal-chamber)  
- [Go back to the hall](#hall-of-statues)

```nim on:enter
visitedLibrary = true
```

# alchemist_lab {"hidden": true}
⠀
The acrid smell leads you to an old laboratory. Broken glass and ceramic vessels litter the floor. Strange stains mark the walls. Whatever happened here, it wasn't pleasant.
⠀
Among the debris, you find a workbench with several intact bottles. One contains a glowing green liquid labeled *"Essence of Light"* in faded script.
⠀
- [Take the essence](#take-essence)  
- [Search the room more carefully](#search-lab)  
- [Return to the hall](#hall-of-statues)

# take_essence {"hidden": true, "removeAfterVisit": "true"}
⠀
You carefully pocket the glowing essence. It feels warm through the glass.
⠀
*This might prove useful.*
⠀
- [Search the room](#search-lab)  
- [Return to the hall](#hall-of-statues)

```nim on:enter
hasEssence = true
```

# search_lab {"hidden": true, "removeAfterVisit": "true"}
⠀
Searching more carefully, you find the alchemist's journal beneath some rubble. The final entry reads:
⠀
*"My experiments with the guardian have failed. It cannot be destroyed, only understood. I leave this place to whatever fate awaits. May those who follow be wiser than I."*
⠀
- [Return to the laboratory](#alchemist-lab)  
- [Go to the hall](#hall-of-statues)

# guardian_chamber {"hidden": true}
⠀
You enter a vast circular chamber. At its center stands a towering figure of **living stone**—the Guardian of Khel-Daran. Its eyes glow with ancient intelligence.
⠀
The Guardian speaks, its voice like grinding boulders:

*"Who dares disturb my eternal vigil? Prove your worth, or be destroyed!"*
⠀
Three pedestals surround the guardian, each marked with a symbol: **Sword**, **Shield**, and **Chains**.
⠀
- [Place an offering on the Sword pedestal](#guardian-fail)  
- [Place an offering on the Shield pedestal](#guardian-fail)  
- [Place an offering on the Chains pedestal](#guardian-success)  
- [Attack the guardian](#guardian-attack)  
- [Try to reason with the guardian](#guardian-reason)

# guardian_attack {"hidden": true}
⠀
You draw your weapon and charge at the stone guardian. It doesn't even move.

Your blade strikes the living stone and **shatters**. The guardian's fist comes down like a falling boulder. Everything goes dark.
⠀
*Perhaps violence wasn't the answer.*
⠀
- [Try again?](#guardian-chamber)

# guardian_reason {"hidden": true}
⠀
You lower your weapon and address the guardian with respect:

"I seek not to conquer, but to understand. I come in peace."
⠀
The guardian tilts its massive head, considering. Then it speaks:
⠀
*"Wisdom... rare among your kind. But words alone are insufficient. Show me you understand the truth of strength."*
⠀
- [Place something on a pedestal](#guardian-chamber)

# guardian_fail {"hidden": true}
⠀
You place your offering on the pedestal. The guardian's eyes flare **angry red**.

*"You understand nothing! Strength and defense are the tools of the proud. True power lies in freedom and sacrifice!"*

The chamber begins to shake violently.
⠀
- [Run back](#crystal-chamber)  
- [Try a different pedestal](#guardian-chamber)

# guardian_success {"hidden": true}
⠀
You approach the pedestal marked with broken chains and bow your head. The gesture of **humility and understanding** resonates through the chamber.
⠀
The guardian's eyes shift from threatening red to a calm **golden glow**.
⠀
*"You comprehend the ancient wisdom. Strength is nothing without the wisdom to bind it. You may pass."*
⠀
The guardian steps aside, revealing a passage to the **Treasure Vault**.
⠀
- [Enter the vault](#treasure-vault)

```nim on:enter
if visitedLibrary:
  draw(0, h-1, 0, w, 1, "Your knowledge from the library helped you understand!", "AlignCenter", "AlignTop", "WrapNone")
```

- [Enter the vault](#treasure-vault)

# treasure_vault {"hidden": true}
⠀
You enter the fabled treasure vault of Khel-Daran. Gold coins spill across the floor, gems glitter in the light of your torch, and ancient weapons line the walls.
⠀
But your eyes are drawn to the center of the room, where a magnificent **sword** rests on an altar, bathed in a beam of light from above. This is the legendary **Blade of Khel-Daran**, said to have defended these lands centuries ago.
⠀
The inscription on the altar reads:
*"To those who brave the depths with wisdom and courage, this is your reward."*
⠀
**Congratulations! You have completed the adventure!**
⠀
- [Take the sword and leave](#victory)  
- [Explore the vault more](#treasure-vault)  
- [Return to the guardian](#guardian-chamber)

# victory {"hidden": true}
⠀
You lift the Blade of Khel-Daran from its altar. The weapon feels perfectly balanced in your hand, and seems to **hum with ancient power**.
⠀
As you make your way back through the dungeon, you notice the guardian watching you with what might be... respect? The stone colossus bows its head slightly as you pass.
⠀
Emerging into the daylight, you shield your eyes against the sun. The ruins of Khel-Daran stand behind you, their secrets revealed.
⠀
**Your adventure is complete! You are victorious!**
⠀
*The legend of Khel-Daran will be told for generations.*
⠀
[Explore more endings?](#hall-of-statues)

# take_sconce {"hidden": true, "removeAfterVisit": "true"}
⠀
You remove the iron sconce from the wall. It's heavier than it looks and has a wicked pointed end. In a pinch, this could serve as a makeshift weapon.
⠀
*Might be useful in the dark.*
⠀
- [Continue to the ruins](#hall-of-statues)  
- [Go back](#entrance-examine)

```nim on:enter
hasWeapon = true
```
