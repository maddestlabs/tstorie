# Theme System Examples

This document demonstrates TStorie's theme system with multiple examples.

## Available Themes

TStorie includes several built-in themes:

- **catppuccin** - Soft, modern colors (excellent usability)
- **nord** - Cool, Arctic-inspired palette
- **dracula** - Vibrant, developer favorite
- **miami-vice** - Bold 80s cyberpunk (hot pink & cyan)
- **outrun** - Neon synthwave aesthetic
- **cyberpunk** - Classic duotone (cyan & magenta)
- **terminal** - Classic green terminal
- **solarized-dark** - The classic Solarized

## Usage Examples

### Example 1: Simple Theme Application

```markdown
---
theme: "catppuccin"
title: "My Document"
---

# Hello World

This document uses the Catppuccin theme!
All headings, links, and text will use the theme's colors automatically.
```

### Example 2: Theme with Overrides

```markdown
---
theme: "nord"
styles.heading.fg: "#FF0080"
---

# This heading is hot pink!

The theme provides defaults, but you can override any specific style.
Other elements still use Nord's beautiful color palette.
```

### Example 3: Comprehensive Theme Usage

```markdown
---
theme: "miami-vice"
title: "Cyberpunk Adventure"
minWidth: 80
minHeight: 24
---

# Welcome to the Future

This uses the Miami Vice theme - perfect for retro-futuristic games!

- [Start Game](game_start)
- [Options](options)
- [Exit](exit)

The theme automatically styles:
- **Headings** (accent1 - hot pink)
- **Links** (accent2 - cyan)
- **Body text** (cream white)
- **Backgrounds** (deep purple-navy)
```

## Style Mappings

When you apply a theme, these standard styles are automatically created:

| Style Name      | Usage                    | Theme Mapping        |
|-----------------|--------------------------|----------------------|
| `body`          | Default text             | `fgPrimary`          |
| `heading`       | H1 headers               | `accent1` (bold)     |
| `heading2`      | H2 headers               | `accent2` (bold)     |
| `heading3`      | H3+ headers              | `accent3`            |
| `link`          | Hyperlinks               | `accent2` (underline)|
| `link_focused`  | Selected/active links    | `accent1` (bold+underline) |
| `placeholder`   | Muted/secondary text     | `fgSecondary` (dim)  |
| `code`          | Code blocks              | `accent3` on `bgSecondary` |
| `emphasis`      | Italic text              | `fgPrimary` (italic) |
| `strong`        | Bold text                | `accent1` (bold)     |
| `warning`       | Alerts/warnings          | `accent3` (bold)     |
| `surface`       | Cards/panels background  | `fgPrimary` on `bgSecondary` |

## Customization Philosophy

**Themes provide:**
- Instant visual consistency
- Professionally chosen color combinations
- WCAG AA accessibility compliance
- Easy onboarding for new users

**Individual overrides allow:**
- Fine-tuning specific elements
- Brand customization
- Special emphasis
- Unique artistic vision

## Best Practices

1. **Start with a theme** - Pick one that matches your project's vibe
2. **Override sparingly** - Trust the theme's color harmony
3. **Test readability** - Ensure text remains readable after overrides
4. **Use semantic names** - Stick to standard style names when possible

## Theme Recommendations by Project Type

- **Games/Interactive Fiction** → miami-vice, cyberpunk, outrun
- **Documentation/Tutorials** → catppuccin, nord, dracula  
- **Terminal Applications** → terminal, nord, dracula
- **Data Visualization** → catppuccin, solarized-dark
- **Creative/Artistic** → outrun, miami-vice, cyberpunk
