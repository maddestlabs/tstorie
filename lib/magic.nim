## Magic - Runtime compression/decompression for magic blocks
##
## This module provides the core compression functions used by both
## the CLI tool and the runtime parser for handling magic blocks.

import std/[strutils, base64, tables]
import zippy  # Pure Nim - works on native AND WASM

proc compressString*(input: string): string =
  ## Compress a string and encode as base64
  ## Uses raw DEFLATE format (RFC 1951) - compatible with JS CompressionStream('deflate-raw')
  let compressed = compress(input, dataFormat = dfDeflate)
  result = encode(compressed)

proc decompressString*(input: string): string =
  ## Decode base64 and decompress
  ## Uses zlib format (RFC 1950) - compatible with JS CompressionStream('deflate')
  try:
    let decoded = decode(input)
    result = uncompress(decoded, dataFormat = dfZlib)
  except Exception as e:
    # If decompression fails, return empty string
    when not defined(release):
      echo "Decompression error: ", e.msg
    result = ""

proc parseSugarParams*(paramString: string): Table[string, string] =
  ## Parse parameters from sugar block header
  ## Example: name="bugs" count="100" speed="3.0"
  ## Returns: {"name": "bugs", "count": "100", "speed": "3.0"}
  result = initTable[string, string]()
  
  var i = 0
  while i < paramString.len:
    # Skip whitespace
    while i < paramString.len and paramString[i] in {' ', '\t', '\n'}:
      inc i
    
    if i >= paramString.len:
      break
    
    # Parse key
    var key = ""
    while i < paramString.len and paramString[i] notin {' ', '=', '\t', '\n'}:
      key.add(paramString[i])
      inc i
    
    # Skip whitespace and '='
    while i < paramString.len and paramString[i] in {' ', '=', '\t', '\n'}:
      inc i
    
    if i >= paramString.len or key.len == 0:
      break
    
    # Parse value (expect quoted string)
    var value = ""
    if paramString[i] == '"':
      inc i  # Skip opening quote
      while i < paramString.len and paramString[i] != '"':
        value.add(paramString[i])
        inc i
      if i < paramString.len:
        inc i  # Skip closing quote
    else:
      # Unquoted value (until space)
      while i < paramString.len and paramString[i] notin {' ', '\t', '\n'}:
        value.add(paramString[i])
        inc i
    
    if key.len > 0:
      result[key] = value

proc extractDeclaredParams*(content: string): seq[string] =
  ## Extract parameter names declared in <!-- MAGIC_PARAMS: name, count, speed --> comments
  ## This provides explicit parameter declaration for safety
  result = @[]
  
  for line in content.splitLines():
    let trimmed = line.strip()
    if trimmed.startsWith("<!--") and trimmed.contains("MAGIC_PARAMS:"):
      # Extract parameter list
      let startPos = trimmed.find("MAGIC_PARAMS:") + 13
      let endPos = trimmed.find("-->", startPos)
      if endPos > startPos:
        let paramList = trimmed[startPos..<endPos].strip()
        for param in paramList.split(','):
          let cleaned = param.strip()
          if cleaned.len > 0:
            result.add(cleaned)
      break

proc substituteSugarParams*(content: string, params: Table[string, string], 
                           syntax: string = "{{PARAM}}"): string =
  ## Replace parameter placeholders in content with actual values
  ## 
  ## Syntax options:
  ## - "{{PARAM}}" (default): {{name}} becomes "bugs"  - Mustache/Handlebars style
  ## - "@PARAM@": @name@ becomes "bugs" - Simple distinctive markers
  ## - "$PARAM$": $name$ becomes "bugs" - Dollar signs
  ## - "<!--PARAM-->": <!--name--> becomes "bugs" - HTML comment style (safest for code)
  ## 
  ## If content contains <!-- MAGIC_PARAMS: ... -->, only those declared params are substituted
  result = content
  
  # Check if parameters are explicitly declared
  let declaredParams = extractDeclaredParams(content)
  let useOnlyDeclared = declaredParams.len > 0
  
  for key, value in params:
    # Skip if this param isn't declared (when using explicit declaration)
    if useOnlyDeclared and key notin declaredParams:
      continue
    
    # Build placeholder based on syntax
    var placeholder = ""
    case syntax:
    of "{{PARAM}}":
      placeholder = "{{" & key & "}}"
    of "@PARAM@":
      placeholder = "@" & key & "@"
    of "$PARAM$":
      placeholder = "$" & key & "$"
    of "<!--PARAM-->":
      placeholder = "<!--" & key & "-->"
    else:
      # Fallback to double-brace
      placeholder = "{{" & key & "}}"
    
    result = result.replace(placeholder, value)
