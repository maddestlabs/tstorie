## Example demonstrating XOR and negative variable support

import ../nimini

proc main() =
  let code = """
# XOR operator examples
let flag1 = true
let flag2 = false

let xor_result = flag1 xor flag2

# Negative variable examples
let temperature = 25
let freezing_point = 0
let below_freezing = freezing_point - temperature

# Combined example: checking temperature ranges
let is_hot = temperature > 30
let is_cold = temperature < 10

# XOR can be used to check if temperature is extreme (either hot or cold, not both)
let is_extreme = is_hot xor is_cold

# Using negative numbers in calculations
let celsius = 20
let fahrenheit_offset = -32
let celsius_to_kelvin = celsius - (-273)

# More complex expressions
let x = 10
let y = 5
let expr1 = -x + y
let expr2 = (-x) * (-y)
"""

  echo "Running nimini code with XOR and negative variable support...\n"
  
  let tokens = tokenizeDsl(code)
  let program = parseDsl(tokens)
  initRuntime()
  initStdlib()
  execProgram(program, runtimeEnv)
  
  # Print results
  let env = runtimeEnv
  echo "Results:"
  echo "  xor_result = ", getVar(env, "xor_result").b
  echo "  below_freezing = ", getVar(env, "below_freezing").i
  echo "  is_extreme = ", getVar(env, "is_extreme").b
  echo "  celsius_to_kelvin = ", getVar(env, "celsius_to_kelvin").i
  echo "  expr1 (-10 + 5) = ", getVar(env, "expr1").i
  echo "  expr2 (-10 * -5) = ", getVar(env, "expr2").i

when isMainModule:
  main()
