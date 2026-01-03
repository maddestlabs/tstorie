## Nim Export Module
##
## Analyzes tStorie code blocks and generates fully compilable native Nim programs.
## This enables the transition from rapid prototyping to optimized native executables.
##
## NOW USES METADATA SYSTEM: Functions self-describe their import requirements
## via registration metadata instead of lookup tables.

import tables, sets, strutils, sequtils, algorithm
import storie_types, storie_md
import ../nimini
import ../nimini/ast
import ../nimini/runtime  # Access to gFunctionMetadata

type
  ImportInfo* = object
    ## Tracks all required imports for code export
    stdLibImports*: HashSet[string]      # Nim standard library: math, strutils, etc.
    storieLibImports*: HashSet[string]   # tStorie lib modules: canvas, layout, etc.
    customImports*: HashSet[string]      # User-defined imports from code
  
  ExportContext* = object
    ## Complete context for exporting tStorie code to native Nim
    imports*: ImportInfo
    globalVars*: Table[string, string]   # name -> declaration
    procedures*: seq[string]             # Extracted proc definitions (Phase 3)
    initCode*: seq[string]               # Code from on:init blocks
    updateCode*: seq[string]             # Code from on:update blocks  
    renderCode*: seq[string]             # Code from on:render blocks
    inputCode*: seq[string]              # Code from on:input blocks
    shutdownCode*: seq[string]           # Code from on:shutdown blocks
    functions*: Table[string, string]    # name -> full function definition
    errors*: seq[string]                 # Collection of export errors/warnings

# ==============================================================================
# METADATA-BASED IMPORT DETECTION
# ==============================================================================
# No more lookup tables! Functions now self-describe their requirements.
# ==============================================================================

# Forward declaration for mutual recursion
proc analyzeStatement(stmt: Stmt, imports: var ImportInfo)

proc analyzeExpression(expr: Expr, imports: var ImportInfo) =
  ## Recursively analyze expressions and gather imports from metadata
  ## NO MORE LOOKUP TABLES - functions self-describe their requirements!
  if expr.isNil:
    return
  
  case expr.kind
  of ekCall:
    # Simply look up the function's metadata!
    if gFunctionMetadata.hasKey(expr.funcName):
      let meta = gFunctionMetadata[expr.funcName]
      
      # Add stdlib imports
      for imp in meta.imports:
        imports.stdLibImports.incl(imp)
      
      # Add tStorie lib imports
      for lib in meta.storieLibs:
        imports.storieLibImports.incl(lib)
      
      # Recursively resolve dependencies
      for dep in meta.dependencies:
        if gFunctionMetadata.hasKey(dep):
          let depMeta = gFunctionMetadata[dep]
          for imp in depMeta.imports:
            imports.stdLibImports.incl(imp)
          for lib in depMeta.storieLibs:
            imports.storieLibImports.incl(lib)
    
    # Analyze arguments
    for arg in expr.args:
      analyzeExpression(arg, imports)
  
  of ekBinOp:
    analyzeExpression(expr.left, imports)
    analyzeExpression(expr.right, imports)
  
  of ekUnaryOp:
    analyzeExpression(expr.unaryExpr, imports)
  
  of ekIndex:
    analyzeExpression(expr.indexTarget, imports)
    analyzeExpression(expr.indexExpr, imports)
  
  of ekDot:
    analyzeExpression(expr.dotTarget, imports)
  
  of ekArray:
    for elem in expr.elements:
      analyzeExpression(elem, imports)
  
  of ekTuple:
    if expr.isNamedTuple:
      for field in expr.tupleFields:
        analyzeExpression(field.value, imports)
    else:
      for elem in expr.tupleElements:
        analyzeExpression(elem, imports)
  
  of ekObjConstr:
    for field in expr.objFields:
      analyzeExpression(field.value, imports)
  
  of ekCast:
    analyzeExpression(expr.castExpr, imports)
  
  of ekAddr:
    analyzeExpression(expr.addrExpr, imports)
  
  of ekDeref:
    analyzeExpression(expr.derefExpr, imports)
  
  of ekLambda:
    for stmt in expr.lambdaBody:
      analyzeStatement(stmt, imports)
  
  of ekMap:
    for pair in expr.mapPairs:
      analyzeExpression(pair.value, imports)
  
  else:
    # Literals: ekInt, ekFloat, ekString, ekBool, ekIdent
    discard

proc analyzeStatement(stmt: Stmt, imports: var ImportInfo) =
  ## Analyze a statement node for function calls and imports
  if stmt.isNil:
    return
  
  case stmt.kind
  of skVar:
    if not stmt.varValue.isNil:
      analyzeExpression(stmt.varValue, imports)
  
  of skLet:
    if not stmt.letValue.isNil:
      analyzeExpression(stmt.letValue, imports)
  
  of skConst:
    if not stmt.constValue.isNil:
      analyzeExpression(stmt.constValue, imports)
  
  of skAssign:
    analyzeExpression(stmt.assignTarget, imports)
    analyzeExpression(stmt.assignValue, imports)
  
  of skExpr:
    analyzeExpression(stmt.expr, imports)
  
  of skIf:
    analyzeExpression(stmt.ifBranch.cond, imports)
    for s in stmt.ifBranch.stmts:
      analyzeStatement(s, imports)
    for elifBranch in stmt.elifBranches:
      analyzeExpression(elifBranch.cond, imports)
      for s in elifBranch.stmts:
        analyzeStatement(s, imports)
    if stmt.elseStmts.len > 0:
      for s in stmt.elseStmts:
        analyzeStatement(s, imports)
  
  of skCase:
    analyzeExpression(stmt.caseExpr, imports)
    for branch in stmt.ofBranches:
      for value in branch.values:
        analyzeExpression(value, imports)
      for s in branch.stmts:
        analyzeStatement(s, imports)
    for elifBranch in stmt.caseElif:
      analyzeExpression(elifBranch.cond, imports)
      for s in elifBranch.stmts:
        analyzeStatement(s, imports)
    if stmt.caseElse.len > 0:
      for s in stmt.caseElse:
        analyzeStatement(s, imports)
  
  of skWhile:
    analyzeExpression(stmt.whileCond, imports)
    for s in stmt.whileBody:
      analyzeStatement(s, imports)
  
  of skFor:
    analyzeExpression(stmt.forIterable, imports)
    for s in stmt.forBody:
      analyzeStatement(s, imports)
  
  of skProc:
    for s in stmt.body:
      analyzeStatement(s, imports)
  
  of skReturn:
    if not stmt.returnVal.isNil:
      analyzeExpression(stmt.returnVal, imports)
  
  of skBlock:
    for s in stmt.stmts:
      analyzeStatement(s, imports)
  
  of skDefer:
    analyzeStatement(stmt.deferStmt, imports)
  
  else:
    # skType, skBreak, skContinue
    discard

proc analyzeCodeBlock*(codeBlock: CodeBlock): ImportInfo =
  ## Analyze a single code block to determine required imports
  result.stdLibImports = initHashSet[string]()
  result.storieLibImports = initHashSet[string]()
  result.customImports = initHashSet[string]()
  
  # Parse the code using nimini
  try:
    let tokens = tokenizeDsl(codeBlock.code)
    let program = parseDsl(tokens)
    
    # Analyze each statement in the program
    for stmt in program.stmts:
      analyzeStatement(stmt, result)
  except:
    # If parsing fails, we can't determine imports from this block
    discard

proc analyzeCodeBlocks*(codeBlocks: seq[CodeBlock]): ImportInfo =
  ## Analyze all code blocks and aggregate import requirements
  result.stdLibImports = initHashSet[string]()
  result.storieLibImports = initHashSet[string]()
  result.customImports = initHashSet[string]()
  
  for codeBlock in codeBlocks:
    let blockImports = analyzeCodeBlock(codeBlock)
    result.stdLibImports = result.stdLibImports + blockImports.stdLibImports
    result.storieLibImports = result.storieLibImports + blockImports.storieLibImports
    result.customImports = result.customImports + blockImports.customImports

# ==============================================================================
# Variable Scope Analysis (Phase 2)
# ==============================================================================

type
  VariableInfo* = object
    name*: string
    declaredIn*: string              # Which lifecycle block it was declared in
    usedIn*: HashSet[string]         # Which lifecycle blocks use it
    isGlobal*: bool                  # Should be promoted to global
    declaration*: string             # The actual var/let declaration

  ScopeAnalysis* = object
    variables*: Table[string, VariableInfo]
    globals*: seq[string]            # Variables that must be global
    locals*: Table[string, seq[string]]  # Locals per lifecycle

proc extractVarName(stmt: Stmt): string =
  ## Extract variable name from var/let declaration
  if stmt.kind == skVar:
    if stmt.isVarUnpack:
      # Tuple unpacking - take first name for now
      if stmt.varNames.len > 0:
        return stmt.varNames[0]
    else:
      return stmt.varName
  elif stmt.kind == skLet:
    if stmt.isLetUnpack:
      if stmt.letNames.len > 0:
        return stmt.letNames[0]
    else:
      return stmt.letName
  return ""

proc extractDeclaredVars(stmt: Stmt, vars: var HashSet[string]) =
  ## Extract all variable names declared in a statement
  if stmt.kind == skVar:
    if stmt.isVarUnpack:
      for name in stmt.varNames:
        vars.incl(name)
    else:
      vars.incl(stmt.varName)
  elif stmt.kind == skLet:
    if stmt.isLetUnpack:
      for name in stmt.letNames:
        vars.incl(name)
    else:
      vars.incl(stmt.letName)
  elif stmt.kind == skConst:
    vars.incl(stmt.constName)

proc extractUsedVars(expr: Expr, vars: var HashSet[string]) =
  ## Extract all variable names used in an expression
  if expr.isNil:
    return
  
  case expr.kind
  of ekIdent:
    vars.incl(expr.ident)
  of ekCall:
    for arg in expr.args:
      extractUsedVars(arg, vars)
  of ekBinOp:
    extractUsedVars(expr.left, vars)
    extractUsedVars(expr.right, vars)
  of ekUnaryOp:
    extractUsedVars(expr.unaryExpr, vars)
  of ekIndex:
    extractUsedVars(expr.indexTarget, vars)
    extractUsedVars(expr.indexExpr, vars)
  of ekDot:
    extractUsedVars(expr.dotTarget, vars)
  of ekArray:
    for elem in expr.elements:
      extractUsedVars(elem, vars)
  of ekTuple:
    if expr.isNamedTuple:
      for field in expr.tupleFields:
        extractUsedVars(field.value, vars)
    else:
      for elem in expr.tupleElements:
        extractUsedVars(elem, vars)
  of ekObjConstr:
    for field in expr.objFields:
      extractUsedVars(field.value, vars)
  of ekCast:
    extractUsedVars(expr.castExpr, vars)
  of ekAddr:
    extractUsedVars(expr.addrExpr, vars)
  of ekDeref:
    extractUsedVars(expr.derefExpr, vars)
  of ekMap:
    for pair in expr.mapPairs:
      extractUsedVars(pair.value, vars)
  else:
    discard

proc extractUsedVarsFromStmt(stmt: Stmt, used: var HashSet[string]) =
  ## Extract all variables used in a statement (not declared)
  if stmt.isNil:
    return
  
  case stmt.kind
  of skVar:
    if not stmt.varValue.isNil:
      extractUsedVars(stmt.varValue, used)
  of skLet:
    if not stmt.letValue.isNil:
      extractUsedVars(stmt.letValue, used)
  of skConst:
    if not stmt.constValue.isNil:
      extractUsedVars(stmt.constValue, used)
  of skAssign:
    extractUsedVars(stmt.assignTarget, used)
    extractUsedVars(stmt.assignValue, used)
  of skExpr:
    extractUsedVars(stmt.expr, used)
  of skIf:
    extractUsedVars(stmt.ifBranch.cond, used)
    for s in stmt.ifBranch.stmts:
      extractUsedVarsFromStmt(s, used)
    for elifBranch in stmt.elifBranches:
      extractUsedVars(elifBranch.cond, used)
      for s in elifBranch.stmts:
        extractUsedVarsFromStmt(s, used)
    for s in stmt.elseStmts:
      extractUsedVarsFromStmt(s, used)
  of skCase:
    extractUsedVars(stmt.caseExpr, used)
    for branch in stmt.ofBranches:
      for value in branch.values:
        extractUsedVars(value, used)
      for s in branch.stmts:
        extractUsedVarsFromStmt(s, used)
    for elifBranch in stmt.caseElif:
      extractUsedVars(elifBranch.cond, used)
      for s in elifBranch.stmts:
        extractUsedVarsFromStmt(s, used)
    for s in stmt.caseElse:
      extractUsedVarsFromStmt(s, used)
  of skWhile:
    extractUsedVars(stmt.whileCond, used)
    for s in stmt.whileBody:
      extractUsedVarsFromStmt(s, used)
  of skFor:
    extractUsedVars(stmt.forIterable, used)
    for s in stmt.forBody:
      extractUsedVarsFromStmt(s, used)
  of skReturn:
    if not stmt.returnVal.isNil:
      extractUsedVars(stmt.returnVal, used)
  of skBlock:
    for s in stmt.stmts:
      extractUsedVarsFromStmt(s, used)
  of skDefer:
    extractUsedVarsFromStmt(stmt.deferStmt, used)
  else:
    discard

proc analyzeVariableScopes*(doc: MarkdownDocument): ScopeAnalysis =
  ## Analyze variable declarations and usage across lifecycle blocks
  ## Determines which variables need to be global vs local
  result.variables = initTable[string, VariableInfo]()
  result.globals = @[]
  result.locals = initTable[string, seq[string]]()
  
  # Track declarations and usage per lifecycle
  for codeBlock in doc.codeBlocks:
    let lifecycle = if codeBlock.lifecycle.len > 0: codeBlock.lifecycle else: "init"
    
    # Parse the code block
    try:
      let tokens = tokenizeDsl(codeBlock.code)
      let program = parseDsl(tokens)
      
      # Find all declared variables in this block
      var declared = initHashSet[string]()
      var used = initHashSet[string]()
      
      for stmt in program.stmts:
        extractDeclaredVars(stmt, declared)
        extractUsedVarsFromStmt(stmt, used)
      
      # Record declarations
      for varName in declared:
        if not result.variables.hasKey(varName):
          result.variables[varName] = VariableInfo(
            name: varName,
            declaredIn: lifecycle,
            usedIn: initHashSet[string](),
            isGlobal: false,
            declaration: ""
          )
        result.variables[varName].usedIn.incl(lifecycle)
      
      # Record usage (variables used but not declared here)
      for varName in used:
        if result.variables.hasKey(varName):
          result.variables[varName].usedIn.incl(lifecycle)
        # Note: If not in variables table, it might be a function or builtin
    except:
      # If parsing fails, skip this block
      discard
  
  # Determine which variables must be global
  # A variable is global if:
  # 1. It's declared in one lifecycle and used in another, OR
  # 2. It's used in multiple lifecycle blocks
  for varName, info in result.variables:
    if info.usedIn.len > 1:
      # Used in multiple lifecycles - must be global
      result.variables[varName].isGlobal = true
      result.globals.add(varName)
    elif info.declaredIn != "" and info.usedIn.len > 0:
      # Check if used in different lifecycle than declared
      var usedElsewhere = false
      for lifecycle in info.usedIn:
        if lifecycle != info.declaredIn:
          usedElsewhere = true
          break
      if usedElsewhere:
        result.variables[varName].isGlobal = true
        result.globals.add(varName)

# ==============================================================================
# Code Export with Scope Analysis
# ==============================================================================

proc removeVarDeclForGlobals(code: string, globals: HashSet[string]): string =
  ## Remove 'var' and 'let' keywords for global variables, converting them to assignments
  ## This is a simple text-based approach - could be improved with AST manipulation
  result = code
  
  # Simple regex-like replacements for common patterns
  # This is a basic implementation - Phase 3 would do this properly with AST
  for varName in globals:
    # Pattern: var varName = value -> varName = value
    result = result.replace("var " & varName & " =", varName & " =")
    result = result.replace("let " & varName & " =", varName & " =")
    # Pattern: var varName: Type = value -> varName = value
    result = result.replace("var " & varName & ":", varName & " =").replace(": auto =", " =")

# ==============================================================================
# Function Extraction (Phase 3)
# ==============================================================================

proc formatProcParam(param: ProcParam): string =
  ## Format a procedure parameter for Nim code
  result = ""
  if param.isVar:
    result.add("var ")
  result.add(param.name)
  if param.paramType.len > 0:
    result.add(": " & param.paramType)

proc formatTypeNode(typeNode: TypeNode): string =
  ## Format a TypeNode to string for Nim code
  if typeNode.isNil:
    return ""
  
  case typeNode.kind
  of tkSimple:
    return typeNode.typeName
  of tkPointer:
    return "ptr " & formatTypeNode(typeNode.ptrType)
  of tkGeneric:
    result = typeNode.genericName & "["
    for i, param in typeNode.genericParams:
      if i > 0: result.add(", ")
      result.add(formatTypeNode(param))
    result.add("]")
  of tkProc:
    result = "proc("
    for i, param in typeNode.procParams:
      if i > 0: result.add(", ")
      result.add(formatTypeNode(param))
    result.add(")")
    if not typeNode.procReturn.isNil:
      result.add(": " & formatTypeNode(typeNode.procReturn))
  else:
    return "auto"  # Fallback for complex types

proc extractProcedures*(code: string): seq[string] =
  ## Extract all proc definitions from code
  ## Returns list of complete proc definitions as strings
  result = @[]
  
  try:
    let tokens = tokenizeDsl(code)
    let program = parseDsl(tokens)
    
    for stmt in program.stmts:
      if stmt.kind == skProc:
        # Find the proc in the original code and extract it completely
        let procStart = code.find("proc " & stmt.procName)
        if procStart >= 0:
          # Find the end of the proc
          # Strategy: find the '=' then keep going until we hit unindented content
          var procEnd = code.len - 1
          var foundEquals = false
          var inProcBody = false
          var lastNonEmptyLine = procStart
          
          var i = procStart
          while i < code.len:
            let ch = code[i]
            
            if ch == '=' and not foundEquals:
              foundEquals = true
              inProcBody = true
            elif inProcBody:
              # Track the last position that's part of the proc
              if ch notin {'\n', '\r'}:
                lastNonEmptyLine = i
              
              # Check if we've hit a newline
              if ch == '\n' and i + 1 < code.len:
                # Look at the next line to see if it's unindented
                var j = i + 1
                # Skip any blank lines
                while j < code.len and code[j] in {'\n', '\r'}:
                  j.inc()
                
                if j < code.len:
                  # Check if next line starts with non-whitespace (and isn't just a blank line)
                  if code[j] notin {' ', '\t', '\n', '\r'}:
                    # We've hit unindented content - end of proc
                    procEnd = lastNonEmptyLine
                    break
            
            i.inc()
          
          # Extract the proc definition
          if procEnd > procStart:
            let procDef = code[procStart..procEnd].strip()
            if procDef.len > 0:
              result.add(procDef)
  except:
    # If parsing fails, can't extract procs
    discard

proc removeProcedures*(code: string, procNames: HashSet[string]): string =
  ## Remove proc definitions from code, leaving only calls
  ## This is a simplified text-based approach for Phase 3
  result = ""
  let lines = code.split('\n')
  var i = 0
  
  while i < lines.len:
    let line = lines[i]
    var skipProc = false
    
    # Check if this line starts a proc definition
    if line.strip().startsWith("proc "):
      # Extract proc name
      let parts = line.strip().split({'(', ' ', '\t'})
      if parts.len >= 2:
        let procName = parts[1].strip()
        if procName in procNames:
          skipProc = true
          # Skip until we find the end of the proc
          i.inc()
          while i < lines.len:
            let nextLine = lines[i]
            # End when we hit non-indented content or empty line followed by non-indented
            if nextLine.strip().len == 0:
              if i + 1 < lines.len and lines[i+1].len > 0 and lines[i+1][0] notin {' ', '\t'}:
                i.inc()
                break
            elif nextLine.len > 0 and nextLine[0] notin {' ', '\t'}:
              break
            i.inc()
          continue
    
    if not skipProc:
      result.add(line & "\n")
    
    i.inc()
  
  result = result.strip()

# ==============================================================================
# Optimization Passes (Phase 5)
# ==============================================================================

type
  OptimizationStats* = object
    unusedVarsRemoved*: int
    constantsFolded*: int
    deadCodeLinesRemoved*: int
    importsOptimized*: int

proc findUnusedVariables*(code: string, declaredVars: HashSet[string]): HashSet[string] =
  ## Find variables that are declared but never used
  result = initHashSet[string]()
  
  try:
    let tokens = tokenizeDsl(code)
    let program = parseDsl(tokens)
    
    # Track which variables are actually used (referenced)
    var usedVars = initHashSet[string]()
    
    proc collectUsedVars(expr: Expr) =
      if expr.isNil: return
      case expr.kind
      of ekIdent:
        usedVars.incl(expr.ident)
      of ekCall:
        for arg in expr.args:
          collectUsedVars(arg)
      of ekBinOp:
        collectUsedVars(expr.left)
        collectUsedVars(expr.right)
      of ekUnaryOp:
        collectUsedVars(expr.unaryExpr)
      of ekIndex:
        collectUsedVars(expr.indexTarget)
        collectUsedVars(expr.indexExpr)
      of ekDot:
        collectUsedVars(expr.indexTarget)
      else:
        discard
    
    proc scanStatement(stmt: Stmt) =
      case stmt.kind
      of skVar:
        # Don't count the variable being declared as "used"
        if not stmt.isVarUnpack:
          collectUsedVars(stmt.varValue)
      of skAssign:
        collectUsedVars(stmt.assignValue)
      of skIf:
        collectUsedVars(stmt.ifBranch.cond)
        for s in stmt.ifBranch.stmts:
          scanStatement(s)
        for branch in stmt.elifBranches:
          collectUsedVars(branch.cond)
          for s in branch.stmts:
            scanStatement(s)
        for s in stmt.elseStmts:
          scanStatement(s)
      of skWhile:
        collectUsedVars(stmt.whileCond)
        for s in stmt.whileBody:
          scanStatement(s)
      of skFor:
        collectUsedVars(stmt.forIterable)
        for s in stmt.forBody:
          scanStatement(s)
      of skReturn:
        collectUsedVars(stmt.returnVal)
      of skExpr:
        collectUsedVars(stmt.expr)
      else:
        discard
    
    for stmt in program.stmts:
      scanStatement(stmt)
    
    # Variables that are declared but never referenced
    for varName in declaredVars:
      if varName notin usedVars:
        result.incl(varName)
  except:
    # If analysis fails, don't mark anything as unused
    discard

proc removeUnusedVariables*(code: string, unusedVars: HashSet[string]): string =
  ## Remove declarations of unused variables
  if unusedVars.len == 0:
    return code
  
  result = ""
  for line in code.split('\n'):
    var skipLine = false
    let trimmed = line.strip()
    
    # Check if this line declares an unused variable
    if trimmed.startsWith("var ") or trimmed.startsWith("let "):
      for varName in unusedVars:
        if trimmed.contains(" " & varName & " =") or 
           trimmed.contains(" " & varName & ":") or
           trimmed.endsWith(" " & varName):
          skipLine = true
          break
    
    if not skipLine:
      result.add(line & "\n")
  
  result = result.strip()

proc foldConstants*(code: string): tuple[code: string, folded: int] =
  ## Perform constant folding on simple expressions
  ## This is a basic implementation - proper AST-based folding would be more comprehensive
  result.code = code
  result.folded = 0
  
  # Simple patterns to fold
  let patterns = [
    (r"(\d+)\s*\+\s*(\d+)", proc(a, b: int): string = $(a + b)),
    (r"(\d+)\s*-\s*(\d+)", proc(a, b: int): string = $(a - b)),
    (r"(\d+)\s*\*\s*(\d+)", proc(a, b: int): string = $(a * b)),
  ]
  
  # Note: This is a simplified example
  # Full implementation would use AST transformation
  result.code = code

proc optimizeImports*(ctx: var ExportContext): int =
  ## Remove unused imports by checking which functions are actually called
  ## Returns number of imports removed
  result = 0
  
  # Build set of all function calls in the code
  var calledFunctions = initHashSet[string]()
  
  proc extractCalls(code: string) =
    try:
      let tokens = tokenizeDsl(code)
      let program = parseDsl(tokens)
      
      proc collectCalls(expr: Expr) =
        if expr.isNil: return
        case expr.kind
        of ekCall:
          calledFunctions.incl(expr.funcName)
          for arg in expr.args:
            collectCalls(arg)
        of ekBinOp:
          collectCalls(expr.left)
          collectCalls(expr.right)
        of ekUnaryOp:
          collectCalls(expr.unaryExpr)
        else:
          discard
      
      proc scanStmt(stmt: Stmt) =
        case stmt.kind
        of skVar:
          collectCalls(stmt.varValue)
        of skAssign:
          collectCalls(stmt.assignValue)
        of skExpr:
          collectCalls(stmt.expr)
        of skIf:
          collectCalls(stmt.ifBranch.cond)
          for s in stmt.ifBranch.stmts:
            scanStmt(s)
          for branch in stmt.elifBranches:
            collectCalls(branch.cond)
            for s in branch.stmts:
              scanStmt(s)
          for s in stmt.elseStmts:
            scanStmt(s)
        of skWhile:
          collectCalls(stmt.whileCond)
          for s in stmt.whileBody:
            scanStmt(s)
        else:
          discard
      
      for stmt in program.stmts:
        scanStmt(stmt)
    except:
      discard
  
  # Scan all code sections
  for code in ctx.initCode:
    extractCalls(code)
  for code in ctx.updateCode:
    extractCalls(code)
  for code in ctx.renderCode:
    extractCalls(code)
  for code in ctx.inputCode:
    extractCalls(code)
  for code in ctx.shutdownCode:
    extractCalls(code)
  
  # Check which imports are actually needed
  var neededStdLib = initHashSet[string]()
  var neededStorieLib = initHashSet[string]()
  
  for funcName in calledFunctions:
    if gFunctionMetadata.hasKey(funcName):
      let meta = gFunctionMetadata[funcName]
      for imp in meta.imports:
        neededStdLib.incl(imp)
      for lib in meta.storieLibs:
        neededStorieLib.incl(lib)
  
  # Count how many we're removing
  let originalStdLib = ctx.imports.stdLibImports.len
  let originalStorieLib = ctx.imports.storieLibImports.len
  
  # Update import sets
  ctx.imports.stdLibImports = neededStdLib
  ctx.imports.storieLibImports = neededStorieLib
  
  result = (originalStdLib - neededStdLib.len) + (originalStorieLib - neededStorieLib.len)

proc optimizeCode*(ctx: var ExportContext): OptimizationStats =
  ## Apply optimization passes to the export context
  result.unusedVarsRemoved = 0
  result.constantsFolded = 0
  result.deadCodeLinesRemoved = 0
  result.importsOptimized = 0
  
  # Optimize imports first
  result.importsOptimized = optimizeImports(ctx)
  
  # Note: More sophisticated optimizations would go here
  # For now, we've implemented the foundation

proc buildExportContext*(doc: MarkdownDocument): ExportContext =
  ## Build a complete export context from a markdown document
  result.imports = analyzeCodeBlocks(doc.codeBlocks)
  result.globalVars = initTable[string, string]()
  result.procedures = @[]
  result.initCode = @[]
  result.updateCode = @[]
  result.renderCode = @[]
  result.inputCode = @[]
  result.shutdownCode = @[]
  result.functions = initTable[string, string]()
  result.errors = @[]
  
  # Analyze variable scopes to determine globals
  let scopeAnalysis = analyzeVariableScopes(doc)
  let globalNames = scopeAnalysis.globals.toHashSet()
  
  # Build global variable declarations with type inference from initial values
  for varName in scopeAnalysis.globals:
    if scopeAnalysis.variables.hasKey(varName):
      let varInfo = scopeAnalysis.variables[varName]
      
      # Try to infer type from declaration in init code
      var inferredType = ""
      
      # Look through init code for the assignment
      for codeBlock in doc.codeBlocks:
        if codeBlock.lifecycle == "init" or codeBlock.lifecycle == "":
          try:
            let tokens = tokenizeDsl(codeBlock.code)
            let program = parseDsl(tokens)
            
            for stmt in program.stmts:
              if stmt.kind == skVar and stmt.varName == varName:
                # Found the declaration - infer type from value
                if not stmt.varValue.isNil:
                  case stmt.varValue.kind
                  of ekInt:
                    inferredType = "int"
                  of ekFloat:
                    inferredType = "float"
                  of ekString:
                    inferredType = "string"
                  of ekBool:
                    inferredType = "bool"
                  else:
                    # For complex expressions, leave untyped
                    inferredType = ""
                break
          except:
            discard
        
        if inferredType != "":
          break
      
      # Generate declaration
      if inferredType == "":
        result.globalVars[varName] = "var " & varName
      else:
        result.globalVars[varName] = "var " & varName & ": " & inferredType
  
  # Phase 3: Extract procedures from all code blocks
  var extractedProcNames = initHashSet[string]()
  for codeBlock in doc.codeBlocks:
    let procs = extractProcedures(codeBlock.code)
    for procDef in procs:
      result.procedures.add(procDef)
      # Extract proc name for removal
      if procDef.startsWith("proc "):
        let parts = procDef.split({'(', ' ', '\t'})
        if parts.len >= 2:
          extractedProcNames.incl(parts[1].strip())
  
  # Organize code by lifecycle, removing var/let for globals and removing proc defs
  for codeBlock in doc.codeBlocks:
    var processedCode = removeVarDeclForGlobals(codeBlock.code, globalNames)
    processedCode = removeProcedures(processedCode, extractedProcNames)
    
    case codeBlock.lifecycle
    of "init":
      result.initCode.add(processedCode)
    of "update":
      result.updateCode.add(processedCode)
    of "render":
      result.renderCode.add(processedCode)
    of "input":
      result.inputCode.add(processedCode)
    of "shutdown":
      result.shutdownCode.add(processedCode)
    of "":
      # Global code - could be variable declarations or functions
      result.initCode.add(processedCode)
    else:
      result.errors.add("Unknown lifecycle: " & codeBlock.lifecycle)

proc generateImportSection*(ctx: ExportContext): string =
  ## Generate the import section of the Nim file
  result = ""
  
  # Standard library imports
  if ctx.imports.stdLibImports.len > 0:
    var sorted = ctx.imports.stdLibImports.toSeq()
    sorted.sort()
    result &= "# Standard library imports\n"
    for lib in sorted:
      result &= "import " & lib & "\n"
    result &= "\n"
  
  # tStorie library imports  
  if ctx.imports.storieLibImports.len > 0:
    var sorted = ctx.imports.storieLibImports.toSeq()
    sorted.sort()
    result &= "# tStorie library imports\n"
    for lib in sorted:
      # Skip drawing library - we generate our own wrappers
      if lib != "drawing":
        result &= "import lib/" & lib & "\n"
    result &= "\n"
  
  # Custom imports
  if ctx.imports.customImports.len > 0:
    var sorted = ctx.imports.customImports.toSeq()
    sorted.sort()
    result &= "# Custom imports\n"
    for lib in sorted:
      result &= "import " & lib & "\n"
    result &= "\n"

proc generateSimpleEventHelpers*(): string =
  ## Generate simplified event API helpers (matches nimini runtime API)
  ## This provides the same user-friendly event interface for exported programs
  result = ""
  result &= "# Simplified event API (compatible with nimini runtime)\n"
  result &= "type\n"
  result &= "  SimpleEvent* = object\n"
  result &= "    eventType*: string  # \"key\", \"mouse\", \"mouse_move\", \"text\"\n"
  result &= "    x*, y*: int         # Mouse position\n"
  result &= "    keyCode*: int       # Key code or character\n"
  result &= "    button*: string     # \"left\", \"right\", \"middle\", \"scroll_up\", \"scroll_down\"\n"
  result &= "    action*: string     # \"press\", \"release\", \"repeat\"\n"
  result &= "    text*: string       # Text input\n"
  result &= "    mods*: seq[string]  # [\"shift\", \"alt\", \"ctrl\", \"super\"]\n"
  result &= "\n"
  result &= "proc toSimpleEvent(event: InputEvent): SimpleEvent =\n"
  result &= "  ## Convert native InputEvent to simplified event object\n"
  result &= "  case event.kind\n"
  result &= "  of KeyEvent:\n"
  result &= "    result.eventType = \"key\"\n"
  result &= "    result.keyCode = event.keyCode\n"
  result &= "    result.action = case event.keyAction\n"
  result &= "      of Press: \"press\"\n"
  result &= "      of Release: \"release\"\n"
  result &= "      of Repeat: \"repeat\"\n"
  result &= "    if ModShift in event.keyMods: result.mods.add(\"shift\")\n"
  result &= "    if ModAlt in event.keyMods: result.mods.add(\"alt\")\n"
  result &= "    if ModCtrl in event.keyMods: result.mods.add(\"ctrl\")\n"
  result &= "    if ModSuper in event.keyMods: result.mods.add(\"super\")\n"
  result &= "  of TextEvent:\n"
  result &= "    result.eventType = \"text\"\n"
  result &= "    result.text = event.text\n"
  result &= "    result.keyCode = if event.text.len > 0: int(event.text[0]) else: 0\n"
  result &= "  of MouseEvent:\n"
  result &= "    result.eventType = \"mouse\"\n"
  result &= "    result.x = event.mouseX\n"
  result &= "    result.y = event.mouseY\n"
  result &= "    result.button = case event.button\n"
  result &= "      of Left: \"left\"\n"
  result &= "      of Right: \"right\"\n"
  result &= "      of Middle: \"middle\"\n"
  result &= "      of ScrollUp: \"scroll_up\"\n"
  result &= "      of ScrollDown: \"scroll_down\"\n"
  result &= "      of Unknown: \"unknown\"\n"
  result &= "    result.action = case event.action\n"
  result &= "      of Press: \"press\"\n"
  result &= "      of Release: \"release\"\n"
  result &= "      of Repeat: \"repeat\"\n"
  result &= "    if ModShift in event.mods: result.mods.add(\"shift\")\n"
  result &= "    if ModAlt in event.mods: result.mods.add(\"alt\")\n"
  result &= "    if ModCtrl in event.mods: result.mods.add(\"ctrl\")\n"
  result &= "  of MouseMoveEvent:\n"
  result &= "    result.eventType = \"mouse_move\"\n"
  result &= "    result.x = event.moveX\n"
  result &= "    result.y = event.moveY\n"
  result &= "    if ModShift in event.moveMods: result.mods.add(\"shift\")\n"
  result &= "    if ModAlt in event.moveMods: result.mods.add(\"alt\")\n"
  result &= "    if ModCtrl in event.moveMods: result.mods.add(\"ctrl\")\n"
  result &= "  of ResizeEvent:\n"
  result &= "    result.eventType = \"resize\"\n"
  result &= "\n"
  result &= "# Compatibility alias: 'event.type' works in addition to 'event.eventType'\n"
  result &= "template type*(e: SimpleEvent): string = e.eventType\n"
  result &= "\n"

proc generateEmbeddedContentSection*(doc: MarkdownDocument): string =
  ## Generate compile-time embedded content from markdown data blocks
  ## This includes figlet fonts, data files, and other embedded content
  result = ""
  
  if doc.embeddedContent.len == 0:
    return
  
  result &= "# ============================================================================\n"
  result &= "# Embedded Content from Markdown\n"
  result &= "# ============================================================================\n"
  result &= "# This section contains data blocks embedded in the source markdown file.\n"
  result &= "# Content is stored as compile-time strings for zero-overhead access.\n"
  result &= "\n"
  result &= "var gEmbeddedContent {.global.} = initTable[string, string]()\n"
  result &= "\n"
  result &= "proc initEmbeddedContent() =\n"
  result &= "  ## Initialize embedded content at startup\n"
  result &= "  ## This loads all embedded data blocks (figlet fonts, data files, etc.)\n"
  
  for content in doc.embeddedContent:
    result &= "  \n"
    result &= "  # Embedded content: " & content.name
    case content.kind
    of FigletFont:
      result &= " (FIGlet font)\n"
    of DataFile:
      result &= " (data file)\n"
    of Custom:
      result &= " (custom)\n"
    
    # Use triple-quoted strings to avoid escaping issues
    result &= "  gEmbeddedContent[\"" & content.name & "\"] = \"\"\"\n"
    result &= content.content
    result &= "\"\"\"\n"
  
  result &= "\n"
  result &= "# Helper functions to access embedded content\n"
  result &= "proc getEmbeddedContent*(name: string): string =\n"
  result &= "  ## Get embedded content by name\n"
  result &= "  ## Returns empty string if content doesn't exist\n"
  result &= "  gEmbeddedContent.getOrDefault(name, \"\")\n"
  result &= "\n"
  result &= "proc hasEmbeddedContent*(name: string): bool =\n"
  result &= "  ## Check if embedded content exists\n"
  result &= "  gEmbeddedContent.hasKey(name)\n"
  result &= "\n"
  result &= "# Specific helpers for figlet fonts\n"
  result &= "proc getEmbeddedFont*(name: string): string =\n"
  result &= "  ## Get embedded FIGlet font by name\n"
  result &= "  ## This is an alias for getEmbeddedContent for clarity\n"
  result &= "  getEmbeddedContent(name)\n"
  result &= "\n"

proc generateNimProgram*(doc: MarkdownDocument, filename: string = "untitled.md"): string =
  ## Generate a complete, compilable Nim program from a markdown document
  ## This is the standalone mode (minimal runtime, direct execution)
  let ctx = buildExportContext(doc)
  
  result = "# Generated by tStorie Nim Export (Standalone)\n"
  result &= "# Source: " & filename & "\n"
  result &= "\n"
  
  # Core imports
  result &= "import times, os\n"
  result &= "import std/[strutils, tables]  # For join and getOrDefault\n"
  result &= "import src/types\n"
  result &= "import src/layers\n"
  result &= "import src/appstate\n"
  result &= "import src/input  # Input parsing and polling\n"
  result &= "import src/simple_event  # Simplified event API\n"
  result &= "when not defined(emscripten):\n"
  result &= "  import src/platform/terminal\n"
  result &= "\n"
  
  # User imports
  result &= generateImportSection(ctx)
  
  # Embedded content (figlet fonts, data files, etc.)
  result &= generateEmbeddedContentSection(doc)
  
  # Global state
  result &= "# Global state\n"
  result &= "var gState: AppState\n"
  result &= "var gDefaultLayer: Layer  # Single default layer (layer 0)\n"
  result &= "var gRunning {.global.} = true\n"
  result &= "var gInputParser: TerminalInputParser  # For input event parsing\n"
  result &= "when not defined(emscripten):\n"
  result &= "  var gTerminalState: TerminalState\n"
  result &= "\n"
  
  # Unified Drawing API
  result &= "# Unified Drawing API - works with any layer\n"
  result &= "proc draw(layer: string, x, y: int, text: string, style: Style = defaultStyle()) =\n"
  result &= "  let targetLayer = if layer == \"default\": gDefaultLayer else: getLayer(gState, layer)\n"
  result &= "  if targetLayer.isNil: return\n"
  result &= "  targetLayer.buffer.writeText(x, y, text, style)\n"
  result &= "\n"
  result &= "proc draw(layerId: int, x, y: int, text: string, style: Style = defaultStyle()) =\n"
  result &= "  # Integer layer ID overload (0 = default layer)\n"
  result &= "  let targetLayer = if layerId == 0: gDefaultLayer\n"
  result &= "                    elif layerId < gState.layers.len: gState.layers[layerId]\n"
  result &= "                    else: nil\n"
  result &= "  if targetLayer.isNil: return\n"
  result &= "  targetLayer.buffer.writeText(x, y, text, style)\n"
  result &= "\n"
  result &= "proc clear(layer: string = \"\", transparent: bool = false) =\n"
  result &= "  # Clear specific layer, or all layers if no layer specified\n"
  result &= "  if layer == \"\":\n"
  result &= "    for l in gState.layers:\n"
  result &= "      if transparent: l.buffer.clearTransparent()\n"
  result &= "      else: l.buffer.clear(gState.themeBackground)\n"
  result &= "  else:\n"
  result &= "    let targetLayer = if layer == \"default\": gDefaultLayer else: getLayer(gState, layer)\n"
  result &= "    if targetLayer.isNil: return\n"
  result &= "    if transparent: targetLayer.buffer.clearTransparent() else: targetLayer.buffer.clear(gState.themeBackground)\n"
  result &= "\n"
  result &= "proc fillRect(layer: string, x, y, w, h: int, ch: string, style: Style = defaultStyle()) =\n"
  result &= "  let targetLayer = if layer == \"default\": gDefaultLayer else: getLayer(gState, layer)\n"
  result &= "  if targetLayer.isNil: return\n"
  result &= "  targetLayer.buffer.fillRect(x, y, w, h, ch, style)\n"
  result &= "\n"
  result &= "# Runtime helper functions\n"
  result &= "proc print(args: varargs[string, `$`]) = echo args.join(\" \")\n"
  result &= "template termWidth: int = gState.termWidth\n"
  result &= "template termHeight: int = gState.termHeight\n"
  result &= "proc str(x: int): string = $x\n"
  result &= "proc str(x: float): string = $x\n"
  result &= "proc str(x: bool): string = $x\n"
  result &= "proc str(x: string): string = x\n"
  result &= "proc getStyle(name: string): Style =\n"
  result &= "  if gState.styleSheet.hasKey(name):\n"
  result &= "    let sc = gState.styleSheet[name]\n"
  result &= "    result = Style(\n"
  result &= "      fg: Color(r: sc.fg.r, g: sc.fg.g, b: sc.fg.b),\n"
  result &= "      bg: Color(r: sc.bg.r, g: sc.bg.g, b: sc.bg.b),\n"
  result &= "      bold: sc.bold, italic: sc.italic, underline: sc.underline, dim: sc.dim)\n"
  result &= "  elif gState.styleSheet.hasKey(\"default\"):\n"
  result &= "    # Use theme's default style as fallback\n"
  result &= "    let sc = gState.styleSheet[\"default\"]\n"
  result &= "    result = Style(\n"
  result &= "      fg: Color(r: sc.fg.r, g: sc.fg.g, b: sc.fg.b),\n"
  result &= "      bg: Color(r: sc.bg.r, g: sc.bg.g, b: sc.bg.b),\n"
  result &= "      bold: sc.bold, italic: sc.italic, underline: sc.underline, dim: sc.dim)\n"
  result &= "  else:\n"
  result &= "    result = defaultStyle()\n"
  result &= "\n"
  
  # Global variables
  if ctx.globalVars.len > 0:
    result &= "# User global variables\n"
    for name, decl in ctx.globalVars:
      result &= decl & "\n"
    result &= "\n"
  
  # User-defined procedures
  if ctx.procedures.len > 0:
    result &= "# User-defined functions\n"
    for procDef in ctx.procedures:
      result &= procDef & "\n\n"
  
  # Functions (placeholder for future phases)
  if ctx.functions.len > 0:
    result &= "# User-defined functions\n"
    for name, funcDef in ctx.functions:
      result &= funcDef & "\n\n"
  
  # Main program with proper lifecycle
  result &= "proc main() =\n"
  result &= "  when not defined(emscripten):\n"
  result &= "    gTerminalState = setupRawMode()\n"
  result &= "    hideCursor()\n"
  result &= "    enableMouseReporting()\n"
  result &= "    enableKeyboardProtocol()\n"
  result &= "    \n"
  result &= "    let (w, h) = getTermSize()\n"
  result &= "    gState = newAppState(w, h)\n"
  result &= "    \n"
  result &= "    # Initialize default layer (layer 0)\n"
  result &= "    gDefaultLayer = addLayer(gState, \"default\", 0)\n"
  result &= "    \n"
  
  # Initialize embedded content if any
  if doc.embeddedContent.len > 0:
    result &= "    # Initialize embedded content (fonts, data, etc.)\n"
    result &= "    initEmbeddedContent()\n"
    result &= "    \n"
  
  # Theme initialization
  if doc.frontMatter.hasKey("theme"):
    let themeName = doc.frontMatter["theme"]
    result &= "    # Load theme and stylesheet\n"
    result &= "    let theme = getTheme(\"" & themeName & "\")\n"
    result &= "    gState.styleSheet = applyTheme(theme, \"" & themeName & "\")\n"
    result &= "    gState.themeBackground = theme.bgPrimary\n"
    result &= "    \n"
  
  # Init code
  if ctx.initCode.len > 0:
    result &= "    # Initialization\n"
    for code in ctx.initCode:
      let indented = code.split('\n').mapIt("    " & it).join("\n")
      result &= indented & "\n"
    result &= "\n"
  
  # Main loop (if update or render code exists)
  if ctx.updateCode.len > 0 or ctx.renderCode.len > 0:
    result &= "    var lastTime = epochTime()\n"
    result &= "    \n"
    result &= "    try:\n"
    result &= "      # Main loop\n"
    result &= "      while gState.running and gRunning:\n"
    result &= "        let currentTime = epochTime()\n"
    result &= "        let deltaTime = currentTime - lastTime\n"
    result &= "        lastTime = currentTime\n"
    result &= "        \n"
    result &= "        # Update FPS counter\n"
    result &= "        gState.updateFpsCounter(deltaTime)\n"
    result &= "        \n"
    
    # Add input event polling if there's input code
    if ctx.inputCode.len > 0:
      result &= "        # Poll for input events\n"
      result &= "        let events = pollInput(gInputParser)\n"
      result &= "        for nativeEvent in events:\n"
      result &= "          # Convert to simplified event API\n"
      result &= "          let event = toSimpleEvent(nativeEvent)\n"
      result &= "          # Process input event\n"
      for code in ctx.inputCode:
        let indented = code.split('\n').mapIt("          " & it).join("\n")
        result &= indented & "\n"
      result &= "\n"
    
    if ctx.updateCode.len > 0:
      result &= "        # Update\n"
      for code in ctx.updateCode:
        let indented = code.split('\n').mapIt("        " & it).join("\n")
        result &= indented & "\n"
      result &= "\n"
    
    if ctx.renderCode.len > 0:
      result &= "        # Render\n"
      for code in ctx.renderCode:
        let indented = code.split('\n').mapIt("        " & it).join("\n")
        result &= indented & "\n"
      result &= "\n"
      result &= "        # Composite layers and display to terminal\n"
      result &= "        gState.compositeLayers()\n"
      result &= "        gState.currentBuffer.display(gState.previousBuffer, gState.colorSupport)\n"
      result &= "\n"
    
    result &= "        # Frame rate limiting\n"
    result &= "        if gState.targetFps > 0.0:\n"
    result &= "          let frameTime = epochTime() - currentTime\n"
    result &= "          let targetFrameTime = 1.0 / gState.targetFps\n"
    result &= "          let sleepTime = targetFrameTime - frameTime\n"
    result &= "          if sleepTime > 0:\n"
    result &= "            sleep(int(sleepTime * 1000))\n"
    result &= "    finally:\n"
    result &= "      # Cleanup terminal\n"
    result &= "      disableKeyboardProtocol()\n"
    result &= "      disableMouseReporting()\n"
    result &= "      showCursor()\n"
    result &= "      clearScreen()\n"
    result &= "      restoreTerminal(gTerminalState)\n"
    result &= "      stdout.write(\"\\n\")\n"
    result &= "      stdout.flushFile()\n"
  
  # Shutdown code
  if ctx.shutdownCode.len > 0:
    result &= "    # Cleanup\n"
    for code in ctx.shutdownCode:
      let indented = code.split('\n').mapIt("    " & it).join("\n")
      result &= indented & "\n"
  
  result &= "\n"
  result &= "when isMainModule:\n"
  result &= "  main()\n"

# ==============================================================================
# Phase 4: tStorie Runtime Integration
# ==============================================================================

proc generateTStorieIntegratedProgram*(doc: MarkdownDocument, filename: string = "untitled.md"): string =
  ## Generate a complete tStorie-integrated program with proper runtime
  ## This creates a native executable that uses tStorie's terminal system
  let ctx = buildExportContext(doc)
  
  result = "# Generated by tStorie Nim Export (Runtime-Integrated)\n"
  result &= "# Source: " & filename & "\n"
  result &= "# This program uses tStorie's terminal and rendering system\n"
  result &= "#\n"
  result &= "# IMPORTANT: Place this file in the tStorie project root directory to compile\n"
  result &= "# Or compile with: nim c --path:. <this file>\n"
  result &= "\n"
  
  # Core tStorie imports
  result &= "import times, os\n"
  result &= "import std/[strutils, tables]  # For join and getOrDefault\n"
  result &= "import src/types\n"
  result &= "import src/layers\n"
  result &= "import src/appstate\n"
  result &= "import src/input  # Input parsing and polling\n"
  result &= "import src/simple_event  # Simplified event API\n"
  result &= "when not defined(emscripten):\n"
  result &= "  import src/platform/terminal\n"
  result &= "\n"
  
  # User imports
  result &= generateImportSection(ctx)
  
  # Embedded content (figlet fonts, data files, etc.)
  result &= generateEmbeddedContentSection(doc)
  
  # Global state (AppState now imported from src/types)
  result &= "# Global state\n"
  result &= "var gState: AppState\n"
  result &= "var gDefaultLayer: Layer  # Single default layer (layer 0)\n"
  result &= "var gRunning {.global.} = true\n"
  result &= "var gInputParser: TerminalInputParser  # For input event parsing\n"
  result &= "when not defined(emscripten):\n"
  result &= "  var gTerminalState: TerminalState\n"
  result &= "\n"
  
  # Add simplified event API
  result &= generateSimpleEventHelpers()
  
  # Unified Drawing API
  result &= "# Unified Drawing API - works with any layer\n"
  result &= "proc draw(layer: string, x, y: int, text: string, style: Style = defaultStyle()) =\n"
  result &= "  let targetLayer = if layer == \"default\": gDefaultLayer else: getLayer(gState, layer)\n"
  result &= "  if targetLayer.isNil: return\n"
  result &= "  targetLayer.buffer.writeText(x, y, text, style)\n"
  result &= "\n"
  result &= "proc draw(layerId: int, x, y: int, text: string, style: Style = defaultStyle()) =\n"
  result &= "  # Integer layer ID overload (0 = default layer)\n"
  result &= "  let targetLayer = if layerId == 0: gDefaultLayer\n"
  result &= "                    elif layerId < gState.layers.len: gState.layers[layerId]\n"
  result &= "                    else: nil\n"
  result &= "  if targetLayer.isNil: return\n"
  result &= "  targetLayer.buffer.writeText(x, y, text, style)\n"
  result &= "\n"
  result &= "proc clear(layer: string = \"\", transparent: bool = false) =\n"
  result &= "  # Clear specific layer, or all layers if no layer specified\n"
  result &= "  if layer == \"\":\n"
  result &= "    for l in gState.layers:\n"
  result &= "      if transparent: l.buffer.clearTransparent()\n"
  result &= "      else: l.buffer.clear(gState.themeBackground)\n"
  result &= "  else:\n"
  result &= "    let targetLayer = if layer == \"default\": gDefaultLayer else: getLayer(gState, layer)\n"
  result &= "    if targetLayer.isNil: return\n"
  result &= "    if transparent: targetLayer.buffer.clearTransparent() else: targetLayer.buffer.clear(gState.themeBackground)\n"
  result &= "\n"
  result &= "proc fillRect(layer: string, x, y, w, h: int, ch: string, style: Style = defaultStyle()) =\n"
  result &= "  let targetLayer = if layer == \"default\": gDefaultLayer else: getLayer(gState, layer)\n"
  result &= "  if targetLayer.isNil: return\n"
  result &= "  targetLayer.buffer.fillRect(x, y, w, h, ch, style)\n"
  result &= "\n"
  result &= "# Runtime helper functions\n"
  result &= "proc print(args: varargs[string, `$`]) = echo args.join(\" \")\n"
  result &= "template termWidth: int = gState.termWidth\n"
  result &= "template termHeight: int = gState.termHeight\n"
  result &= "proc str(x: int): string = $x\n"
  result &= "proc str(x: float): string = $x\n"
  result &= "proc str(x: bool): string = $x\n"
  result &= "proc str(x: string): string = x\n"
  result &= "proc getStyle(name: string): Style =\n"
  result &= "  if gState.styleSheet.hasKey(name):\n"
  result &= "    let sc = gState.styleSheet[name]\n"
  result &= "    result = Style(\n"
  result &= "      fg: Color(r: sc.fg.r, g: sc.fg.g, b: sc.fg.b),\n"
  result &= "      bg: Color(r: sc.bg.r, g: sc.bg.g, b: sc.bg.b),\n"
  result &= "      bold: sc.bold, italic: sc.italic, underline: sc.underline, dim: sc.dim)\n"
  result &= "  elif gState.styleSheet.hasKey(\"default\"):\n"
  result &= "    # Use theme's default style as fallback\n"
  result &= "    let sc = gState.styleSheet[\"default\"]\n"
  result &= "    result = Style(\n"
  result &= "      fg: Color(r: sc.fg.r, g: sc.fg.g, b: sc.fg.b),\n"
  result &= "      bg: Color(r: sc.bg.r, g: sc.bg.g, b: sc.bg.b),\n"
  result &= "      bold: sc.bold, italic: sc.italic, underline: sc.underline, dim: sc.dim)\n"
  result &= "  else:\n"
  result &= "    result = defaultStyle()\n"
  result &= "\n"
  
  # Global variables
  if ctx.globalVars.len > 0:
    result &= "# User global variables\n"
    for name, decl in ctx.globalVars:
      result &= decl & "\n"
    result &= "\n"
  
  # User-defined procedures
  if ctx.procedures.len > 0:
    result &= "# User-defined functions\n"
    for procDef in ctx.procedures:
      result &= procDef & "\n\n"
  
  # Lifecycle callbacks
  result &= "# Lifecycle callbacks\n"
  result &= "proc onInit() =\n"
  result &= "  ## Initialization - runs once at startup\n"
  if ctx.initCode.len > 0:
    for code in ctx.initCode:
      let indented = code.split('\n').mapIt("  " & it).join("\n")
      result &= indented & "\n"
  else:
    result &= "  discard\n"
  result &= "\n"
  
  result &= "proc onUpdate(dt: float) =\n"
  result &= "  ## Update logic - runs every frame\n"
  if ctx.updateCode.len > 0:
    for code in ctx.updateCode:
      let indented = code.split('\n').mapIt("  " & it).join("\n")
      result &= indented & "\n"
  else:
    result &= "  discard\n"
  result &= "\n"
  
  result &= "proc onRender() =\n"
  result &= "  ## Rendering - runs every frame\n"
  if ctx.renderCode.len > 0:
    for code in ctx.renderCode:
      let indented = code.split('\n').mapIt("  " & it).join("\n")
      result &= indented & "\n"
    result &= "  \n"
    result &= "  # Composite layers and display to terminal\n"
    result &= "  gState.compositeLayers()\n"
    result &= "  gState.currentBuffer.display(gState.previousBuffer, gState.colorSupport)\n"
  else:
    result &= "  discard\n"
  result &= "\n"
  
  if ctx.inputCode.len > 0:
    result &= "proc onInput(event: SimpleEvent) =\n"
    result &= "  ## Input handling - processes keyboard and mouse events\n"
    for code in ctx.inputCode:
      let indented = code.split('\n').mapIt("  " & it).join("\n")
      result &= indented & "\n"
    result &= "\n"
  
  if ctx.shutdownCode.len > 0:
    result &= "proc onShutdown() =\n"
    result &= "  ## Cleanup - runs on exit\n"
    for code in ctx.shutdownCode:
      let indented = code.split('\n').mapIt("  " & it).join("\n")
      result &= indented & "\n"
    result &= "\n"
  
  # Main program with proper tStorie integration
  result &= "proc main() =\n"
  result &= "  ## Main entry point with tStorie runtime integration\n"
  result &= "  when not defined(emscripten):\n"
  result &= "    # Setup terminal\n"
  result &= "    gTerminalState = setupRawMode()\n"
  result &= "    hideCursor()\n"
  result &= "    enableMouseReporting()\n"
  result &= "    enableKeyboardProtocol()\n"
  result &= "    \n"
  result &= "    # Get terminal size and initialize state\n"
  result &= "    let (w, h) = getTermSize()\n"
  result &= "    gState = newAppState(w, h)\n"
  result &= "    \n"
  result &= "    # Initialize default layer (layer 0)\n"
  result &= "    gDefaultLayer = addLayer(gState, \"default\", 0)\n"
  result &= "    \n"
  result &= "    # Initialize input parser\n"
  result &= "    gInputParser = newTerminalInputParser()\n"
  result &= "    \n"
  
  # Initialize embedded content if any
  if doc.embeddedContent.len > 0:
    result &= "    # Initialize embedded content (fonts, data, etc.)\n"
    result &= "    initEmbeddedContent()\n"
    result &= "    \n"
  
  # Theme initialization
  if doc.frontMatter.hasKey("theme"):
    let themeName = doc.frontMatter["theme"]
    result &= "    # Load theme and stylesheet\n"
    result &= "    let theme = getTheme(\"" & themeName & "\")\n"
    result &= "    gState.styleSheet = applyTheme(theme, \"" & themeName & "\")\n"
    result &= "    gState.themeBackground = theme.bgPrimary\n"
    result &= "    \n"
  
  result &= "    # User initialization\n"
  result &= "    onInit()\n"
  result &= "    \n"
  result &= "    var lastTime = epochTime()\n"
  result &= "    \n"
  result &= "    try:\n"
  result &= "      # Main event loop\n"
  result &= "      while gState.running and gRunning:\n"
  result &= "        let currentTime = epochTime()\n"
  result &= "        let deltaTime = currentTime - lastTime\n"
  result &= "        lastTime = currentTime\n"
  result &= "        \n"
  result &= "        # Update FPS counter\n"
  result &= "        gState.updateFpsCounter(deltaTime)\n"
  result &= "        \n"
  if ctx.inputCode.len > 0:
    result &= "        # Poll for input events\n"
    result &= "        let events = pollInput(gInputParser)\n"
    result &= "        for nativeEvent in events:\n"
    result &= "          let event = toSimpleEvent(nativeEvent)\n"
    result &= "          onInput(event)\n"
    result &= "        \n"
  result &= "        # User update\n"
  result &= "        onUpdate(deltaTime)\n"
  result &= "        \n"
  result &= "        # User render\n"
  result &= "        onRender()\n"
  result &= "        \n"
  result &= "        # Frame rate limiting\n"
  result &= "        if gState.targetFps > 0.0:\n"
  result &= "          let frameTime = epochTime() - currentTime\n"
  result &= "          let targetFrameTime = 1.0 / gState.targetFps\n"
  result &= "          let sleepTime = targetFrameTime - frameTime\n"
  result &= "          if sleepTime > 0:\n"
  result &= "            sleep(int(sleepTime * 1000))\n"
  result &= "    finally:\n"
  if ctx.shutdownCode.len > 0:
    result &= "      onShutdown()\n"
  result &= "      # Cleanup terminal\n"
  result &= "      disableKeyboardProtocol()\n"
  result &= "      disableMouseReporting()\n"
  result &= "      showCursor()\n"
  result &= "      clearScreen()\n"
  result &= "      restoreTerminal(gTerminalState)\n"
  result &= "      stdout.write(\"\\n\")\n"
  result &= "      stdout.flushFile()\n"
  result &= "\n"
  result &= "when isMainModule:\n"
  result &= "  main()\n"

# ==============================================================================
# Optimized Export (Phase 5)
# ==============================================================================

proc exportToNimOptimized*(doc: MarkdownDocument, filename: string = "untitled.md"): tuple[code: string, stats: OptimizationStats] =
  ## Export with optimization passes enabled
  ## Returns the generated code and optimization statistics
  var ctx = buildExportContext(doc)
  
  # Apply optimizations
  result.stats = optimizeCode(ctx)
  
  # Generate code from optimized context
  result.code = ""
  result.code &= "# Generated by tStorie Nim Export (Optimized)\n"
  result.code &= "# Source: " & filename & "\n"
  result.code &= "# Optimizations applied:\n"
  result.code &= "#   - Import optimization: " & $result.stats.importsOptimized & " imports removed\n"
  result.code &= "#   - Unused variables: " & $result.stats.unusedVarsRemoved & " removed\n"
  result.code &= "#   - Constants folded: " & $result.stats.constantsFolded & "\n"
  result.code &= "\n"
  
  # Imports (optimized)
  result.code &= generateImportSection(ctx)
  
  # Global variables
  if ctx.globalVars.len > 0:
    result.code &= "# Global state variables\n"
    for name, decl in ctx.globalVars:
      result.code &= decl & "\n"
    result.code &= "\n"
  
  # Procedures
  if ctx.procedures.len > 0:
    result.code &= "# User-defined functions\n"
    for procDef in ctx.procedures:
      result.code &= procDef & "\n\n"
  
  # Main program
  result.code &= "proc main() =\n"
  
  # Init code
  if ctx.initCode.len > 0:
    result.code &= "  # Initialization\n"
    for code in ctx.initCode:
      let indented = code.split('\n').mapIt("  " & it).join("\n")
      result.code &= indented & "\n"
    result.code &= "\n"
  
  # Main loop
  if ctx.updateCode.len > 0 or ctx.renderCode.len > 0:
    result.code &= "  # Main loop\n"
    result.code &= "  var running = true\n"
    result.code &= "  while running:\n"
    
    if ctx.updateCode.len > 0:
      result.code &= "    # Update\n"
      for code in ctx.updateCode:
        let indented = code.split('\n').mapIt("    " & it).join("\n")
        result.code &= indented & "\n"
      result.code &= "\n"
    
    if ctx.renderCode.len > 0:
      result.code &= "    # Render\n"
      for code in ctx.renderCode:
        let indented = code.split('\n').mapIt("    " & it).join("\n")
        result.code &= indented & "\n"
      result.code &= "\n"
  
  # Shutdown
  if ctx.shutdownCode.len > 0:
    result.code &= "  # Cleanup\n"
    for code in ctx.shutdownCode:
      let indented = code.split('\n').mapIt("  " & it).join("\n")
      result.code &= indented & "\n"
  
  result.code &= "\nwhen isMainModule:\n"
  result.code &= "  main()\n"

proc exportToTStorieNimOptimized*(doc: MarkdownDocument, filename: string = "untitled.md"): tuple[code: string, stats: OptimizationStats] =
  ## Export tStorie-integrated program with optimizations
  var ctx = buildExportContext(doc)
  
  # Apply optimizations
  result.stats = optimizeCode(ctx)
  
  # Generate optimized tStorie-integrated code
  result.code = ""
  result.code &= "# Generated by tStorie Nim Export (Runtime-Integrated, Optimized)\n"
  result.code &= "# Source: " & filename & "\n"
  result.code &= "# Optimizations: " & $result.stats.importsOptimized & " imports removed\n"
  result.code &= "\n"
  
  # Core imports
  result.code &= "import times, os\n"
  result.code &= "import std/[strutils, tables]  # For join and getOrDefault\n"
  result.code &= "import src/types\n"
  result.code &= "import src/layers\n"
  result.code &= "import src/appstate\n"
  result.code &= "import src/input  # Input parsing and polling\n"
  result.code &= "import src/simple_event  # Simplified event API\n"
  result.code &= "when not defined(emscripten):\n"
  result.code &= "  import src/platform/terminal\n"
  result.code &= "\n"
  
  # User imports (optimized)
  result.code &= generateImportSection(ctx)
  
  # Global state (AppState now imported from src/types)
  result.code &= "# Global state\n"
  result.code &= "var gState: AppState\n"
  result.code &= "var gDefaultLayer: Layer  # Single default layer (layer 0)\n"
  result.code &= "var gRunning {.global.} = true\n"
  result.code &= "var gInputParser: TerminalInputParser  # For input event parsing\n"
  result.code &= "when not defined(emscripten):\n"
  result.code &= "  var gTerminalState: TerminalState\n"
  result.code &= "\n"
  
  # Add simplified event API
  result.code &= generateSimpleEventHelpers()
  
  # Unified Drawing API
  result.code &= "# Unified Drawing API - works with any layer\n"
  result.code &= "proc draw(layer: string, x, y: int, text: string, style: Style = defaultStyle()) =\n"
  result.code &= "  let targetLayer = if layer == \"default\": gDefaultLayer else: getLayer(gState, layer)\n"
  result.code &= "  if targetLayer.isNil: return\n"
  result.code &= "  targetLayer.buffer.writeText(x, y, text, style)\n"
  result.code &= "\n"
  result.code &= "proc draw(layerId: int, x, y: int, text: string, style: Style = defaultStyle()) =\n"
  result.code &= "  # Integer layer ID overload (0 = default layer)\n"
  result.code &= "  let targetLayer = if layerId == 0: gDefaultLayer\n"
  result.code &= "                    elif layerId < gState.layers.len: gState.layers[layerId]\n"
  result.code &= "                    else: nil\n"
  result.code &= "  if targetLayer.isNil: return\n"
  result.code &= "  targetLayer.buffer.writeText(x, y, text, style)\n"
  result.code &= "\n"
  result.code &= "proc clear(layer: string = \"\", transparent: bool = false) =\n"
  result.code &= "  # Clear specific layer, or all layers if no layer specified\n"
  result.code &= "  if layer == \"\":\n"
  result.code &= "    for l in gState.layers:\n"
  result.code &= "      if transparent: l.buffer.clearTransparent()\n"
  result.code &= "      else: l.buffer.clear(gState.themeBackground)\n"
  result.code &= "  else:\n"
  result.code &= "    let targetLayer = if layer == \"default\": gDefaultLayer else: getLayer(gState, layer)\n"
  result.code &= "    if targetLayer.isNil: return\n"
  result.code &= "    if transparent: targetLayer.buffer.clearTransparent() else: targetLayer.buffer.clear(gState.themeBackground)\n"
  result.code &= "\n"
  result.code &= "proc fillRect(layer: string, x, y, w, h: int, ch: string, style: Style = defaultStyle()) =\n"
  result.code &= "  let targetLayer = if layer == \"default\": gDefaultLayer else: getLayer(gState, layer)\n"
  result.code &= "  if targetLayer.isNil: return\n"
  result.code &= "  targetLayer.buffer.fillRect(x, y, w, h, ch, style)\n"
  result.code &= "\n"
  result.code &= "# Runtime helper functions\n"
  result.code &= "proc print(args: varargs[string, `$`]) = echo args.join(\" \")\n"
  result.code &= "template termWidth: int = gState.termWidth\n"
  result.code &= "template termHeight: int = gState.termHeight\n"
  result.code &= "proc str(x: int): string = $x\n"
  result.code &= "proc str(x: float): string = $x\n"
  result.code &= "proc str(x: bool): string = $x\n"
  result.code &= "proc str(x: string): string = x\n"
  result.code &= "proc getStyle(name: string): Style =\n"
  result.code &= "  if gState.styleSheet.hasKey(name):\n"
  result.code &= "    let sc = gState.styleSheet[name]\n"
  result.code &= "    result = Style(\n"
  result.code &= "      fg: Color(r: sc.fg.r, g: sc.fg.g, b: sc.fg.b),\n"
  result.code &= "      bg: Color(r: sc.bg.r, g: sc.bg.g, b: sc.bg.b),\n"
  result.code &= "      bold: sc.bold, italic: sc.italic, underline: sc.underline, dim: sc.dim)\n"
  result.code &= "  elif gState.styleSheet.hasKey(\\\"default\\\"):\n"
  result.code &= "    # Use theme's default style as fallback\n"
  result.code &= "    let sc = gState.styleSheet[\\\"default\\\"]\n"
  result.code &= "    result = Style(\n"
  result.code &= "      fg: Color(r: sc.fg.r, g: sc.fg.g, b: sc.fg.b),\n"
  result.code &= "      bg: Color(r: sc.bg.r, g: sc.bg.g, b: sc.bg.b),\n"
  result.code &= "      bold: sc.bold, italic: sc.italic, underline: sc.underline, dim: sc.dim)\n"
  result.code &= "  else:\n"
  result.code &= "    result = defaultStyle()\n"
  result.code &= "\n"
  
  # Global variables
  if ctx.globalVars.len > 0:
    result.code &= "# User global variables\n"
    for name, decl in ctx.globalVars:
      result.code &= decl & "\n"
    result.code &= "\n"
  
  # Procedures
  if ctx.procedures.len > 0:
    result.code &= "# User-defined functions\n"
    for procDef in ctx.procedures:
      result.code &= procDef & "\n\n"
  
  # Lifecycle callbacks
  result.code &= "# Lifecycle callbacks\n"
  result.code &= "proc onInit() =\n"
  if ctx.initCode.len > 0:
    for code in ctx.initCode:
      let indented = code.split('\n').mapIt("  " & it).join("\n")
      result.code &= indented & "\n"
  else:
    result.code &= "  discard\n"
  result.code &= "\n"
  
  result.code &= "proc onUpdate(dt: float) =\n"
  if ctx.updateCode.len > 0:
    for code in ctx.updateCode:
      let indented = code.split('\n').mapIt("  " & it).join("\n")
      result.code &= indented & "\n"
  else:
    result.code &= "  discard\n"
  result.code &= "\n"
  
  result.code &= "proc onRender() =\n"
  if ctx.renderCode.len > 0:
    for code in ctx.renderCode:
      let indented = code.split('\n').mapIt("  " & it).join("\n")
      result.code &= indented & "\n"
    result.code &= "  \n"
    result.code &= "  # Composite layers and display to terminal\n"
    result.code &= "  gState.compositeLayers()\n"
    result.code &= "  gState.currentBuffer.display(gState.previousBuffer, gState.colorSupport)\n"
  else:
    result.code &= "  discard\n"
  result.code &= "\n"
  
  if ctx.inputCode.len > 0:
    result.code &= "proc onInput(event: SimpleEvent) =\n"
    result.code &= "  ## Input handling - processes keyboard and mouse events\n"
    for code in ctx.inputCode:
      let indented = code.split('\n').mapIt("  " & it).join("\n")
      result.code &= indented & "\n"
    result.code &= "\n"
  
  if ctx.shutdownCode.len > 0:
    result.code &= "proc onShutdown() =\n"
    for code in ctx.shutdownCode:
      let indented = code.split('\n').mapIt("  " & it).join("\n")
      result.code &= indented & "\n"
    result.code &= "\n"
  
  # Main with runtime
  result.code &= "proc main() =\n"
  result.code &= "  when not defined(emscripten):\n"
  result.code &= "    gTerminalState = setupRawMode()\n"
  result.code &= "    hideCursor()\n"
  result.code &= "    enableMouseReporting()\n"
  result.code &= "    enableKeyboardProtocol()\n"
  result.code &= "    \n"
  result.code &= "    let (w, h) = getTermSize()\n"
  result.code &= "    gState = newAppState(w, h)\n"
  result.code &= "    \n"
  result.code &= "    # Initialize default layer (layer 0)\n"
  result.code &= "    gDefaultLayer = addLayer(gState, \"default\", 0)\n"
  result.code &= "    \n"
  result.code &= "    # Initialize input parser\n"
  result.code &= "    gInputParser = newTerminalInputParser()\n"
  result.code &= "    \n"
  
  # Theme initialization for optimized integrated export
  if doc.frontMatter.hasKey("theme"):
    let themeName = doc.frontMatter["theme"]
    result.code &= "    # Load theme and stylesheet\n"
    result.code &= "    let theme = getTheme(\"" & themeName & "\")\n"
    result.code &= "    gState.styleSheet = applyTheme(theme, \"" & themeName & "\")\n"
    result.code &= "    gState.themeBackground = theme.bgPrimary\n"
    result.code &= "    \n"
  
  result.code &= "    onInit()\n"
  result.code &= "    \n"
  result.code &= "    var lastTime = epochTime()\n"
  result.code &= "    \n"
  result.code &= "    try:\n"
  result.code &= "      while gState.running and gRunning:\n"
  result.code &= "        let currentTime = epochTime()\n"
  result.code &= "        let deltaTime = currentTime - lastTime\n"
  result.code &= "        lastTime = currentTime\n"
  result.code &= "        \n"
  result.code &= "        gState.updateFpsCounter(deltaTime)\n"
  result.code &= "        \n"
  if ctx.inputCode.len > 0:
    result.code &= "        # Poll for input events\n"
    result.code &= "        let events = pollInput(gInputParser)\n"
    result.code &= "        for nativeEvent in events:\n"
    result.code &= "          let event = toSimpleEvent(nativeEvent)\n"
    result.code &= "          onInput(event)\n"
    result.code &= "        \n"
  result.code &= "        onUpdate(deltaTime)\n"
  result.code &= "        onRender()\n"
  result.code &= "        \n"
  result.code &= "        if gState.targetFps > 0.0:\n"
  result.code &= "          let frameTime = epochTime() - currentTime\n"
  result.code &= "          let targetFrameTime = 1.0 / gState.targetFps\n"
  result.code &= "          let sleepTime = targetFrameTime - frameTime\n"
  result.code &= "          if sleepTime > 0:\n"
  result.code &= "            sleep(int(sleepTime * 1000))\n"
  result.code &= "    finally:\n"
  if ctx.shutdownCode.len > 0:
    result.code &= "      onShutdown()\n"
  result.code &= "      disableKeyboardProtocol()\n"
  result.code &= "      disableMouseReporting()\n"
  result.code &= "      showCursor()\n"
  result.code &= "      clearScreen()\n"
  result.code &= "      restoreTerminal(gTerminalState)\n"
  result.code &= "      stdout.write(\"\\n\")\n"
  result.code &= "      stdout.flushFile()\n"
  result.code &= "\n"
  result.code &= "when isMainModule:\n"
  result.code &= "  main()\n"

# ==============================================================================
# Public API
# ==============================================================================

proc exportToNim*(doc: MarkdownDocument, filename: string = "untitled.md"): string =
  ## Main export function: convert a tStorie markdown document to compilable Nim
  ## Returns the generated Nim source code as a string (simple standalone mode)
  result = generateNimProgram(doc, filename)

proc exportToTStorieNim*(doc: MarkdownDocument, filename: string = "untitled.md"): string =
  ## Export with full tStorie runtime integration
  ## Returns a native program that uses tStorie's terminal and rendering system
  result = generateTStorieIntegratedProgram(doc, filename)

proc exportToNimFile*(doc: MarkdownDocument, outputPath: string, sourceName: string = "untitled.md") =
  ## Export a tStorie markdown document to a Nim file
  ## Writes the generated code to the specified file path
  let nimCode = exportToNim(doc, sourceName)
  writeFile(outputPath, nimCode)

proc printImportAnalysis*(doc: MarkdownDocument) =
  ## Utility to print import analysis for debugging
  let imports = analyzeCodeBlocks(doc.codeBlocks)
  
  echo "=== Import Analysis ==="
  echo "Standard Library:"
  for lib in imports.stdLibImports:
    echo "  - ", lib
  
  echo "\ntStorie Libraries:"
  for lib in imports.storieLibImports:
    echo "  - lib/", lib
  
  if imports.customImports.len > 0:
    echo "\nCustom Imports:"
    for lib in imports.customImports:
      echo "  - ", lib

proc printScopeAnalysis*(doc: MarkdownDocument) =
  ## Utility to print variable scope analysis for debugging
  let analysis = analyzeVariableScopes(doc)
  
  echo "=== Variable Scope Analysis ==="
  echo "\nGlobal Variables (used across lifecycles):"
  if analysis.globals.len > 0:
    for varName in analysis.globals:
      if analysis.variables.hasKey(varName):
        let info = analysis.variables[varName]
        echo "  - ", varName
        echo "    Declared in: ", info.declaredIn
        echo "    Used in: ", info.usedIn.toSeq.join(", ")
  else:
    echo "  (none detected)"
  
  echo "\nLocal Variables:"
  var hasLocals = false
  for varName, info in analysis.variables:
    if not info.isGlobal:
      if not hasLocals:
        hasLocals = true
      echo "  - ", varName, " (", info.declaredIn, " only)"
  if not hasLocals:
    echo "  (none detected)"

proc printProcedureAnalysis*(doc: MarkdownDocument) =
  ## Utility to print extracted procedures for debugging
  let ctx = buildExportContext(doc)
  
  echo "=== Function Extraction (Phase 3) ==="
  if ctx.procedures.len > 0:
    echo "\nExtracted Procedures (", ctx.procedures.len, "):"
    for i, procDef in ctx.procedures:
      echo "\n", i+1, ". "
      # Print first line (signature) prominently
      let lines = procDef.split('\n')
      if lines.len > 0:
        echo "   ", lines[0]
        if lines.len > 1:
          echo "   ... (", lines.len - 1, " more lines)"
  else:
    echo "\nNo procedures detected in code blocks."
