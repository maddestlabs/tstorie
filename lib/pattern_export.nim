## ASCII Art Pattern Export System
##
## Analyzes nimini scripts using the ascii_art library and generates
## compiled Nim modules following the Rebuild Pattern.
##
## This module extends nim_export.nim with pattern-specific analysis.

import tables, sets, strutils, sequtils
import storie_types, storie_md, nim_export
import ../nimini/ast

type
  PatternType* = enum
    ptBorder      ## Border/frame patterns
    ptFill        ## Fill/texture patterns
    ptDecoration  ## Decorative details
    ptAnimation   ## Animated patterns
    ptGeneric     ## Generic pattern
  
  PatternExportMetadata* = object
    ## Metadata extracted from pattern prototype
    name*: string                 # Module/type name (e.g., "CrackedBorder")
    patternType*: PatternType     # Type of pattern
    seed*: int                    # Seed value for reproducibility
    description*: string          # Pattern description
    category*: string             # Category (e.g., "borders", "weathered")
    
    # Extracted pattern configuration
    patternFuncCalls*: seq[string]   # Calls to pattern creation functions
    borderCorners*: array[4, string] # Corner characters if applicable
    crackDetails*: seq[string]       # Detail additions
    
    # Variable dependencies
    usesTermWidth*: bool          # Pattern uses terminal width
    usesTermHeight*: bool         # Pattern uses terminal height
    userVariables*: seq[string]   # User-defined variables used

proc extractPatternMetadata*(md: MarkdownDoc, frontMatter: FrontMatter): PatternExportMetadata =
  ## Extract pattern export metadata from markdown document
  result = PatternExportMetadata()
  
  # Extract from front matter
  if frontMatter.hasKey("export.name"):
    result.name = frontMatter["export.name"]
  elif frontMatter.hasKey("title"):
    # Generate name from title
    result.name = frontMatter["title"].replace(" ", "").replace("-", "")
  
  if frontMatter.hasKey("export.seed"):
    try:
      result.seed = parseInt(frontMatter["export.seed"])
    except:
      result.seed = 42  # Default seed
  
  if frontMatter.hasKey("export.type"):
    case frontMatter["export.type"]
    of "border", "ascii-pattern": result.patternType = ptBorder
    of "fill": result.patternType = ptFill
    of "decoration": result.patternType = ptDecoration
    of "animation": result.patternType = ptAnimation
    else: result.patternType = ptGeneric
  
  if frontMatter.hasKey("export.description"):
    result.description = frontMatter["export.description"]
  
  if frontMatter.hasKey("export.category"):
    result.category = frontMatter["export.category"]

proc analyzePatternCode*(ast: Program, metadata: var PatternExportMetadata) =
  ## Analyze nimini AST to extract pattern usage information
  
  proc analyzeExpr(expr: Expr) =
    if expr.isNil:
      return
    
    case expr.kind
    of ekCall:
      # Track pattern function calls
      case expr.funcName
      of "crackedBorderPattern", "simpleBorderPattern", "moduloPattern", "moduloPatternV":
        metadata.patternFuncCalls.add(expr.funcName)
      of "getBorderCorners":
        if expr.args.len > 0 and expr.args[0].kind == ekString:
          # Extract corner style
          discard
      of "addDetail", "generateCracks":
        metadata.crackDetails.add(expr.funcName)
      else:
        discard
      
      # Recursively analyze arguments
      for arg in expr.args:
        analyzeExpr(arg)
    
    of ekBinOp:
      analyzeExpr(expr.left)
      analyzeExpr(expr.right)
    
    of ekUnaryOp:
      analyzeExpr(expr.unaryExpr)
    
    of ekIndex:
      analyzeExpr(expr.indexTarget)
      analyzeExpr(expr.indexExpr)
    
    of ekDot:
      analyzeExpr(expr.dotTarget)
    
    of ekArray:
      for elem in expr.elements:
        analyzeExpr(elem)
    
    of ekIdent:
      # Check for terminal dimensions
      if expr.identName == "termWidth":
        metadata.usesTermWidth = true
      elif expr.identName == "termHeight":
        metadata.usesTermHeight = true
    
    else:
      discard
  
  proc analyzeStmt(stmt: Stmt) =
    if stmt.isNil:
      return
    
    case stmt.kind
    of skVarDecl:
      # Track user variables (pattern configuration)
      if stmt.varName notin ["w", "h", "termWidth", "termHeight"]:
        if stmt.varName notin metadata.userVariables:
          metadata.userVariables.add(stmt.varName)
      
      analyzeExpr(stmt.varValue)
    
    of skAssign:
      analyzeExpr(stmt.assignValue)
    
    of skExpr:
      analyzeExpr(stmt.expr)
    
    of skIf:
      analyzeExpr(stmt.ifCondition)
      for s in stmt.ifBody:
        analyzeStmt(s)
      for elifBranch in stmt.elifBranches:
        analyzeExpr(elifBranch.condition)
        for s in elifBranch.body:
          analyzeStmt(s)
      for s in stmt.elseBody:
        analyzeStmt(s)
    
    of skWhile:
      analyzeExpr(stmt.whileCondition)
      for s in stmt.whileBody:
        analyzeStmt(s)
    
    of skFor:
      analyzeExpr(stmt.forStart)
      analyzeExpr(stmt.forEnd)
      for s in stmt.forBody:
        analyzeStmt(s)
    
    of skProc:
      for s in stmt.procBody:
        analyzeStmt(s)
    
    of skReturn:
      analyzeExpr(stmt.returnValue)
    
    else:
      discard
  
  # Analyze all statements in the program
  for stmt in ast.stmts:
    analyzeStmt(stmt)

proc generatePatternModule*(metadata: PatternExportMetadata): string =
  ## Generate a compiled Nim module from pattern metadata
  
  let typeName = metadata.name
  let description = if metadata.description != "": metadata.description 
                    else: "Procedural ASCII art pattern"
  
  result = &"""## {typeName} - Compiled ASCII Art Pattern
##
## {description}
##
## Generated from tStorie prototype using the Rebuild Pattern.
## Seed: {metadata.seed}

import std/[tables, random]
import ../ascii_art

when not declared(Style):
  import ../../src/types

type
  {typeName}* = ref object
    seed*: int
    topPattern*: PatternFunc
    bottomPattern*: PatternFunc
    leftPattern*: PatternFunc
    rightPattern*: PatternFunc
    corners*: array[4, string]

proc new{typeName}*(seed: int = {metadata.seed}): {typeName} =
  ## Create a new {typeName} pattern with specified seed
  result = {typeName}(seed: seed)
  setSeedIfNeeded(seed)
  
  # Generate patterns (compiled from prototype)
  let patterns = crackedBorderPattern(seed)
  result.topPattern = patterns.top
  result.bottomPattern = patterns.bottom
  result.leftPattern = patterns.left
  result.rightPattern = patterns.right
  result.corners = ["╔", "╗", "╚", "╝"]

proc render*(p: {typeName}, layer: int, x, y, width, height: int,
            style: Style, drawProc: proc(layer, x, y: int, char: string, style: Style)) =
  ## Render the pattern to a buffer
  drawBorder(layer, x, y, width, height,
             p.topPattern, p.bottomPattern,
             p.leftPattern, p.rightPattern,
             p.corners, style, drawProc)

proc renderFull*(p: {typeName}, layer: int, termWidth, termHeight: int,
                style: Style, drawProc: proc(layer, x, y: int, char: string, style: Style)) =
  ## Render the pattern filling the entire terminal
  drawBorder(layer, 0, 0, termWidth, termHeight,
             p.topPattern, p.bottomPattern,
             p.leftPattern, p.rightPattern,
             p.corners, style, drawProc)

# Export pattern configuration for regeneration
proc getConfig*(p: {typeName}): tuple[seed: int, name: string] =
  return (p.seed, "{typeName}")
"""
  
  return result

proc generateNiminiBindings*(typeName: string): string =
  ## Generate nimini bindings for the compiled pattern module
  
  result = &"""## Nimini bindings for {typeName}
##
## Auto-generated bindings to expose compiled pattern to scripts

import ../nimini
import ../nimini/runtime
import {typeName.toLowerAscii()}

proc nimini_new{typeName}*(env: ref Env; args: seq[Value]): Value {{.nimini.}} =
  ## Create a new {typeName} instance. Args: seed (int, optional)
  let seed = if args.len > 0 and args[0].kind == vkInt: args[0].i else: {typeName.toLowerAscii()}.DEFAULT_SEED
  let instance = new{typeName}(seed)
  
  # Store as pointer (pattern instances are ref objects)
  return valPointer(cast[pointer](instance))

proc nimini_{typeName}_render*(env: ref Env; args: seq[Value]): Value {{.nimini.}} =
  ## Render pattern. Args: pattern (ptr), layer (int), x (int), y (int), width (int), height (int), style (style)
  if args.len < 7:
    return valNil()
  
  let pattern = cast[{typeName}](args[0].p)
  let layer = args[1].i
  let x = args[2].i
  let y = args[3].i
  let width = args[4].i
  let height = args[5].i
  # let style = ... convert from Value
  
  # TODO: Get draw proc from environment
  # pattern.render(layer, x, y, width, height, style, drawProc)
  
  return valNil()

proc register{typeName}Bindings*() =
  ## Register bindings with nimini runtime
  registerNative("new{typeName}", nimini_new{typeName},
    storieLibs = @["ascii_art", "{metadata.category}"],
    description = "Create {typeName} pattern (compiled, seed={metadata.seed})")
  
  registerNative("{typeName}_render", nimini_{typeName}_render,
    storieLibs = @["ascii_art", "{metadata.category}"],
    description = "Render {typeName} pattern")

export register{typeName}Bindings
"""
  
  return result

proc exportPatternModule*(mdPath: string, outputDir: string = "lib/ascii_art/exported/"): bool =
  ## Main export function - analyzes a markdown pattern and generates module
  ## Returns true on success
  
  # TODO: Implement full export pipeline:
  # 1. Parse markdown document
  # 2. Extract pattern metadata from front matter
  # 3. Parse and analyze nimini code blocks
  # 4. Generate compiled module
  # 5. Generate nimini bindings
  # 6. Write files to output directory
  # 7. Update registry/index
  
  echo "Pattern export from: ", mdPath
  echo "Output directory: ", outputDir
  echo "This will be implemented to complete the Rebuild Pattern workflow"
  
  return true

# Export main functions
export PatternType, PatternExportMetadata
export extractPatternMetadata, analyzePatternCode
export generatePatternModule, generateNiminiBindings
export exportPatternModule
