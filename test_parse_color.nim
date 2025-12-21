import strutils

proc parseColor(colorStr: string): tuple[r, g, b: uint8] =
  let trimmed = colorStr.strip()
  echo "Parsing: '", trimmed, "'"
  
  if trimmed.startsWith("#"):
    echo "  Detected as hex color"
    if trimmed.len == 7:
      echo "  Length is correct (7)"
      let r = parseHexInt(trimmed[1..2])
      let g = parseHexInt(trimmed[3..4])
      let b = parseHexInt(trimmed[5..6])
      echo "  Parsed: r=", r, " g=", g, " b=", b
      return (r.uint8, g.uint8, b.uint8)
    else:
      echo "  ERROR: Length is ", trimmed.len, " not 7"
  elif ',' in trimmed:
    echo "  Detected as comma-separated"
  else:
    echo "  ERROR: No # or comma found"
  
  echo "  Returning default black"
  return (0'u8, 0'u8, 0'u8)

# Test the colors from depths.md
echo parseColor("#FFD700")
echo parseColor("#4A9EFF")
echo parseColor("#CCCCCC")
echo parseColor("#505050")
