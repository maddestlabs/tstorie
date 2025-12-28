## Layout Module for TStorie
## 
## Provides text layout operations including:
## - Text measurement (UTF-8 aware)
## - Horizontal alignment (left, center, right, justify)
## - Vertical alignment (top, middle, bottom)
## - Word/character wrapping
## - Bounded text box rendering
##
## Note: This module is designed to be used alongside tstorie.nim
## and requires TermBuffer, Layer, and Style types to be available.

# Import core types when used as a module
when not declared(Layer):
  import ../src/types

import unicode
import strutils
import sequtils

type
  HAlign* = enum
    ## Horizontal text alignment
    AlignLeft
    AlignCenter
    AlignRight
    AlignJustify

  VAlign* = enum
    ## Vertical text alignment
    AlignTop
    AlignMiddle
    AlignBottom

  WrapMode* = enum
    ## Text wrapping behavior
    WrapNone      ## Truncate at boundary
    WrapWord      ## Break at word boundaries
    WrapChar      ## Break at any character
    WrapEllipsis  ## Truncate with "..." suffix
    WrapJustify   ## Wrap with justification

  LayoutResult* = object
    ## Result of layout operations
    linesUsed*: int          ## Number of lines actually rendered
    linesFit*: int           ## Number of lines that fit in bounds
    totalLines*: int         ## Total lines after wrapping
    truncated*: bool         ## True if content was truncated
    overflow*: seq[string]   ## Lines that didn't fit

# ================================================================
# TEXT MEASUREMENT
# ================================================================

proc visualWidth*(text: string): int =
  ## Calculate the visual width of text (UTF-8 aware)
  ## Returns the number of terminal columns the text occupies
  result = 0
  for rune in text.runes:
    result += 1

proc splitIntoWords*(text: string): seq[string] =
  ## Split text into words, preserving whitespace as separate tokens
  result = @[]
  var current = ""
  var inWord = false
  
  for ch in text:
    if ch in {' ', '\t'}:
      if current.len > 0:
        result.add(current)
        current = ""
      result.add($ch)
      inWord = false
    else:
      current.add(ch)
      inWord = true
  
  if current.len > 0:
    result.add(current)

proc truncateWithEllipsis*(text: string, maxWidth: int): string =
  ## Truncate text to maxWidth, adding "..." if truncated
  if maxWidth <= 0:
    return ""
  
  let width = text.visualWidth()
  if width <= maxWidth:
    return text
  
  if maxWidth <= 3:
    return "...".substr(0, maxWidth - 1)
  
  # Find where to cut
  var visWidth = 0
  var cutPos = 0
  for rune in text.runes:
    if visWidth + 1 > maxWidth - 3:
      break
    visWidth += 1
    cutPos += rune.size
  
  return text.substr(0, cutPos - 1) & "..."

# ================================================================
# TEXT WRAPPING
# ================================================================

proc wrapText*(text: string, maxWidth: int, mode: WrapMode): seq[string] =
  ## Wrap text to fit within maxWidth columns
  ## Returns a sequence of lines
  result = @[]
  
  if maxWidth <= 0:
    return @[]
  
  case mode
  of WrapNone:
    result.add(text)
  
  of WrapEllipsis:
    result.add(truncateWithEllipsis(text, maxWidth))
  
  of WrapChar:
    var line = ""
    var lineWidth = 0
    
    for rune in text.runes:
      if lineWidth >= maxWidth:
        result.add(line)
        line = ""
        lineWidth = 0
      
      line.add(rune.toUTF8())
      lineWidth += 1
    
    if line.len > 0:
      result.add(line)
  
  of WrapWord:
    let words = text.splitIntoWords()
    var line = ""
    var lineWidth = 0
    
    for word in words:
      let wordWidth = word.visualWidth()
      
      # If word alone is too wide, force char wrap
      if wordWidth > maxWidth:
        if line.len > 0:
          result.add(line.strip(trailing = true))
          line = ""
          lineWidth = 0
        
        # Char wrap the long word
        for rune in word.runes:
          if lineWidth >= maxWidth:
            result.add(line)
            line = ""
            lineWidth = 0
          line.add(rune.toUTF8())
          lineWidth += 1
        continue
      
      # Try to fit word on current line
      if lineWidth + wordWidth <= maxWidth:
        line.add(word)
        lineWidth += wordWidth
      else:
        # Start new line
        if line.len > 0:
          result.add(line.strip(trailing = true))
        line = word
        lineWidth = wordWidth
    
    if line.len > 0:
      result.add(line.strip(trailing = true))
  
  of WrapJustify:
    # Same as WrapWord for wrapping, justify applied during render
    result = wrapText(text, maxWidth, WrapWord)

proc wrapTextMultiLine*(text: string, maxWidth: int, mode: WrapMode): seq[string] =
  ## Wrap multi-line text (respecting existing \n)
  result = @[]
  let wrapModeToUse = if mode == WrapJustify: WrapWord else: mode
  for line in text.splitLines():
    result.add(wrapText(line, maxWidth, wrapModeToUse))

# ================================================================
# ALIGNMENT HELPERS
# ================================================================

proc alignHorizontal*(text: string, width: int, align: HAlign): string =
  ## Align text within a given width
  let textWidth = text.visualWidth()
  
  if textWidth >= width:
    return text
  
  case align
  of AlignLeft:
    return text & spaces(width - textWidth)
  
  of AlignRight:
    return spaces(width - textWidth) & text
  
  of AlignCenter:
    let leftPad = (width - textWidth) div 2
    let rightPad = width - textWidth - leftPad
    return spaces(leftPad) & text & spaces(rightPad)
  
  of AlignJustify:
    # For single line, justify is same as left
    return text & spaces(width - textWidth)

proc justifyLine*(text: string, width: int): string =
  ## Justify a line by distributing spaces evenly between words
  let words = text.split(' ').filterIt(it.len > 0)
  
  if words.len <= 1:
    return text
  
  let totalWordWidth = words.mapIt(it.visualWidth()).foldl(a + b, 0)
  let totalSpaces = width - totalWordWidth
  let gaps = words.len - 1
  
  if gaps <= 0 or totalSpaces <= 0:
    return text
  
  let spacesPerGap = totalSpaces div gaps
  let extraSpaces = totalSpaces mod gaps
  
  result = ""
  for i, word in words:
    result.add(word)
    if i < words.len - 1:
      result.add(spaces(spacesPerGap))
      if i < extraSpaces:
        result.add(" ")

# ================================================================
# CORE RENDERING FUNCTIONS
# ================================================================
# Note: These functions require TermBuffer, Layer, and Style types
# from tstorie.nim to be available in the calling scope.

proc writeAligned*[T, S](buffer: var T, x, y, width: int, 
                         text: string, align: HAlign, style: S) =
  ## Write aligned text on a single line
  let alignedText = alignHorizontal(text, width, align)
  buffer.writeText(x, y, alignedText, style)

proc writeWrapped*[T, S](buffer: var T, x, y, width, height: int,
                         text: string, hAlign: HAlign = AlignLeft, 
                         vAlign: VAlign = AlignTop,
                         wrap: WrapMode = WrapWord, 
                         style: S): LayoutResult =
  ## Write wrapped text within a bounded area
  ## Returns layout information including overflow
  
  result = LayoutResult()
  
  # Wrap the text
  var lines = wrapTextMultiLine(text, width, wrap)
  result.totalLines = lines.len
  
  # Calculate vertical alignment offset
  let linesFit = min(lines.len, height)
  result.linesFit = linesFit
  
  let startY = case vAlign
    of AlignTop: y
    of AlignMiddle: y + max(0, (height - linesFit) div 2)
    of AlignBottom: y + max(0, height - linesFit)
  
  # Render lines that fit
  var renderedLines = 0
  for i in 0..<linesFit:
    let lineY = startY + i
    if lineY >= y and lineY < y + height:
      var lineText = lines[i]
      
      # Apply horizontal alignment (with justify special case)
      if hAlign == AlignJustify and i < lines.len - 1:
        lineText = justifyLine(lineText, width)
      else:
        lineText = alignHorizontal(lineText, width, hAlign)
      
      buffer.writeText(x, lineY, lineText, style)
      renderedLines += 1
  
  result.linesUsed = renderedLines
  result.truncated = lines.len > linesFit
  
  # Collect overflow
  if result.truncated:
    result.overflow = lines[linesFit..^1]

proc writeTextBox*[T, S](buffer: var T, 
                         x, y, width, height: int,
                         text: string, 
                         hAlign: HAlign = AlignLeft,
                         vAlign: VAlign = AlignTop,
                         wrap: WrapMode = WrapWord,
                         style: S): LayoutResult =
  ## Convenience function: write text in a box with alignment and wrapping
  result = writeWrapped(buffer, x, y, width, height, text, hAlign, vAlign, wrap, style)

# ================================================================
# LAYER VARIANTS
# ================================================================

proc writeAlignedOnLayer*[L, S](layer: L, x, y, width: int,
                                text: string, align: HAlign, style: S) =
  ## Write aligned text on a layer
  writeAligned(layer.buffer, x, y, width, text, align, style)

proc writeWrappedOnLayer*[L, S](layer: L, x, y, width, height: int,
                                text: string, hAlign: HAlign = AlignLeft,
                                vAlign: VAlign = AlignTop,
                                wrap: WrapMode = WrapWord,
                                style: S): LayoutResult =
  ## Write wrapped text on a layer
  result = writeWrapped(layer.buffer, x, y, width, height, text, hAlign, vAlign, wrap, style)

proc writeTextBoxOnLayer*[L, S](layer: L, 
                                x, y, width, height: int,
                                text: string,
                                hAlign: HAlign = AlignLeft,
                                vAlign: VAlign = AlignTop,
                                wrap: WrapMode = WrapWord,
                                style: S): LayoutResult =
  ## Write text box on a layer
  result = writeTextBox(layer.buffer, x, y, width, height, text, hAlign, vAlign, wrap, style)
