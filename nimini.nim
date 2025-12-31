## Nimini - Lightweight Nim-inspired scripting for interactive applications
##
## This is the main module that exports all public APIs.
##
## Basic usage:
##
##   import nimini
##
##   # Tokenize DSL source
##   let tokens = tokenizeDsl(mySource)
##
##   # Parse into AST
##   let program = parseDsl(tokens)
##
##   # Initialize runtime
##   initRuntime()
##   registerNative("myFunc", myNativeFunc)
##
##   # Execute
##   execProgram(program, runtimeEnv)
##
## Multi-Language Frontend usage (new):
##
##   import nimini
##
##   # Auto-detect and compile from any supported language
##   let program = compileSource(myCode)
##
##   # Or specify frontend explicitly
##   let program = compileSource(myCode, getNimFrontend())

import nimini/[ast, runtime, tokenizer, plugin, parser, codegen, codegen_ext, backend, frontend]
import nimini/stdlib/seqops

# backends allow exporting generated code in various languages
import nimini/backends/[nim_backend, python_backend, javascript_backend]

# frontends allow scripting in various languages
import nimini/frontends/[nim_frontend]
# Uncomment to enable Python frontend support:
# import nimini/frontends/[py_frontend]
# Uncomment to enable JavaScript frontend support:
# import nimini/frontends/[js_frontend]

import nimini/lang/[nim_extensions]

# Re-export everything
export ast
export tokenizer
export parser
export runtime
export plugin
export codegen
export codegen_ext
export nim_extensions  # Nim-specific language extensions (autopragma features)
export seqops

# Export metadata system for export tools
export FunctionMetadata, gFunctionMetadata, getImports, getStorieLibs, hasMetadata

# Import stdlib modules
import nimini/stdlib/[mathops, typeconv, collections, random, stringops]
export mathops, typeconv, collections, random, stringops

# Initialize standard library - must be called after initRuntime()
proc initStdlib*() =
  ## Register standard library functions with the runtime
  ## NOTE: Random functions require setNiminiRng() to be called separately
  
  # Sequence operations (built-in, no imports needed)
  registerNative("add", niminiAdd,
    description = "Add element to sequence")
  registerNative("len", niminiLen,
    description = "Get length of sequence or string")
  registerNative("newSeq", niminiNewSeq,
    description = "Create new sequence with specified length")
  registerNative("setLen", niminiSetLen,
    description = "Set length of sequence")
  registerNative("delete", niminiDelete,
    description = "Delete element at index from sequence")
  registerNative("insert", niminiInsert,
    description = "Insert element at index in sequence")
  registerNative("pop", niminiPop,
    description = "Remove and return last element from sequence")
  registerNative("reverse", niminiReverse,
    imports = @["algorithm"],
    description = "Reverse sequence in place")
  registerNative("contains", niminiContains,
    description = "Check if sequence contains element")
  registerNative("find", niminiFindIndex,
    description = "Find index of element in sequence")
  
  # Collection data structures
  registerNative("newHashSet", niminiNewHashSet,
    imports = @["sets"],
    description = "Create new hash set")
  registerNative("incl", niminiHashSetIncl,
    description = "Include element in hash set")
  registerNative("excl", niminiHashSetExcl,
    description = "Exclude element from hash set")
  registerNative("card", niminiHashSetCard,
    description = "Get cardinality (size) of hash set")
  registerNative("toSeq", niminiHashSetToSeq,
    description = "Convert hash set to sequence")
  registerNative("newDeque", niminiNewDeque,
    imports = @["deques"],
    description = "Create new double-ended queue")
  registerNative("addFirst", niminiDequeAddFirst,
    description = "Add element to front of deque")
  registerNative("addLast", niminiDequeAddLast,
    description = "Add element to back of deque")
  registerNative("popFirst", niminiDequePopFirst,
    description = "Remove and return first element from deque")
  registerNative("popLast", niminiDequePopLast,
    description = "Remove and return last element from deque")
  registerNative("peekFirst", niminiDequePeekFirst,
    description = "Get first element without removing")
  registerNative("peekLast", niminiDequePeekLast,
    description = "Get last element without removing")
  
  # Random number generation and sampling
  registerNative("randomize", niminiRandomize,
    imports = @["random"],
    description = "Initialize random number generator with current time")
  registerNative("rand", niminiRand,
    imports = @["random"],
    description = "Generate random integer in range [0, max]")
  registerNative("randFloat", niminiRandFloat,
    imports = @["random"],
    description = "Generate random float in range [0.0, 1.0)")
  registerNative("sample", niminiSample,
    imports = @["random"],
    dependencies = @["rand"],
    description = "Randomly sample element from sequence")
  registerNative("choice", niminiChoice,
    imports = @["random"],
    dependencies = @["rand"],
    description = "Randomly choose element from sequence (alias for sample)")
  registerNative("shuffle", niminiShuffle,
    imports = @["random"],
    description = "Randomly shuffle sequence in place")
  
  # Type conversion functions (built-in)
  registerNative("int", niminiToInt,
    description = "Convert value to integer")
  registerNative("float", niminiToFloat,
    description = "Convert value to float")
  registerNative("bool", niminiToBool,
    description = "Convert value to boolean")
  registerNative("str", niminiToString,
    description = "Convert value to string")
  
  # String operations
  registerNative("chr", niminiChr,
    description = "Convert ASCII code to character")
  registerNative("ord", niminiOrd,
    description = "Convert character to ASCII code")
  registerNative("toUpper", niminiToUpper,
    imports = @["strutils"],
    description = "Convert string to uppercase")
  registerNative("toLower", niminiToLower,
    imports = @["strutils"],
    description = "Convert string to lowercase")
  registerNative("startsWith", niminiStartsWith,
    imports = @["strutils"],
    description = "Check if string starts with prefix")
  registerNative("endsWith", niminiEndsWith,
    imports = @["strutils"],
    description = "Check if string ends with suffix")
  registerNative("split", niminiSplit,
    imports = @["strutils"],
    description = "Split string by separator into array")
  registerNative("splitLines", niminiSplitLines,
    imports = @["strutils"],
    description = "Split string by actual newline characters into array")
  registerNative("join", niminiJoin,
    imports = @["strutils"],
    description = "Join array elements with separator")
  registerNative("strip", niminiStrip,
    imports = @["strutils"],
    description = "Remove leading and trailing whitespace")
  registerNative("replace", niminiReplace,
    imports = @["strutils"],
    description = "Replace all occurrences of substring")
  registerNative("findStr", niminiFindStr,
    imports = @["strutils"],
    description = "Find index of substring, returns -1 if not found")
  registerNative("repeat", niminiRepeat,
    imports = @["strutils"],
    description = "Repeat string n times")
  
  # Math functions - trigonometric
  registerNative("sin", niminiSin,
    imports = @["math"],
    description = "Sine function - returns sine of x (x in radians)")
  registerNative("cos", niminiCos,
    imports = @["math"],
    description = "Cosine function - returns cosine of x (x in radians)")
  registerNative("tan", niminiTan,
    imports = @["math"],
    description = "Tangent function - returns tangent of x (x in radians)")
  registerNative("arcsin", niminiArcsin,
    imports = @["math"],
    description = "Arcsine function - returns angle in radians")
  registerNative("arccos", niminiArccos,
    imports = @["math"],
    description = "Arccosine function - returns angle in radians")
  registerNative("arctan", niminiArctan,
    imports = @["math"],
    description = "Arctangent function - returns angle in radians")
  registerNative("arctan2", niminiArctan2,
    imports = @["math"],
    description = "Two-argument arctangent - returns angle in radians")
  
  # Math functions - exponential and logarithmic
  registerNative("sqrt", niminiSqrt,
    imports = @["math"],
    description = "Square root function")
  registerNative("pow", niminiPow,
    imports = @["math"],
    description = "Power function - returns x raised to power y")
  registerNative("exp", niminiExp,
    imports = @["math"],
    description = "Exponential function - returns e^x")
  registerNative("ln", niminiLn,
    imports = @["math"],
    description = "Natural logarithm - base e")
  registerNative("log10", niminiLog10,
    imports = @["math"],
    description = "Common logarithm - base 10")
  registerNative("log2", niminiLog2,
    imports = @["math"],
    description = "Binary logarithm - base 2")
  
  # Math functions - rounding and absolute value
  registerNative("abs", niminiAbs,
    imports = @["math"],
    description = "Absolute value function")
  registerNative("floor", niminiFloor,
    imports = @["math"],
    description = "Floor function - largest integer <= x")
  registerNative("ceil", niminiCeil,
    imports = @["math"],
    description = "Ceiling function - smallest integer >= x")
  registerNative("round", niminiRound,
    imports = @["math"],
    description = "Round to nearest integer")
  registerNative("trunc", niminiTrunc,
    imports = @["math"],
    description = "Truncate to integer (remove decimal part)")
  
  # Math functions - min/max (built-in)
  registerNative("min", niminiMin,
    description = "Return minimum of two values")
  registerNative("max", niminiMax,
    description = "Return maximum of two values")
  
  # Math functions - hyperbolic
  registerNative("sinh", niminiSinh,
    imports = @["math"],
    description = "Hyperbolic sine function")
  registerNative("cosh", niminiCosh,
    imports = @["math"],
    description = "Hyperbolic cosine function")
  registerNative("tanh", niminiTanh,
    imports = @["math"],
    description = "Hyperbolic tangent function")
  
  # Math functions - conversions
  registerNative("degToRad", niminiDegToRad,
    imports = @["math"],
    description = "Convert degrees to radians")
  registerNative("radToDeg", niminiRadToDeg,
    imports = @["math"],
    description = "Convert radians to degrees")

export backend
export nim_backend
export python_backend
export javascript_backend

export frontend
export nim_frontend
# Uncomment to export Python frontend:
# export py_frontend
# Uncomment to export JavaScript frontend:
# export js_frontend
