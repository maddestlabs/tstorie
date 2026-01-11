## Graph Compiler - Compile node graphs to native Nim code
##
## Converts runtime graph evaluation to standalone Nim procedures
## that use only primitives (no tstorie runtime required).
##
## This enables "sketch to ship" workflow:
## - Author interactively with graphs
## - Export to native code for production
## - Zero runtime overhead

import std/[tables, strutils, sets, strformat]
import graph, primitives

type
  CompilerContext = object
    varCounter: int
    emittedVars: Table[int, string]  # nodeId → varName
    code: seq[string]
    usedPrimitives: HashSet[string]

proc newCompilerContext(): CompilerContext =
  result.varCounter = 0
  result.emittedVars = initTable[int, string]()
  result.code = @[]
  result.usedPrimitives = initHashSet[string]()

proc freshVar(ctx: var CompilerContext, prefix: string = "v"): string =
  result = prefix & $ctx.varCounter
  ctx.varCounter += 1

proc emit(ctx: var CompilerContext, line: string) =
  ctx.code.add("  " & line)

proc getNodeVar(ctx: var CompilerContext, node: Node): string =
  ## Get or create variable name for a node
  if ctx.emittedVars.hasKey(node.id):
    return ctx.emittedVars[node.id]
  
  let varName = ctx.freshVar()
  ctx.emittedVars[node.id] = varName
  return varName

proc compileNode(ctx: var CompilerContext, node: Node, graph: Graph): string

proc compileInputs(ctx: var CompilerContext, node: Node, graph: Graph): seq[string] =
  ## Compile all input nodes and return their variable names
  result = @[]
  for inputNode in node.inputs:
    result.add(ctx.compileNode(inputNode, graph))

proc compileNode(ctx: var CompilerContext, node: Node, graph: Graph): string =
  ## Compile a single node to Nim code, returns the variable name
  
  # Check if already compiled
  if ctx.emittedVars.hasKey(node.id):
    return ctx.emittedVars[node.id]
  
  let varName = ctx.getNodeVar(node)
  
  case node.kind
  of nkInput:
    # Input nodes are parameters, already defined
    ctx.emittedVars[node.id] = node.inputName
    return node.inputName
  
  of nkConstant:
    if node.domain == edControl:
      ctx.emit(&"let {varName} = {node.constValue}")
    else:
      ctx.emit(&"let {varName} = {int(node.constValue)}")
    return varName
  
  of nkMath:
    let inputs = ctx.compileInputs(node, graph)
    
    case node.mathOp
    of "add":
      if inputs.len >= 2:
        if node.domain == edVisual:
          ctx.usedPrimitives.incl("waveAdd")
          ctx.emit(&"let {varName} = waveAdd({inputs[0]}, {inputs[1]})")
        else:
          ctx.emit(&"let {varName} = {inputs[0]} + {inputs[1]}")
    
    of "mul":
      if inputs.len >= 2:
        if node.domain == edVisual:
          ctx.usedPrimitives.incl("waveMultiply")
          ctx.emit(&"let {varName} = waveMultiply({inputs[0]}, {inputs[1]})")
        else:
          ctx.emit(&"let {varName} = {inputs[0]} * {inputs[1]}")
    
    of "map":
      if node.mathParams.len >= 4:
        let inMin = int(node.mathParams[0])
        let inMax = int(node.mathParams[1])
        let outMin = int(node.mathParams[2])
        let outMax = int(node.mathParams[3])
        ctx.usedPrimitives.incl("map")
        ctx.emit(&"let {varName} = map({inputs[0]}, {inMin}, {inMax}, {outMin}, {outMax})")
    
    of "clamp":
      let minVal = if node.mathParams.len > 0: int(node.mathParams[0]) else: 0
      let maxVal = if node.mathParams.len > 1: int(node.mathParams[1]) else: 1000
      ctx.emit(&"let {varName} = clamp({inputs[0]}, {minVal}, {maxVal})")
    
    of "abs":
      ctx.emit(&"let {varName} = abs({inputs[0]})")
    
    else:
      ctx.emit(&"let {varName} = {inputs[0]}  # TODO: {node.mathOp}")
    
    return varName
  
  of nkWave:
    let inputs = ctx.compileInputs(node, graph)
    let inputVal = if inputs.len > 0: inputs[0] else: "0"
    let phaseShift = int(node.wavePhase * 3600.0)
    
    case node.waveType
    of "sin":
      ctx.usedPrimitives.incl("isin")
      if phaseShift != 0:
        ctx.emit(&"let {varName} = isin(({inputVal} + {phaseShift}) mod 3600)")
      else:
        ctx.emit(&"let {varName} = isin({inputVal} mod 3600)")
    of "cos":
      ctx.usedPrimitives.incl("icos")
      if phaseShift != 0:
        ctx.emit(&"let {varName} = icos(({inputVal} + {phaseShift}) mod 3600)")
      else:
        ctx.emit(&"let {varName} = icos({inputVal} mod 3600)")
    of "saw":
      # Sawtooth is just the angle itself, wrapped
      ctx.emit(&"let {varName} = {inputVal} mod 3600")
    of "square":
      # Square wave: positive half vs negative half
      ctx.emit(&"let {varName} = if ({inputVal} mod 3600) < 1800: 1000 else: -1000")
    else:
      ctx.emit(&"let {varName} = 0  # Unknown wave: {node.waveType}")
    
    return varName
  
  of nkPolar:
    let inputs = ctx.compileInputs(node, graph)
    let xVal = if inputs.len > 0: inputs[0] else: "x"
    let yVal = if inputs.len > 1: inputs[1] else: "y"
    let centerX = int(node.centerX)
    let centerY = int(node.centerY)
    
    case node.polarOp
    of "distance":
      ctx.usedPrimitives.incl("polarDistance")
      ctx.emit(&"let {varName} = polarDistance({xVal}, {yVal}, {centerX}, {centerY})")
    of "angle":
      ctx.usedPrimitives.incl("polarAngle")
      ctx.emit(&"let {varName} = polarAngle({xVal}, {yVal}, {centerX}, {centerY})")
    else:
      ctx.emit(&"let {varName} = 0  # Unknown polar: {node.polarOp}")
    
    return varName
  
  of nkValueOut, nkBufferOut, nkAudioOut:
    # Output nodes just pass through their input
    let inputs = ctx.compileInputs(node, graph)
    if inputs.len > 0:
      ctx.emittedVars[node.id] = inputs[0]
      return inputs[0]
    else:
      ctx.emit(&"let {varName} = 0")
      return varName
  
  else:
    ctx.emit(&"let {varName} = 0  # TODO: {node.kind}")
    return varName

proc compileToNim*(graph: Graph, procName: string = "evaluateGraph", 
                   inputParams: seq[tuple[name: string, typ: string]] = @[]): string =
  ## Compile a graph to standalone Nim code using only primitives
  ## 
  ## Args:
  ##   graph: The graph to compile
  ##   procName: Name of the generated procedure
  ##   inputParams: List of (name, type) pairs for procedure parameters
  ##
  ## Returns: Complete Nim code as a string
  
  var ctx = newCompilerContext()
  
  # Build parameter list
  var paramList = ""
  if inputParams.len > 0:
    var params: seq[string] = @[]
    for (name, typ) in inputParams:
      params.add(&"{name}: {typ}")
    paramList = params.join(", ")
  
  # Start building the procedure
  var output = @[
    &"proc {procName}({paramList}): float =",
    "  ## Auto-generated from node graph"
  ]
  
  # Compile all output nodes (which will recursively compile their inputs)
  var outputVars: seq[string] = @[]
  for node in graph.nodes:
    if node.kind in {nkValueOut, nkBufferOut, nkAudioOut}:
      let varName = ctx.compileNode(node, graph)
      outputVars.add(varName)
  
  # Add all emitted code
  output.add(ctx.code)
  
  # Return the first output value
  if outputVars.len > 0:
    output.add(&"  result = float({outputVars[0]})")
  else:
    output.add("  result = 0.0")
  
  # Add primitive imports at the top
  var imports = "import lib/primitives\n"
  if "map" in ctx.usedPrimitives or "clamp" in ctx.usedPrimitives:
    imports &= "import std/math\n"
  
  result = imports & "\n" & output.join("\n")

proc compileMotionGraphToNim*(graph: Graph): string =
  ## Compile a particle motion graph to a standalone procedure
  ## Returns Nim code that takes particle context and returns velocity delta
  
  let params = @[
    ("px", "float"),
    ("py", "float"), 
    ("pvx", "float"),
    ("pvy", "float"),
    ("page", "float"),
    ("plife", "float"),
    ("time", "float"),
    ("dt", "float")
  ]
  
  result = graph.compileToNim("updateParticleMotion", params)
