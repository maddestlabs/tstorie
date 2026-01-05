---
title: ANSI Art Demo
---

# ANSI Art Support

TStorie now supports `ansi:name` code blocks for embedding ANSI art with colors and styles!

You can also load `.ans` files directly (classic ANSI art files from the BBS era).

```nim on:render
# Standard embedded blocks (with automatic escape sequence conversion)
drawAnsi(0, 2, 3, "logo")
drawAnsi(0, 2, 11, "gradient")
drawAnsi(0, 2, 16, "styled")

# Load .ans file (converted from \x1b[ to [ for markdown format)
drawAnsi(0, 2, 24, "amiex")

# Show info text
draw(0, 2, 23, "Classic .ANS file from BBS era -->")
```

## Embedded ANSI Art

Here's some embedded ANSI art with various styles:

```ansi
[38;2;0;217;142m  ▄  [0m [1;37m█[0m [38;2;100;100;100m▄▄▄▄   ▄                     [0m
[38;2;0;217;142m ▄█▄ [0m [1;37m█[0m [38;2;100;100;100m█     ▄█▄  ▄▄▄▄ ▄▄▄▄ ▄  ▄▄▄▄▄[0m
[38;2;0;217;142m  █  [0m [1;37m█[0m [38;2;100;100;100m▀▀▀▀▄  █   █  █ █    █  █▄▄▄█[0m
[38;2;0;217;142m  █  [0m [1;37m█[0m [38;2;100;100;100m    █  █   █  █ █    █  █    [0m
[38;2;0;217;142m  ▀▀ [0m [1;37m█[0m [38;2;100;100;100m▀▀▀▀   ▀▀  ▀▀▀▀ ▀    ▀  ▀▀▀▀▀[0m
```

```ansi:gradient
[38;5;196m▀[38;5;202m▀[38;5;208m▀[38;5;214m▀[38;5;220m▀[38;5;226m▀[38;5;190m▀[38;5;154m▀[38;5;118m▀[38;5;82m▀[38;5;46m▀[38;5;47m▀[38;5;48m▀[38;5;49m▀[38;5;50m▀[38;5;51m▀[38;5;45m▀[38;5;39m▀[38;5;33m▀[38;5;27m▀[0m  256 Color Gradient
[38;5;196m■[38;5;202m■[38;5;208m■[38;5;214m■[38;5;220m■[38;5;226m■[38;5;190m■[38;5;154m■[38;5;118m■[38;5;82m■[38;5;46m■[38;5;47m■[38;5;48m■[38;5;49m■[38;5;50m■[38;5;51m■[38;5;45m■[38;5;39m■[38;5;33m■[38;5;27m■[0m
```

```ansi:styled
[1;31m●[0m [1;33m Bold Red + Bold Yellow[0m
[3;32m●[0m [3;36m Italic Green + Italic Cyan[0m
[4;35m●[0m [4;34m Underline Magenta + Underline Blue[0m
[1;3;4;37m●[0m [1;3;4;37m Bold Italic Underline White[0m
[38;2;255;105;180m●[0m [38;2;255;105;180m RGB Hot Pink[0m
[48;5;18;38;5;226m█[48;5;19;38;5;227m█[48;5;20;38;5;228m█[48;5;21;38;5;229m█[0m Background + Foreground
```

```ansi:amiex
[255D[6C[0;1;30m▄▄ ▄▄▄ ▄  ▄ ▄▄▄▄    ▄▄▄ ▄  ▄    ▄▄▄▄ ▄    ▄ ▄▄▄▄▄▄▄▄
   ▄ ███▀ [0;31m▄▄▄▄▄▄[0;33m▄[0;31m▄[0;33m▄▄ [0;1;30m▀█▄█▀ [0;31m▄▄[0;33m▄[0;31m▄[0;33m▄▄ [0;1;30m▀█▄▀ [0;31m▄▄[0;33m▄[0;31m▄[0;33m▄▄   [0;31m▄▄▄▄▄[0;33m▄[0;31m▄[0;33m▄▄ [0;1;30m▀█▄▄
    ██▀ [0;31m▄▀ ░▓▒░[5C[0;1;31m▀▄ [0;1;30m▀ [0;31m▄▀▓░    [0;1;31m▀▄  [0;31m▄▀▒▓░   [0;1;31m▀▄  [0;31m░▓▒░    [0;1;31m▀▄ [0;1;30m▀██▄  [0;34m· │  ·
   [0;1;30m▀██▌[0;31m█    ▒░[8C[0;33m█ [0;31m▀  ▒[6C░[0;33m█    [0;31m▒[6C[0;33m▀▄ [0;31m▒░[6C▒[0;33m▓ [0;1;30m██[5C[0;1;34m│
    [0;1;30m▐█▌[0;31m█    ░[9C█    ░[6C▒▓    ░[6C░█ ░[7C░▒ [0;1;30m▐▌[0;34m──[0;1;34m──[0;1m─┼─[0;1;34m──[0;34m──
    [0;1;30m██ [0;31m█░[5C[0;33m▓[7C[0;31m█[11C░▒[11C▒█    ▄[0;33m▄[0;31m▄[0;33m▄▄[0;1;31m▄   [0;1;30m▌· [0;34m·  [0;1;34m│ [0;34m·
    [0;1;30m▐▄ [0;31m█▒[5C[0;33m▒[6C[0;31m░█[12C░[11C▓█[5C░▒   [0;1;31m░[8C[0;34m│
   [0;1;30m· ▌ [0;31m█▓[5C[0;33m░[6C[0;31m▒█[24C▒█[6C░  ░[0;33m▓  [0;1;30m▌ [0m·   [0;34m·
    [0m·  [0;31m█▒[12C▓█[24C░▓[9C▒▓ [0m·  [0;1m·
    [0;1;30m· r[0;31m▓░[12C▒█[25C▒[9C▓█   [0m·  [0;1m·
  [0m·   [0;1;30mo[0;31m▒   [0;1;30m·[5C·   [0;31m░█[14C[0;32m▄███▄[6C[0;31m░[9C▒▓ [0;1;30m·  ·[0;1m·  ·
   [0m·  [0;1;30my[0;31m░    [0;1;30m· ·  [0;33m─ ── [0;31m▓ [0;33m─ ───────── [0;32m██▀[0;33m──[0;32m▀[0;1;33;42m▀[1C[0;33m─ ─────────── [0;31m░▒ [0;33m── ──  ─
 [0;1m·  [0m·    [0;1;30m·[7C[0;31m░ ░░ ▒ ░ ░░▒▒▒▒▓▀ [0;32m███▄  ▄  [0;31m▀ [0;32m▄[0;1;33m▄ [0;31m▀█▓▓▒▒░░  ░ ░░ ░░  ░
   [0;1m·   [0m·    ·    [0;33m─ ── [0;31m░ [0;33m─ ─────── [0;32m██▄ ▀[0;1;33m▀[0;33m─ [0;32m▀█▄█▀ [0;33m─────────────── ──  ─
[9C[0m·[5C[0;1;30m·   ·[15C[0;32m▀▀█▄   ▄██▄[5C[0;33mTOOLZ
[12C[0;1m·[27C[0;32m▄█▀ ▀█[0;1;33m▀

[0m[255D
```

## Advanced Features

ANSI art supports:

- **8-color mode**: Basic ANSI colors (30-37, 90-97)
- **256-color mode**: Extended palette (ESC[38;5;Nm)
- **RGB mode**: True color (ESC[38;2;R;G;Bm)
- **Styles**: Bold, italic, underline, dim
- **Cursor positioning**: For complex layouts
- **.ans files**: Classic ANSI art files from the BBS era (use `skipConversion: true`)

Perfect for terminal-based graphics, logos, and retro ASCII art!

### Using .ans Files

To use classic `.ans` files (which already contain proper escape sequences):

```nim
# Pass 'true' as the 5th parameter to skip escape sequence conversion
drawAnsi(0, 10, 5, "amiex", true)
```

The `skipConversion` flag tells `drawAnsi()` not to convert `[` to `\x1b[` since `.ans` files already have the proper escape codes.
