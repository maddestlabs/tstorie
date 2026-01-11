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
import nimini/stdlib/[seqops, procgen]

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
import nimini/stdlib/[mathops, typeconv, collections, random, stringops, chainable]
export mathops, typeconv, collections, random, stringops, chainable

# Initialize standard library - must be called after initRuntime()
proc initStdlib*() =
  ## Register standard library functions with the runtime
  ## NOTE: Random functions require setNiminiRng() to be called separately
  ##
  ## Uses exportNiminiProcsClean which automatically strips the nimini_ prefix
  ## from all function names when exposing them to scripts.
  
  # All stdlib functions - automatically registered with clean names
  # (e.g., nimini_sin -> "sin", nimini_abs -> "abs")
  exportNiminiProcsClean(
    # Sequence operations
    nimini_add, nimini_len, nimini_newSeq, nimini_setLen,
    nimini_delete, nimini_insert, nimini_pop, nimini_reverse,
    nimini_contains, nimini_findIndex,
    
    # Collection data structures
    nimini_newHashSet, nimini_hashSetIncl, nimini_hashSetExcl,
    nimini_hashSetCard, nimini_hashSetToSeq,
    nimini_newDeque, nimini_dequeAddFirst, nimini_dequeAddLast,
    nimini_dequePopFirst, nimini_dequePopLast,
    nimini_dequePeekFirst, nimini_dequePeekLast,
    
    # Random number generation
    nimini_randomize, nimini_rand, nimini_randFloat,
    nimini_sample, nimini_choice, nimini_shuffle,
    nimini_initRand, nimini_randIsolated, nimini_randFloatIsolated,
    nimini_sampleIsolated, nimini_shuffleIsolated,
    
    # Type conversions
    nimini_toInt, nimini_toFloat, nimini_toBool, nimini_toString,
    
    # String operations
    nimini_chr, nimini_ord, nimini_toUpper, nimini_toLower,
    nimini_startsWith, nimini_endsWith, nimini_split, nimini_splitLines,
    nimini_join, nimini_strip, nimini_replace, nimini_findStr, nimini_repeat,
    
    # Math - trigonometric
    nimini_sin, nimini_cos, nimini_tan,
    nimini_arcsin, nimini_arccos, nimini_arctan, nimini_arctan2,
    
    # Math - exponential and logarithmic
    nimini_sqrt, nimini_pow, nimini_exp, nimini_ln, nimini_log10, nimini_log2,
    
    # Math - rounding and absolute
    nimini_abs, nimini_floor, nimini_ceil, nimini_round, nimini_trunc,
    nimini_min, nimini_max,
    
    # Math - hyperbolic
    nimini_sinh, nimini_cosh, nimini_tanh,
    
    # Math - conversions
    nimini_degToRad, nimini_radToDeg,
    
    # Procedural generation - math
    nimini_idiv, nimini_imod, nimini_iabs, nimini_sign,
    nimini_clamp, nimini_wrap, nimini_lerp, nimini_smoothstep, nimini_map,
    
    # Procedural generation - noise and hash
    nimini_intHash, nimini_intHash2D, nimini_intHash3D,
    nimini_valueNoise2D, nimini_smoothNoise2D, nimini_fractalNoise2D,
    
    # Procedural generation - distance metrics
    nimini_manhattanDist, nimini_chebyshevDist,
    nimini_euclideanDist, nimini_euclideanDistSq,
    
    # Procedural generation - patterns
    nimini_checkerboard, nimini_stripes,
    nimini_concentricCircles, nimini_spiralPattern,
    
    # Procedural generation - easing
    nimini_easeLinear, nimini_easeInQuad, nimini_easeOutQuad,
    nimini_easeInOutQuad, nimini_easeInCubic, nimini_easeOutCubic,
    
    # Procedural generation - grid utilities
    nimini_inBounds,
    
    # Shader primitives - trigonometry
    nimini_isin, nimini_icos,
    
    # Shader primitives - polar coordinates
    nimini_polarDistance, nimini_polarAngle,
    
    # Shader primitives - wave operations
    nimini_waveAdd, nimini_waveMultiply, nimini_waveMix,
    
    # Shader primitives - color palettes
    nimini_colorHeatmap, nimini_colorPlasma, nimini_colorCoolWarm,
    nimini_colorFire, nimini_colorOcean, nimini_colorNeon,
    nimini_colorMatrix, nimini_colorGrayscale,
    
    # Chainable array operations (UFCS support) - use "Arr" suffix to avoid conflicts
    nimini_filterArr, nimini_mapArr, nimini_sortedArr, nimini_reversedArr,
    nimini_takeArr, nimini_dropArr, nimini_sumArr, nimini_firstArr, nimini_lastArr,
    nimini_uniqueArr, nimini_countArr, nimini_anyArr, nimini_allArr,
    
    # Chainable string operations - use "Str" suffix
    nimini_trimStr, nimini_concatStr
  )
  
  # Note: Metadata (imports, descriptions) has been removed for brevity
  # It can be re-added later as pragma parameters when we enhance the macro
  # For now, the metadata remains in source code but isn't used during registration

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
