import nimini
import std/tables

let code = """
proc outer(): seq =
  var dungeonHeight = 25
  var g = newSeq(10)
  
  proc inner() =
    for ry in 0..<5:
      if ry >= 0 and ry < dungeonHeight:
        var row = g[ry]
  
  inner()
  return g

var result = outer()
"""

try:
  let tokens = tokenizeDsl(code)
  echo "Tokens: OK"
  let program = parseDsl(tokens)
  echo "Parse: OK"
  initRuntime()
  execProgram(program, runtimeEnv)
  echo "Exec: OK"
except NiminiParseError as e:
  echo "Parse error at line ", e.line, ", col ", e.col, ": ", e.msg
except Exception as e:
  echo "Error: ", e.msg
