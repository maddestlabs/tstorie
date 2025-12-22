## Debug utilities for Nimini
## Enable with: nim c -d:niminiDebug yourfile.nim

import std/[strutils]

when not defined(emscripten):
  import std/[times]

proc debugWriteLine(msg: string) {.inline.} =
  ## Write debug output to stderr (native only, silent in WASM)
  when not defined(emscripten):
    stderr.writeLine(msg)

when defined(niminiDebug):
  when not defined(emscripten):
    import std/[times]
  
  proc debugLog*(category: string, msg: string) {.used.} =
    ## Write debug output to stderr (native) or console.log (WASM)
    when defined(emscripten):
      debugWriteLine("[" & category & "] " & msg)
    else:
      let timestamp = now().format("HH:mm:ss.fff")
      debugWriteLine("[" & timestamp & "] [" & category & "] " & msg)
  
  proc debugTokens*(category: string, tokens: seq[auto], pos: int, context: int = 3) {.used.} =
    ## Dump tokens around a position
    debugWriteLine("[" & category & "] Tokens around position " & $pos & ":")
    let start = max(0, pos - context)
    let endPos = min(tokens.len - 1, pos + context)
    for i in start..endPos:
      let marker = if i == pos: " >>> " else: "     "
      let tok = tokens[i]
      debugWriteLine(marker & "[" & $i & "] " & $tok.kind & ": '" & 
                    tok.lexeme.replace("\n", "\\n") & "' (line " & $tok.line & ")")
  
  template debugBlock*(category: string, label: string, body: untyped) =
    ## Execute a block with enter/exit logging
    debugLog(category, "ENTER: " & label)
    body
    debugLog(category, "EXIT: " & label)

else:
  # No-op versions when debug is disabled
  proc debugLog*(category: string, msg: string) {.used, inline.} = discard
  proc debugTokens*(category: string, tokens: seq[auto], pos: int, context: int = 3) {.used, inline.} = discard
  template debugBlock*(category: string, label: string, body: untyped) =
    body

## Error logging that's always enabled
proc logParseError*(msg: string, line: int, col: int, tokens: seq[auto] = @[], pos: int = -1) {.used.} =
  ## Log parse errors - to file (native) or silent (WASM)
  ## In WASM, errors will be caught and displayed by the main error handler
  when not defined(emscripten):
    # For native builds, write to file for post-mortem analysis
    const errorLogPath = "/tmp/nimini_parse_errors.log"
    
    try:
      let f = open(errorLogPath, fmAppend)
      defer: f.close()
      
      f.writeLine("=" .repeat(80))
      f.writeLine("Parse Error at ", now().format("yyyy-MM-dd HH:mm:ss"))
      f.writeLine("  Message: ", msg)
      f.writeLine("  Location: line ", line, ", col ", col)
      
      if tokens.len > 0 and pos >= 0:
        f.writeLine("\n  Token context:")
        let start = max(0, pos - 5)
        let endPos = min(tokens.len - 1, pos + 5)
        for i in start..endPos:
          let marker = if i == pos: " >>> " else: "     "
          let tok = tokens[i]
          f.writeLine(marker, "[", i, "] ", tok.kind, ": '", 
                     tok.lexeme.replace("\n", "\\n").replace("\r", "\\r"), 
                     "' (line ", tok.line, ")")
      
      f.writeLine("")
    except IOError:
      # Silently fail if we can't write the log
      discard
