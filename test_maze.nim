import nimini
import std/tables

let code = """
proc test() =
  var mazeCells = newSeq(0)
  add(mazeCells, 5)
  add(mazeCells, 10)
  
  while len(mazeCells) > 0:
    var x = pop(mazeCells)
    var y = pop(mazeCells)

test()
"""

try:
  let tokens = tokenizeDsl(code)
  echo "Tokens: OK"
  let program = parseDsl(tokens)
  echo "Parse: OK"
  initRuntime()
  echo "Running..."
  execProgram(program, runtimeEnv)
  echo "Exec: OK"
except NiminiParseError as e:
  echo "Parse error at line ", e.line, ", col ", e.col, ": ", e.msg
except Exception as e:
  echo "Error: ", e.msg
  echo getCurrentExceptionMsg()
