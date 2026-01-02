## Character Display Width Utilities
## Provides functions to determine the display width of UTF-8 characters in terminal columns

proc getCharDisplayWidth*(ch: string): int =
  ## Returns the display width of a UTF-8 character in terminal columns
  ## Most emoji and East Asian characters occupy 2 columns, ASCII occupies 1
  if ch.len == 0:
    return 0
  
  let firstByte = ch[0].ord
  
  # ASCII characters (single byte) are always width 1
  if (firstByte and 0x80) == 0:
    return 1
  
  # Multi-byte UTF-8 characters
  # 2-byte sequences (U+0080 to U+07FF) - width 1
  if (firstByte and 0xE0) == 0xC0:
    return 1
  
  # 3-byte sequences (U+0800 to U+FFFF) - check for wide characters
  if (firstByte and 0xF0) == 0xE0:
    if ch.len >= 3:
      let cp = ((firstByte and 0x0F) shl 12) or
               ((ch[1].ord and 0x3F) shl 6) or
               (ch[2].ord and 0x3F)
      
      # East Asian Width ranges (common double-width ranges)
      # This covers most emoji, CJK characters, and other wide chars
      if (cp >= 0x1100 and cp <= 0x115F) or  # Hangul Jamo
         (cp >= 0x231A and cp <= 0x231B) or  # Watch, Hourglass
         (cp >= 0x23E9 and cp <= 0x23EC) or  # Media control symbols
         (cp >= 0x23F0 and cp <= 0x23F0) or  # Alarm Clock
         (cp >= 0x23F3 and cp <= 0x23F3) or  # Hourglass
         (cp >= 0x25FD and cp <= 0x25FE) or  # White/Black Small Squares
         (cp >= 0x2614 and cp <= 0x2615) or  # Umbrella, Hot Beverage
         (cp >= 0x2648 and cp <= 0x2653) or  # Zodiac Signs
         (cp >= 0x267F and cp <= 0x267F) or  # Wheelchair Symbol
         (cp >= 0x2693 and cp <= 0x2693) or  # Anchor
         (cp >= 0x26A1 and cp <= 0x26A1) or  # High Voltage
         (cp >= 0x26AA and cp <= 0x26AB) or  # White/Black Circles
         (cp >= 0x26BD and cp <= 0x26BE) or  # Soccer/Baseball
         (cp >= 0x26C4 and cp <= 0x26C5) or  # Snowman, Sun
         (cp >= 0x26CE and cp <= 0x26CE) or  # Ophiuchus
         (cp >= 0x26D4 and cp <= 0x26D4) or  # No Entry
         (cp >= 0x26EA and cp <= 0x26EA) or  # Church
         (cp >= 0x26F2 and cp <= 0x26F3) or  # Fountain, Golf
         (cp >= 0x26F5 and cp <= 0x26F5) or  # Sailboat
         (cp >= 0x26FA and cp <= 0x26FA) or  # Tent
         (cp >= 0x26FD and cp <= 0x26FD) or  # Fuel Pump
         (cp >= 0x2705 and cp <= 0x2705) or  # Check Mark Button
         (cp >= 0x270A and cp <= 0x270B) or  # Fist, Raised Hand
         (cp >= 0x2728 and cp <= 0x2728) or  # Sparkles
         (cp >= 0x274C and cp <= 0x274C) or  # Cross Mark
         (cp >= 0x274E and cp <= 0x274E) or  # Cross Mark Button
         (cp >= 0x2753 and cp <= 0x2755) or  # Question/Exclamation marks
         (cp >= 0x2757 and cp <= 0x2757) or  # Exclamation Mark
         (cp >= 0x2795 and cp <= 0x2797) or  # Plus/Minus/Division signs
         (cp >= 0x27B0 and cp <= 0x27B0) or  # Curly Loop
         (cp >= 0x27BF and cp <= 0x27BF) or  # Double Curly Loop
         (cp >= 0x2B1B and cp <= 0x2B1C) or  # Black/White Large Squares
         (cp >= 0x2B50 and cp <= 0x2B50) or  # Star
         (cp >= 0x2B55 and cp <= 0x2B55) or  # Heavy Large Circle
         (cp >= 0x2E80 and cp <= 0x2EFF) or  # CJK Radicals
         (cp >= 0x2F00 and cp <= 0x2FDF) or  # Kangxi Radicals
         (cp >= 0x3000 and cp <= 0x303F) or  # CJK Symbols and Punctuation
         (cp >= 0x3040 and cp <= 0x309F) or  # Hiragana
         (cp >= 0x30A0 and cp <= 0x30FF) or  # Katakana
         (cp >= 0x3100 and cp <= 0x312F) or  # Bopomofo
         (cp >= 0x3130 and cp <= 0x318F) or  # Hangul Compatibility Jamo
         (cp >= 0x3190 and cp <= 0x319F) or  # Kanbun
         (cp >= 0x31A0 and cp <= 0x31BF) or  # Bopomofo Extended
         (cp >= 0x31C0 and cp <= 0x31EF) or  # CJK Strokes
         (cp >= 0x3200 and cp <= 0x32FF) or  # Enclosed CJK Letters and Months
         (cp >= 0x3300 and cp <= 0x33FF) or  # CJK Compatibility
         (cp >= 0x3400 and cp <= 0x4DBF) or  # CJK Unified Ideographs Extension A
         (cp >= 0x4DC0 and cp <= 0x4DFF) or  # Yijing Hexagram Symbols
         (cp >= 0x4E00 and cp <= 0x9FFF) or  # CJK Unified Ideographs
         (cp >= 0xA960 and cp <= 0xA97F) or  # Hangul Jamo Extended-A
         (cp >= 0xAC00 and cp <= 0xD7AF) or  # Hangul Syllables
         (cp >= 0xF900 and cp <= 0xFAFF) or  # CJK Compatibility Ideographs
         (cp >= 0xFE10 and cp <= 0xFE1F) or  # Vertical Forms
         (cp >= 0xFE30 and cp <= 0xFE4F) or  # CJK Compatibility Forms
         (cp >= 0xFF00 and cp <= 0xFF60) or  # Fullwidth Forms
         (cp >= 0xFFE0 and cp <= 0xFFE6):    # Fullwidth Forms
        return 2
    return 1
  
  # 4-byte sequences (U+10000 to U+10FFFF) - most are emoji and wide
  if (firstByte and 0xF8) == 0xF0:
    if ch.len >= 4:
      let cp = ((firstByte and 0x07) shl 18) or
               ((ch[1].ord and 0x3F) shl 12) or
               ((ch[2].ord and 0x3F) shl 6) or
               (ch[3].ord and 0x3F)
      
      # Most 4-byte characters are emoji or supplementary ideographs (width 2)
      # Exceptions are rare, so default to 2 for 4-byte sequences
      if (cp >= 0x1F000 and cp <= 0x1FFFF) or  # Emoji and Symbols
         (cp >= 0x20000 and cp <= 0x2FFFF):     # CJK Extension B-F
        return 2
    return 2  # Default to width 2 for 4-byte sequences
  
  # Fallback
  return 1
