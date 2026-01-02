import nimini
import std/tables

let code = """
proc outer(x: int): int =
  var y = x + 1
  
  proc inner(z: int): int =
    return z * 2
  
  var result = inner(y)
  return result

var value = outer(5)
"""

try:
  let tokens = tokenizeDsl(code)
  echo "Tokens: OK"
  let program = parseDsl(tokens)
  echo "Parse: OK"
  initRuntime()
  execProgram(program, runtimeEnv)
  echo "Exec: OK"
  if runtimeEnv.vars.contains("value"):
    let value = runtimeEnv.vars["value"]
    echo "value = ", value
except NiminiParseError as e:
  echo "Parse error at line ", e.line, ", col ", e.col, ": ", e.msg
except Exception as e:
  echo "Error: ", e.msg
