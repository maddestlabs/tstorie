## Simple test for isolated RNG

import ../nimini
import std/random

proc testSimple() =
  echo "Starting test..."
  
  let code = """
print("Creating RNG...")
var rng = initRand(12345)
print("Generating 5 random numbers...")
var i = 0
while i < 5:
  let val = rand(rng, 100)
  print(val)
  i = i + 1
"""
  
  echo "Code to execute:"
  echo code
  
  try:
    echo "Tokenizing..."
    let tokens = tokenizeDsl(code)
    echo "Tokens: ", tokens.len
    echo "Parsing..."
    let prog = parseDsl(tokens)
    echo "Program stmts: ", prog.stmts.len
    echo "Init runtime..."
    initRuntime()
    echo "Init stdlib..."
    initStdlib()
    echo "Executing..."
    execProgram(prog, runtimeEnv)
    echo "Done!"
  except Exception as e:
    echo "Error: ", e.msg
    echo e.getStackTrace()

when isMainModule:
  echo "Test program starting..."
  testSimple()
  echo "Test program finished."
