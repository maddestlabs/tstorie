## Universal Node Graph System
##
## A domain-agnostic dataflow graph engine inspired by WebAudio's node architecture.
## Handles both audio processing (time-domain) and visual effects (spatial-domain)
## using the same composable node pattern.
##
## Design principles:
## - Pull-based evaluation (like WebAudio)
## - Composable nodes with inputs/outputs
## - Native performance (tight loops, no indirection)
## - Domain-agnostic (works for audio, visuals, or cross-domain)
##
## Architecture:
##   Source Nodes (no inputs) → Transform Nodes → Output Nodes
##   Examples:
##     Audio: Oscillator → Filter → Gain → AudioDestination
##     Visual: Noise → Wave → Color → BufferDestination
##     Reactive: AudioAnalyzer → ParticleEmitter (cross-domain!)

import std/[tables, math]
import primitives
import ../nimini/auto_pointer
import ../nimini/runtime  # For Env, Value types

{.used.}  # Prevent dead code elimination

# ================================================================
# CORE TYPES
# ================================================================

type
  NodeKind* = enum
    ## Node categories - determines behavior and connection rules
    
    # Source nodes (0 inputs, 1+ outputs) - Generate data
    nkConstant          ## Constant value
    nkInput             ## Context input (x, y, frame, time, etc.)
    nkOscillator        ## Audio: sine/square/saw/triangle wave
    nkNoiseSource       ## Audio: white/pink noise OR Visual: procedural noise
    nkAudioInput        ## Audio: microphone/line input
    
    # Transform nodes (1+ inputs, 1+ outputs) - Process data
    nkMath              ## Universal: add, multiply, lerp, clamp, etc.
    nkWave              ## Audio: waveshaper OR Visual: isin/icos primitives
    nkFilter            ## Audio: biquad filter OR Visual: blur/sharpen
    nkPolar             ## Visual: distance/angle calculations
    nkColor             ## Visual: map value to color palette
    nkEasing            ## Universal: easing curves (both audio envelopes and visual)
    nkDelay             ## Audio: echo/reverb OR Visual: motion blur/trails
    nkMix               ## Universal: blend/mix multiple inputs
    nkSplit             ## Universal: duplicate signal to multiple outputs
    
    # Analysis nodes (1 input, multiple outputs) - Extract information
    nkAnalyzer          ## Audio: FFT/spectrum OR Visual: histogram
    nkEnvelope          ## Audio: envelope follower OR Visual: motion detection
    
    # Output nodes (1+ inputs, 0 outputs) - Terminal nodes
    nkAudioOut          ## Audio destination (speakers)
    nkBufferOut         ## Visual destination (render buffer)
    nkValueOut          ## Scalar output (for reactive control)
  
  NodeState* = enum
    nsUnprocessed       ## Not yet evaluated this cycle
    nsProcessing        ## Currently being evaluated (cycle detection)
    nsProcessed         ## Evaluated this cycle, output ready
  
  EvalDomain* = enum
    edAudio             ## Time-domain: evaluates per sample at audio rate
    edVisual            ## Spatial-domain: evaluates per pixel at frame rate
    edControl           ## Control-domain: evaluates once per frame for parameters
  
  EvalContext* = object
    ## Context provided during graph evaluation
    ## Different domains use different fields
    
    # Common
    frame*: int           ## Current frame number (universal clock)
    deltaTime*: float     ## Time since last frame (seconds)
    
    # Visual domain (spatial)
    x*, y*: int           ## Current pixel coordinates
    width*, height*: int  ## Buffer dimensions
    
    # Audio domain (temporal)
    sampleRate*: int      ## Audio sample rate (e.g., 44100 Hz)
    sampleIndex*: int     ## Current sample index in buffer
    time*: float          ## Current time in seconds
    
    # Custom inputs (user-provided)
    custom*: Table[string, float]  ## Named custom inputs (e.g., "mouseX", "volume")
  
  NodeOutput* = object
    ## Output value from a node (can be scalar, audio, or visual)
    case domain*: EvalDomain
    of edAudio:
      audioValue*: float32          ## Single audio sample
      audioBuffer*: seq[float32]    ## Buffer of samples (for block processing)
    of edVisual:
      visualValue*: int             ## Integer value (color, displacement, etc.)
      visualColor*: tuple[r, g, b: uint8]  ## RGB color
    of edControl:
      controlValue*: float          ## Scalar control value
  
  Node* = ref object
    ## Base node type - all nodes inherit from this
    id*: int                        ## Unique node identifier
    kind*: NodeKind                 ## What type of node this is
    domain*: EvalDomain             ## What domain this node operates in
    state*: NodeState               ## Current evaluation state
    
    # Graph connectivity
    inputs*: seq[Node]              ## Input connections (what feeds into this node)
    outputs*: seq[Node]             ## Output connections (what this feeds into)
    
    # Cached output
    cachedOutput*: NodeOutput       ## Result from last evaluation
    
    # Node-specific data (discriminated union)
    case nodeKind*: NodeKind
    
    # Constant node
    of nkConstant:
      constValue*: float
    
    # Input node
    of nkInput:
      inputName*: string            ## Name of input to read from context
    
    # Oscillator node (audio)
    of nkOscillator:
      oscType*: string              ## "sine", "square", "saw", "triangle"
      frequency*: float             ## Hz
      phase*: float                 ## Current phase (0..1)
      detune*: float                ## Cents to detune
    
    # Noise source
    of nkNoiseSource:
      noiseType*: string            ## "white", "pink", "fractal"
      noiseSeed*: int               ## Seed for deterministic noise
      noiseScale*: int              ## Scale for visual noise
      noiseOctaves*: int            ## Octaves for fractal noise
    
    # Math operation
    of nkMath:
      mathOp*: string               ## "add", "sub", "mul", "div", "lerp", "clamp", "map"
      mathParams*: seq[float]       ## Additional parameters (e.g., clamp min/max)
    
    # Wave transformation
    of nkWave:
      waveType*: string             ## "sin", "cos", "isin", "icos"
      waveFrequency*: float         ## Frequency multiplier
      wavePhase*: float             ## Phase offset
    
    # Color mapping
    of nkColor:
      colorPalette*: string         ## "plasma", "fire", "ocean", "heatmap", etc.
      colorRange*: tuple[min, max: int]  ## Input value range
    
    # Easing
    of nkEasing:
      easingType*: string           ## "linear", "inQuad", "outQuad", "inOutQuad", etc.
    
    # Polar coordinates
    of nkPolar:
      polarOp*: string              ## "distance", "angle"
      centerX*, centerY*: float     ## Center point (can be connected inputs)
    
    # Mix/blend
    of nkMix:
      mixAmount*: float             ## Blend factor (0..1)
    
    # Output nodes
    of nkAudioOut, nkBufferOut, nkValueOut:
      discard
    
    else:
      discard
  
  Graph* = ref object
    ## The node graph - collection of connected nodes
    nodes*: seq[Node]               ## All nodes in the graph
    outputNodes*: seq[Node]         ## Terminal output nodes
    nextId*: int                    ## For generating unique node IDs
    
    # Evaluation context
    context*: EvalContext           ## Current evaluation context
    
    # Performance tracking
    evaluationCount*: int           ## Number of evaluations performed
    lastFrameTime*: float           ## Time of last frame evaluation

# Set up auto-pointer system for Graph and Node
autoPointer(Graph)
autoPointer(Node)

# ================================================================
# GRAPH CONSTRUCTION
# ================================================================

proc newGraph*(): Graph {.autoExposePointer.} =
  ## Create a new empty graph
  result = Graph(
    nodes: @[],
    outputNodes: @[],
    nextId: 0,
    evaluationCount: 0,
    lastFrameTime: 0.0
  )
  
  # Initialize default context
  result.context = EvalContext(
    frame: 0,
    deltaTime: 1.0 / 60.0,  # Default to 60fps
    sampleRate: 44100,
    width: 80,
    height: 24
  )

proc addNode*(graph: Graph, kind: NodeKind, domain: EvalDomain = edControl): Node =
  ## Add a new node to the graph
  result = Node(
    id: graph.nextId,
    kind: kind,
    nodeKind: kind,
    domain: domain,
    state: nsUnprocessed,
    inputs: @[],
    outputs: @[],
    cachedOutput: NodeOutput(domain: domain)
  )
  
  inc graph.nextId
  graph.nodes.add(result)
  
  # Add to output nodes if it's a terminal node
  if kind in {nkAudioOut, nkBufferOut, nkValueOut}:
    graph.outputNodes.add(result)

proc connect*(source, dest: Node) =
  ## Connect source node output to dest node input
  ## This is the core of the dataflow graph
  if dest notin source.outputs:
    source.outputs.add(dest)
  if source notin dest.inputs:
    dest.inputs.add(source)

proc disconnect*(source, dest: Node) =
  ## Disconnect two nodes
  let outputIdx = source.outputs.find(dest)
  if outputIdx >= 0:
    source.outputs.delete(outputIdx)
  
  let inputIdx = dest.inputs.find(source)
  if inputIdx >= 0:
    dest.inputs.delete(inputIdx)

proc disconnectAll*(node: Node) =
  ## Disconnect node from all inputs and outputs
  for output in node.outputs:
    let idx = output.inputs.find(node)
    if idx >= 0:
      output.inputs.delete(idx)
  
  for input in node.inputs:
    let idx = input.outputs.find(node)
    if idx >= 0:
      input.outputs.delete(idx)
  
  node.inputs = @[]
  node.outputs = @[]

# ================================================================
# NODE EVALUATION (Pull-based, like WebAudio)
# ================================================================

proc evaluateNode*(node: Node, context: EvalContext): NodeOutput

proc getInputValue*(node: Node, inputIndex: int, context: EvalContext): NodeOutput =
  ## Get value from an input node (recursive evaluation)
  if inputIndex < 0 or inputIndex >= node.inputs.len:
    # No input connected - return default/zero
    return NodeOutput(domain: node.domain)
  
  let inputNode = node.inputs[inputIndex]
  
  # If already processed this cycle, return cached result
  if inputNode.state == nsProcessed:
    return inputNode.cachedOutput
  
  # Otherwise evaluate it
  return evaluateNode(inputNode, context)

proc evaluateNode*(node: Node, context: EvalContext): NodeOutput =
  ## Evaluate a single node (pull-based)
  ## Returns the node's output value
  
  # Cycle detection
  if node.state == nsProcessing:
    echo "Warning: Cycle detected at node ", node.id
    return NodeOutput(domain: node.domain)
  
  # Already processed this cycle
  if node.state == nsProcessed:
    return node.cachedOutput
  
  node.state = nsProcessing
  
  # Evaluate based on node kind
  case node.kind
  
  # ---- SOURCE NODES ----
  
  of nkConstant:
    result = NodeOutput(domain: edControl, controlValue: node.constValue)
  
  of nkInput:
    # Read from context
    case node.inputName
    of "x": result = NodeOutput(domain: edVisual, visualValue: context.x)
    of "y": result = NodeOutput(domain: edVisual, visualValue: context.y)
    of "frame": result = NodeOutput(domain: edControl, controlValue: float(context.frame))
    of "time": result = NodeOutput(domain: edControl, controlValue: context.time)
    of "width": result = NodeOutput(domain: edVisual, visualValue: context.width)
    of "height": result = NodeOutput(domain: edVisual, visualValue: context.height)
    else:
      # Check custom inputs
      if node.inputName in context.custom:
        result = NodeOutput(domain: edControl, controlValue: context.custom[node.inputName])
      else:
        result = NodeOutput(domain: edControl, controlValue: 0.0)
  
  of nkOscillator:
    # Audio oscillator using primitives
    let angle = int(node.phase * 3600.0) mod 3600  # Convert to decidegrees
    var audioSample: float32
    case node.oscType
    of "sine": 
      audioSample = float32(isin(angle)) / 1000.0
    of "square": 
      audioSample = if node.phase < 0.5: 1.0'f32 else: -1.0'f32
    of "saw": 
      audioSample = float32(node.phase * 2.0 - 1.0)
    of "triangle": 
      if node.phase < 0.5: 
        audioSample = float32(node.phase * 4.0 - 1.0)
      else: 
        audioSample = float32(3.0 - node.phase * 4.0)
    else: 
      audioSample = 0.0'f32
    
    # Advance phase
    node.phase += node.frequency / float(context.sampleRate)
    if node.phase >= 1.0:
      node.phase -= 1.0
    
    result = NodeOutput(domain: edAudio, audioValue: audioSample)
  
  of nkNoiseSource:
    # Generate noise using primitives
    case node.noiseType
    of "white":
      # Use hash for deterministic white noise
      let hash = intHash3D(context.x, context.y, context.frame, node.noiseSeed)
      result = NodeOutput(domain: edVisual, visualValue: hash)
    
    of "fractal":
      let noise = fractalNoise2D(context.x, context.y, node.noiseOctaves, 
                                  node.noiseScale, node.noiseSeed)
      result = NodeOutput(domain: edVisual, visualValue: noise)
    
    else:
      result = NodeOutput(domain: edVisual, visualValue: 0)
  
  # ---- TRANSFORM NODES ----
  
  of nkMath:
    # Math operations on inputs
    if node.inputs.len == 0:
      result = NodeOutput(domain: edControl, controlValue: 0.0)
    elif node.inputs.len == 1:
      let input = getInputValue(node, 0, context)
      case node.mathOp
      of "abs":
        if input.domain == edVisual:
          result = NodeOutput(domain: edVisual, visualValue: iabs(input.visualValue))
        else:
          result = NodeOutput(domain: edControl, controlValue: abs(input.controlValue))
      of "clamp":
        let minVal = if node.mathParams.len > 0: node.mathParams[0] else: 0.0
        let maxVal = if node.mathParams.len > 1: node.mathParams[1] else: 1.0
        if input.domain == edVisual:
          result = NodeOutput(domain: edVisual, 
            visualValue: clamp(input.visualValue, int(minVal), int(maxVal)))
        else:
          result = NodeOutput(domain: edControl,
            controlValue: clamp(input.controlValue, minVal, maxVal))
      else:
        result = input
    else:
      # Two or more inputs
      let input1 = getInputValue(node, 0, context)
      let input2 = getInputValue(node, 1, context)
      
      case node.mathOp
      of "add":
        if input1.domain == edVisual and input2.domain == edVisual:
          result = NodeOutput(domain: edVisual, 
            visualValue: waveAdd(input1.visualValue, input2.visualValue))
        elif input1.domain == edControl and input2.domain == edControl:
          result = NodeOutput(domain: edControl,
            controlValue: input1.controlValue + input2.controlValue)
        else:
          # Mixed domains - convert to controlValue
          let val1 = if input1.domain == edVisual: float(input1.visualValue) / 1000.0 else: input1.controlValue
          let val2 = if input2.domain == edVisual: float(input2.visualValue) / 1000.0 else: input2.controlValue
          result = NodeOutput(domain: edControl, controlValue: val1 + val2)
      
      of "mul":
        if input1.domain == edVisual and input2.domain == edVisual:
          result = NodeOutput(domain: edVisual,
            visualValue: waveMultiply(input1.visualValue, input2.visualValue))
        elif input1.domain == edControl and input2.domain == edControl:
          result = NodeOutput(domain: edControl,
            controlValue: input1.controlValue * input2.controlValue)
        else:
          # Mixed domains - convert to controlValue
          let val1 = if input1.domain == edVisual: float(input1.visualValue) / 1000.0 else: input1.controlValue
          let val2 = if input2.domain == edVisual: float(input2.visualValue) / 1000.0 else: input2.controlValue
          result = NodeOutput(domain: edControl, controlValue: val1 * val2)
      
      of "lerp":
        let t = if node.inputs.len > 2:
          let tInput = getInputValue(node, 2, context)
          tInput.controlValue
        else:
          node.mathParams[0]
        
        if input1.domain == edVisual:
          result = NodeOutput(domain: edVisual,
            visualValue: lerp(input1.visualValue, input2.visualValue, int(t * 1000)))
        else:
          result = NodeOutput(domain: edControl,
            controlValue: input1.controlValue * (1.0 - t) + input2.controlValue * t)
      
      of "map":
        # map(value, inMin, inMax, outMin, outMax)
        if node.mathParams.len >= 4:
          let inMin = int(node.mathParams[0])
          let inMax = int(node.mathParams[1])
          let outMin = int(node.mathParams[2])
          let outMax = int(node.mathParams[3])
          if input1.domain == edVisual:
            result = NodeOutput(domain: edVisual,
              visualValue: map(input1.visualValue, inMin, inMax, outMin, outMax))
        else:
          result = input1
      
      else:
        result = input1
  
  of nkWave:
    let input = getInputValue(node, 0, context)
    let angle = case input.domain
      of edVisual: input.visualValue
      of edControl: int(input.controlValue * 3600.0)
      of edAudio: int(input.audioValue * 3600.0)
    
    let waveValue = case node.waveType
      of "sin": isin((angle + int(node.wavePhase * 3600.0)) mod 3600)
      of "cos": icos((angle + int(node.wavePhase * 3600.0)) mod 3600)
      else: angle
    
    result = NodeOutput(domain: edVisual, visualValue: waveValue)
  
  of nkPolar:
    # Get x, y inputs (either from connected nodes or use context)
    let x = if node.inputs.len > 0:
      let input = getInputValue(node, 0, context)
      if input.domain == edVisual: input.visualValue else: int(input.controlValue)
    else: context.x
    
    let y = if node.inputs.len > 1:
      let input = getInputValue(node, 1, context)
      if input.domain == edVisual: input.visualValue else: int(input.controlValue)
    else: context.y
    
    let value = case node.polarOp
      of "distance": 
        polarDistance(x, y, int(node.centerX), int(node.centerY))
      of "angle":
        polarAngle(x, y, int(node.centerX), int(node.centerY))
      else: 0
    
    result = NodeOutput(domain: edVisual, visualValue: value)
  
  of nkColor:
    let input = getInputValue(node, 0, context)
    let value = if input.domain == edVisual:
      input.visualValue
    else:
      int(input.controlValue * 255.0)
    
    # Map to 0..255 range
    let normalizedValue = clamp(
      map(value, node.colorRange.min, node.colorRange.max, 0, 255),
      0, 255
    )
    
    # Get packed color from primitives
    let packedColor = case node.colorPalette
      of "plasma": colorPlasma(normalizedValue)
      of "fire": colorFire(normalizedValue)
      of "ocean": colorOcean(normalizedValue)
      of "heatmap": colorHeatmap(normalizedValue)
      of "coolwarm": colorCoolWarm(normalizedValue)
      of "neon": colorNeon(normalizedValue)
      of "matrix": colorMatrix(normalizedValue)
      of "grayscale": colorGrayscale(normalizedValue)
      else: colorGrayscale(normalizedValue)
    
    # IColor from primitives has r, g, b fields directly
    result = NodeOutput(domain: edVisual)
    result.visualColor = (r: uint8(packedColor.r), g: uint8(packedColor.g), b: uint8(packedColor.b))
  
  of nkEasing:
    let input = getInputValue(node, 0, context)
    let t = if input.domain == edControl:
      int(input.controlValue * 1000.0)
    else:
      input.visualValue
    
    let easedValue = case node.easingType
      of "linear": easeLinear(t)
      of "inQuad": easeInQuad(t)
      of "outQuad": easeOutQuad(t)
      of "inOutQuad": easeInOutQuad(t)
      of "inCubic": easeInCubic(t)
      of "outCubic": easeOutCubic(t)
      else: t
    
    result = NodeOutput(domain: edVisual, visualValue: easedValue)
  
  of nkMix:
    if node.inputs.len >= 2:
      let input1 = getInputValue(node, 0, context)
      let input2 = getInputValue(node, 1, context)
      
      if input1.domain == edVisual and input2.domain == edVisual:
        result = NodeOutput(domain: edVisual,
          visualValue: waveMix(input1.visualValue, input2.visualValue, 
                               int(node.mixAmount * 1000)))
      else:
        let mixed = input1.controlValue * (1.0 - node.mixAmount) + 
                   input2.controlValue * node.mixAmount
        result = NodeOutput(domain: edControl, controlValue: mixed)
    else:
      result = NodeOutput(domain: edControl, controlValue: 0.0)
  
  # ---- OUTPUT NODES ----
  
  of nkAudioOut, nkBufferOut, nkValueOut:
    # Output nodes just pass through their input
    if node.inputs.len > 0:
      result = getInputValue(node, 0, context)
    else:
      result = NodeOutput(domain: node.domain)
  
  # ---- NOT YET IMPLEMENTED ----
  
  of nkAudioInput, nkFilter, nkDelay, nkSplit, nkAnalyzer, nkEnvelope:
    # Placeholder for future implementation
    result = NodeOutput(domain: node.domain)
  
  # Cache result and mark as processed
  node.cachedOutput = result
  node.state = nsProcessed

# ================================================================
# GRAPH EVALUATION
# ================================================================

proc resetNodeStates*(graph: Graph) =
  ## Reset all nodes to unprocessed state (call before each frame)
  for node in graph.nodes:
    node.state = nsUnprocessed

proc evaluate*(graph: Graph, context: EvalContext): seq[NodeOutput] =
  ## Evaluate the entire graph and return outputs from all output nodes
  ## This is the main entry point for graph evaluation
  
  graph.context = context
  resetNodeStates(graph)
  
  result = @[]
  
  # Evaluate all output nodes (pulls data through the graph)
  for outputNode in graph.outputNodes:
    let output = evaluateNode(outputNode, context)
    result.add(output)
  
  inc graph.evaluationCount

proc evaluateForPixel*(graph: Graph, x, y: int): NodeOutput =
  ## Evaluate graph for a specific pixel (visual domain)
  var ctx = graph.context
  ctx.x = x
  ctx.y = y
  
  let outputs = graph.evaluate(ctx)
  if outputs.len > 0:
    return outputs[0]
  else:
    return NodeOutput(domain: edVisual, visualValue: 0)

proc evaluateForAudioSample*(graph: Graph, sampleIndex: int, time: float): float32 =
  ## Evaluate graph for a single audio sample (audio domain)
  var ctx = graph.context
  ctx.sampleIndex = sampleIndex
  ctx.time = time
  
  let outputs = graph.evaluate(ctx)
  if outputs.len > 0 and outputs[0].domain == edAudio:
    return outputs[0].audioValue
  else:
    return 0.0'f32

# ================================================================
# HELPER CONSTRUCTORS (Fluent API)
# ================================================================

proc constant*(graph: Graph, value: float): Node =
  ## Create a constant value node
  result = graph.addNode(nkConstant)
  result.constValue = value

proc input*(graph: Graph, name: string, domain: EvalDomain = edVisual): Node =
  ## Create an input node (reads from context)
  result = graph.addNode(nkInput, domain)
  result.inputName = name

proc oscillator*(graph: Graph, oscType: string = "sine", frequency: float = 440.0): Node =
  ## Create an audio oscillator node
  result = graph.addNode(nkOscillator, edAudio)
  result.oscType = oscType
  result.frequency = frequency
  result.phase = 0.0
  result.detune = 0.0

proc noise*(graph: Graph, noiseType: string = "white", seed: int = 42, 
            scale: int = 20, octaves: int = 3): Node =
  ## Create a noise source node
  result = graph.addNode(nkNoiseSource, edVisual)
  result.noiseType = noiseType
  result.noiseSeed = seed
  result.noiseScale = scale
  result.noiseOctaves = octaves

proc math*(graph: Graph, op: string, params: varargs[float]): Node =
  ## Create a math operation node
  result = graph.addNode(nkMath)
  result.mathOp = op
  result.mathParams = @params

proc wave*(graph: Graph, waveType: string = "sin", frequency: float = 1.0, 
          phase: float = 0.0): Node =
  ## Create a wave transformation node
  result = graph.addNode(nkWave, edVisual)
  result.waveType = waveType
  result.waveFrequency = frequency
  result.wavePhase = phase

proc polar*(graph: Graph, op: string, centerX: float = 0.0, centerY: float = 0.0): Node =
  ## Create a polar coordinate node
  result = graph.addNode(nkPolar, edVisual)
  result.polarOp = op
  result.centerX = centerX
  result.centerY = centerY

proc color*(graph: Graph, palette: string = "plasma", 
           rangeMin: int = 0, rangeMax: int = 1000): Node =
  ## Create a color mapping node
  result = graph.addNode(nkColor, edVisual)
  result.colorPalette = palette
  result.colorRange = (rangeMin, rangeMax)

proc easing*(graph: Graph, easingType: string = "linear"): Node =
  ## Create an easing curve node
  result = graph.addNode(nkEasing)
  result.easingType = easingType

proc mix*(graph: Graph, amount: float = 0.5): Node =
  ## Create a mix/blend node
  result = graph.addNode(nkMix)
  result.mixAmount = amount

proc audioOut*(graph: Graph): Node =
  ## Create an audio output node
  result = graph.addNode(nkAudioOut, edAudio)

proc bufferOut*(graph: Graph): Node =
  ## Create a visual buffer output node
  result = graph.addNode(nkBufferOut, edVisual)

proc valueOut*(graph: Graph): Node =
  ## Create a scalar value output node
  result = graph.addNode(nkValueOut, edControl)

# ================================================================
# OPERATOR OVERLOADING (for fluent chaining)
# ================================================================

proc `+`*(a, b: Node): Node =
  ## Add two nodes (creates math node)
  let graph = a.outputs[0]  # Hack: need to track graph better
  result = newGraph().math("add")
  a.connect(result)
  b.connect(result)

proc `*`*(a, b: Node): Node =
  ## Multiply two nodes
  result = newGraph().math("mul")
  a.connect(result)
  b.connect(result)

proc `->`*(source, dest: Node): Node =
  ## Connect operator (syntactic sugar)
  source.connect(dest)
  return dest

# ================================================================
# NIMINI BINDINGS
# ================================================================

proc nimini_graphConstant*(env: ref Env; args: seq[Value]): Value =
  ## Create a constant node in graph. Args: graphPtrId (int), value (float)
  ## Returns: node pointer ID (int)
  if args.len < 2 or args[0].kind != vkInt:
    return valInt(0)
  
  let graphPtrId = args[0].i
  let value = if args[1].kind == vkFloat: args[1].f elif args[1].kind == vkInt: float(args[1].i) else: 0.0
  
  if not gGraphPtrTable.hasKey(graphPtrId):
    return valInt(0)
  
  let graph = cast[Graph](gGraphPtrTable[graphPtrId])
  let node = graph.constant(value)
  
  # Store node in pointer table and return ID
  let nodeId = gNodeNextId
  inc gNodeNextId
  GC_ref(node)
  gNodePtrTable[nodeId] = cast[pointer](node)
  return valInt(nodeId)

proc nimini_graphInput*(env: ref Env; args: seq[Value]): Value =
  ## Create an input node in graph. Args: graphPtrId (int), name (string)
  ## Returns: node pointer ID (int)
  if args.len < 2 or args[0].kind != vkInt or args[1].kind != vkString:
    return valInt(0)
  
  let graphPtrId = args[0].i
  let name = args[1].s
  
  if not gGraphPtrTable.hasKey(graphPtrId):
    return valInt(0)
  
  let graph = cast[Graph](gGraphPtrTable[graphPtrId])
  let node = graph.input(name)
  
  # Store node in pointer table and return ID
  let nodeId = gNodeNextId
  inc gNodeNextId
  GC_ref(node)
  gNodePtrTable[nodeId] = cast[pointer](node)
  return valInt(nodeId)

# ================================================================
# PLUGIN INITIALIZATION
# ================================================================

# Explicit module initialization for WASM builds
proc initGraphModule*() =
  ## Called explicitly to ensure module initialization in WASM builds
  ## Manually queues all registration functions that were generated by macros
  # From autoPointer(Graph) and autoPointer(Node):
  queuePluginRegistration(register_releaseGraph)
  queuePluginRegistration(register_releaseNode)
  # From {.autoExposePointer.}:
  queuePluginRegistration(register_newGraph)
  # Manual registrations for methods that return Node:
  queuePluginRegistration(proc() = registerNative("graphConstant", nimini_graphConstant, description = "Create constant node"))
  queuePluginRegistration(proc() = registerNative("graphInput", nimini_graphInput, description = "Create input node"))
