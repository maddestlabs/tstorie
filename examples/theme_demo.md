---
theme: "catppuccin"
title: "Theme Demo"
minWidth: 80
minHeight: 24
---

```nim on:init
print "Theme system demo initialized"
```

```nim on:render
bgClear()
fgClear()
```

# 🎨 Theme System Demo

Welcome to the TStorie theme system! This demo uses the **Catppuccin Mocha** theme.

## What Are Themes?

Themes provide a complete color palette for your documents. Instead of manually defining colors for every element, just set:

```
theme: "catppuccin"
```

And you get beautiful, accessible colors automatically!

## Available Themes

Try these in your own documents:

- **catppuccin** - Soft, modern (current theme!)
- **nord** - Cool Arctic palette
- **dracula** - Vibrant developer favorite
- **miami-vice** - Bold 80s cyberpunk
- **cyberpunk** - Classic duotone
- **terminal** - Classic green CRT

## Features

### Automatic Styling

All these elements are automatically styled:

- **Bold text** uses accent colors
- *Italic text* maintains readability
- `Code snippets` have distinct backgrounds
- Regular text is optimized for long reading

### Interactive Elements

Navigation links are automatically themed too:

- [Home](#home)
- [About](#about)
- [Contact](#contact)

### Hierarchical Headings

Headings at different levels use different accent colors:

#### This is an H4
##### This is an H5
###### This is an H6

## Override When Needed

You can still override individual styles:

```markdown
---
theme: "catppuccin"
styles.heading.fg: "#FF0080"  # Custom hot pink!
---
```

## Why Use Themes?

✅ **Instant visual consistency**  
✅ **Professional color harmony**  
✅ **Accessible contrast ratios**  
✅ **Easy to change entire look**  
✅ **Focus on content, not colors**

## Try It Yourself!

Edit this file's front matter to try different themes:

```yaml
---
theme: "nord"        # Try this!
# or
theme: "miami-vice"  # Or this!
# or
theme: "cyberpunk"   # Or this!
---
```

Each theme provides a completely different aesthetic while maintaining readability and usability!

---

*This demo showcases the theme system. See THEME_GUIDE.md for complete documentation.*
