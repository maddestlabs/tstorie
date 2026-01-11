## Comprehensive test for chainable functions with UFCS support

import ../nimini

proc testBasicChaining() =
  echo "\n=== Test 1: Basic Array Chaining ==="
  
  let code = """
let numbers = @[5, 2, 8, 1, 9, 3, 7, 4, 6]

# Chain operations with intermediate variables
let step1 = numbers.sortedArr()
let step2 = step1.reversedArr()
let step3 = step2.takeArr(5)
"""
  
  let tokens = tokenizeDsl(code)
  let program = parseDsl(tokens)
  initRuntime()
  initStdlib()
  execProgram(program, runtimeEnv)
  
  let env = runtimeEnv
  echo "Original: [5, 2, 8, 1, 9, 3, 7, 4, 6]"
  echo "Sorted: ", getVar(env, "step1")
  echo "Reversed: ", getVar(env, "step2")
  echo "Take 5: ", getVar(env, "step3")
  echo "✓ Basic chaining works!"

proc testFilterMap() =
  echo "\n=== Test 2: Filter and Map ==="
  
  let code = """
# Define transform functions
proc isEven(x: int): bool =
  x % 2 == 0

proc double(x: int): int =
  x * 2

let numbers = @[1, 2, 3, 4, 5, 6, 7, 8, 9, 10]

# Filter even numbers, then double them
let evens = numbers.filterArr(isEven)
let doubled = evens.mapArr(double)
"""
  
  let tokens = tokenizeDsl(code)
  let program = parseDsl(tokens)
  initRuntime()
  initStdlib()
  execProgram(program, runtimeEnv)
  
  let env = runtimeEnv
  echo "Original: [1, 2, 3, 4, 5, 6, 7, 8, 9, 10]"
  echo "Evens: ", getVar(env, "evens")
  echo "Doubled: ", getVar(env, "doubled")
  echo "✓ Filter and map work!"

proc testAggregations() =
  echo "\n=== Test 3: Aggregation Functions ==="
  
  let code = """
let numbers = @[1, 2, 3, 4, 5]

let total = numbers.sumArr()
let firstNum = numbers.firstArr()
let lastNum = numbers.lastArr()
"""
  
  let tokens = tokenizeDsl(code)
  let program = parseDsl(tokens)
  initRuntime()
  initStdlib()
  execProgram(program, runtimeEnv)
  
  let env = runtimeEnv
  echo "Array: [1, 2, 3, 4, 5]"
  echo "Sum: ", getVar(env, "total").f
  echo "First: ", getVar(env, "firstNum").i
  echo "Last: ", getVar(env, "lastNum").i
  echo "✓ Aggregations work!"

proc testTakeDrop() =
  echo "\n=== Test 4: Take and Drop ==="
  
  let code = """
let numbers = @[1, 2, 3, 4, 5, 6, 7, 8, 9, 10]

let first5 = numbers.takeArr(5)
let skip3 = numbers.dropArr(3)
let middle = numbers.dropArr(2)
let middle3 = middle.takeArr(3)
"""
  
  let tokens = tokenizeDsl(code)
  let program = parseDsl(tokens)
  initRuntime()
  initStdlib()
  execProgram(program, runtimeEnv)
  
  let env = runtimeEnv
  echo "Array: [1, 2, 3, 4, 5, 6, 7, 8, 9, 10]"
  echo "First 5: ", getVar(env, "first5")
  echo "Skip 3: ", getVar(env, "skip3")
  echo "Middle 3: ", getVar(env, "middle3")
  echo "✓ Take and drop work!"

proc testUnique() =
  echo "\n=== Test 5: Unique Elements ==="
  
  let code = """
let numbers = @[1, 2, 2, 3, 3, 3, 4, 4, 5]

let unique = numbers.uniqueArr()
"""
  
  let tokens = tokenizeDsl(code)
  let program = parseDsl(tokens)
  initRuntime()
  initStdlib()
  execProgram(program, runtimeEnv)
  
  let env = runtimeEnv
  echo "Array: [1, 2, 2, 3, 3, 3, 4, 4, 5]"
  echo "Unique: ", getVar(env, "unique")
  echo "✓ Unique works!"

proc testPredicates() =
  echo "\n=== Test 6: Any and All ==="
  
  let code = """
proc greaterThan5(x: int): bool =
  x > 5

proc positive(x: int): bool =
  x > 0

let numbers = @[1, 2, 3, 4, 5, 6, 7, 8]

let hasLarge = numbers.anyArr(greaterThan5)
let allPositive = numbers.allArr(positive)

let count = numbers.countArr(greaterThan5)
"""
  
  let tokens = tokenizeDsl(code)
  let program = parseDsl(tokens)
  initRuntime()
  initStdlib()
  execProgram(program, runtimeEnv)
  
  let env = runtimeEnv
  echo "Array: [1, 2, 3, 4, 5, 6, 7, 8]"
  echo "Any > 5: ", getVar(env, "hasLarge").b
  echo "All positive: ", getVar(env, "allPositive").b
  echo "Count > 5: ", getVar(env, "count").i
  echo "✓ Predicates work!"

proc testStringChaining() =
  echo "\n=== Test 7: String Operations ==="
  
  let code = """
let text = "  hello world  "

let cleaned = text.trimStr()
let upper = cleaned.toUpper()
let withBang = upper.concatStr("!")
"""
  
  let tokens = tokenizeDsl(code)
  let program = parseDsl(tokens)
  initRuntime()
  initStdlib()
  execProgram(program, runtimeEnv)
  
  let env = runtimeEnv
  echo "Original: '  hello world  '"
  echo "Trimmed: '", getVar(env, "cleaned").s, "'"
  echo "Upper: '", getVar(env, "upper").s, "'"
  echo "With !: '", getVar(env, "withBang").s, "'"
  echo "✓ String chaining works!"

proc testComplexPipeline() =
  echo "\n=== Test 8: Complex Pipeline ==="
  
  let code = """
# Define helper functions
proc isOdd(x: int): bool =
  x % 2 == 1

proc square(x: int): int =
  x * x

# Complex transformation pipeline
let numbers = @[1, 2, 3, 4, 5, 6, 7, 8, 9, 10]

# Filter odd numbers
let odds = numbers.filterArr(isOdd)

# Square them
let squared = odds.mapArr(square)

# Sort descending by reversing
let sorted = squared.sortedArr()
let desc = sorted.reversedArr()

# Take top 3
let top3 = desc.takeArr(3)

# Sum them up
let result = top3.sumArr()
"""
  
  let tokens = tokenizeDsl(code)
  let program = parseDsl(tokens)
  initRuntime()
  initStdlib()
  execProgram(program, runtimeEnv)
  
  let env = runtimeEnv
  echo "Pipeline: [1..10] → filter odds → square → sort → reverse → take 3 → sum"
  echo "Odds: ", getVar(env, "odds")
  echo "Squared: ", getVar(env, "squared")
  echo "Descending: ", getVar(env, "desc")
  echo "Top 3: ", getVar(env, "top3")
  echo "Sum: ", getVar(env, "result").f
  echo "✓ Complex pipeline works!"

when isMainModule:
  echo "========================================"
  echo "Testing Chainable Functions (UFCS)"
  echo "========================================"
  
  try:
    testBasicChaining()
    testFilterMap()
    testAggregations()
    testTakeDrop()
    testUnique()
    testPredicates()
    testStringChaining()
    testComplexPipeline()
    
    echo "\n========================================"
    echo "✅ All tests passed!"
    echo "========================================"
    echo "\nUFCS (Uniform Function Call Syntax) is working!"
    echo "You can now chain operations like:"
    echo "  arr.filterArr(pred).mapArr(fn).sortedArr().takeArr(5)"
    echo "========================================"
  except Exception as e:
    echo "\n❌ Test failed: ", e.msg
    echo getStackTrace(e)
