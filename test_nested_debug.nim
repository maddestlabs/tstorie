import nimini
import std/tables

let code = """
proc outer() =
  proc inner() =
    if true:
      return
  
  inner()
"""

try:
  let tokens = tokenizeDsl(code)
  echo "Tokens: OK"
  let program = parseDsl(tokens)
  echo "Parse: OK"
except NiminiParseError as e:
  echo "Parse error at line ", e.line, ", col ", e.col, ": ", e.msg
except Exception as e:
  echo "Error: ", e.msg
