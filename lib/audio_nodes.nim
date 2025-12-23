# ================================================================
# WEB AUDIO API-INSPIRED NODE GRAPH SYSTEM
# ================================================================
# TStorie's audio node system mimics the Web Audio API for familiarity
# WASM: Direct bindings to native Web Audio API
# Native: Implemented using miniaudio + custom Nim code

import tables

when defined(emscripten):
  # ================================================================
  # WASM: DIRECT WEB AUDIO API BINDINGS
  # ================================================================
  
  type
    JsAudioContext {.importc.} = ref object
    JsAudioNode {.importc.} = ref object
    JsAudioParam {.importc.} = ref object
  
  # JavaScript bridge functions
  proc jsCreateAudioContext(): JsAudioContext {.importc: "emCreateAudioContext".}
  proc jsCreateOscillator(ctx: JsAudioContext): JsAudioNode {.importc: "emCreateOscillator".}
  proc jsCreateGain(ctx: JsAudioContext): JsAudioNode {.importc: "emCreateGain".}
  proc jsCreateAudioBufferSource(ctx: JsAudioContext): JsAudioNode {.importc: "emCreateBufferSource".}
  proc jsGetDestination(ctx: JsAudioContext): JsAudioNode {.importc: "emGetDestination".}
  proc jsConnectNodes(source: JsAudioNode, dest: JsAudioNode) {.importc: "emConnectNodes".}
  proc jsDisconnectNode(node: JsAudioNode) {.importc: "emDisconnectNode".}
  proc jsStartNode(node: JsAudioNode, time: float) {.importc: "emStartNode".}
  proc jsStopNode(node: JsAudioNode, time: float) {.importc: "emStopNode".}
  proc jsSetNodeParam(node: JsAudioNode, param: cstring, value: float) {.importc: "emSetNodeParam".}
  proc jsGetCurrentTime(ctx: JsAudioContext): float {.importc: "emGetCurrentTime".}
  proc jsSetBufferData(node: JsAudioNode, data: ptr float32, length: cint, sampleRate: cint) {.importc: "emSetBufferData".}

else:
  # ================================================================
  # NATIVE: MINIAUDIO-BASED IMPLEMENTATION
  # ================================================================
  import miniaudio_bindings
  
  type
    NativeAudioNodeKind = enum
      nakOscillator
      nakGain
      nakBufferSource
      nakDestination
    
    NativeAudioNode = ref object of RootObj
      kind: NativeAudioNodeKind
      connections: seq[NativeAudioNode]
      # Oscillator fields
      oscFrequency: float
      oscType: string
      oscRunning: bool
      # Gain fields
      gainValue: float
      # Buffer source fields
      bufferData: seq[float32]
      bufferSampleRate: int
      bufferPosition: int
      sourceRunning: bool

# ================================================================
# COMMON API (PLATFORM-AGNOSTIC)
# ================================================================

type
  AudioContext* = ref object
    when defined(emscripten):
      jsContext: JsAudioContext
    else:
      sampleRate: int
      context: ma_context
      device: ma_device
      deviceConfig: ma_device_config
      nodes: seq[NativeAudioNode]
      destinationNode: NativeAudioNode
  
  AudioNode* = ref object
    ctx: AudioContext
    when defined(emscripten):
      jsNode: JsAudioNode
    else:
      nativeNode: NativeAudioNode
  
  OscillatorType* = enum
    Sine = "sine"
    Square = "square"
    Sawtooth = "sawtooth"
    Triangle = "triangle"

# ================================================================
# AUDIO CONTEXT
# ================================================================

proc newAudioContext*(sampleRate: int = 44100): AudioContext =
  ## Create a new audio context (like Web Audio's AudioContext)
  result = new(AudioContext)
  
  when defined(emscripten):
    result.jsContext = jsCreateAudioContext()
    echo "AudioContext initialized (Web Audio API)"
  else:
    # Native implementation using miniaudio
    result.sampleRate = sampleRate
    result.nodes = @[]
    
    # Initialize miniaudio (simplified for now)
    var contextResult = ma_context_init(nil, 0, nil, addr result.context)
    if contextResult != MA_SUCCESS:
      echo "Warning: Failed to initialize miniaudio context"
      return result
    
    # Create destination node
    result.destinationNode = NativeAudioNode(kind: nakDestination)
    
    echo "AudioContext initialized (miniaudio, ", sampleRate, " Hz)"

proc getCurrentTime*(ctx: AudioContext): float =
  ## Get current time in seconds (like Web Audio's currentTime)
  when defined(emscripten):
    return jsGetCurrentTime(ctx.jsContext)
  else:
    # For native, we'd need to track time from device start
    return 0.0  # Stub for now

proc destination*(ctx: AudioContext): AudioNode =
  ## Get the destination node (speakers) - like Web Audio's destination
  result = new(AudioNode)
  result.ctx = ctx
  
  when defined(emscripten):
    result.jsNode = jsGetDestination(ctx.jsContext)
  else:
    result.nativeNode = ctx.destinationNode

# ================================================================
# AUDIO NODE (BASE)
# ================================================================

proc connect*(source: AudioNode, dest: AudioNode) =
  ## Connect this node to another node (like Web Audio's connect())
  when defined(emscripten):
    jsConnectNodes(source.jsNode, dest.jsNode)
  else:
    if source.nativeNode != nil and dest.nativeNode != nil:
      source.nativeNode.connections.add(dest.nativeNode)

proc disconnect*(node: AudioNode) =
  ## Disconnect this node from all outputs
  when defined(emscripten):
    jsDisconnectNode(node.jsNode)
  else:
    if node.nativeNode != nil:
      node.nativeNode.connections = @[]

# ================================================================
# OSCILLATOR NODE
# ================================================================

proc createOscillator*(ctx: AudioContext): AudioNode =
  ## Create an oscillator node (like Web Audio's OscillatorNode)
  result = new(AudioNode)
  result.ctx = ctx
  
  when defined(emscripten):
    result.jsNode = jsCreateOscillator(ctx.jsContext)
  else:
    result.nativeNode = NativeAudioNode(
      kind: nakOscillator,
      oscFrequency: 440.0,
      oscType: "sine",
      oscRunning: false,
      connections: @[]
    )
    ctx.nodes.add(result.nativeNode)

proc setFrequency*(osc: AudioNode, frequency: float) =
  ## Set oscillator frequency in Hz
  when defined(emscripten):
    jsSetNodeParam(osc.jsNode, "frequency", frequency)
  else:
    if osc.nativeNode != nil and osc.nativeNode.kind == nakOscillator:
      osc.nativeNode.oscFrequency = frequency

proc setType*(osc: AudioNode, waveType: OscillatorType) =
  ## Set oscillator waveform type
  when defined(emscripten):
    jsSetNodeParam(osc.jsNode, "type", float(ord(waveType)))
  else:
    if osc.nativeNode != nil and osc.nativeNode.kind == nakOscillator:
      osc.nativeNode.oscType = $waveType

proc start*(osc: AudioNode, time: float = 0.0) =
  ## Start the oscillator
  when defined(emscripten):
    jsStartNode(osc.jsNode, time)
  else:
    if osc.nativeNode != nil and osc.nativeNode.kind == nakOscillator:
      osc.nativeNode.oscRunning = true

proc stop*(osc: AudioNode, time: float = 0.0) =
  ## Stop the oscillator
  when defined(emscripten):
    jsStopNode(osc.jsNode, time)
  else:
    if osc.nativeNode != nil and osc.nativeNode.kind == nakOscillator:
      osc.nativeNode.oscRunning = false

# ================================================================
# GAIN NODE
# ================================================================

proc createGain*(ctx: AudioContext): AudioNode =
  ## Create a gain (volume) node (like Web Audio's GainNode)
  result = new(AudioNode)
  result.ctx = ctx
  
  when defined(emscripten):
    result.jsNode = jsCreateGain(ctx.jsContext)
  else:
    result.nativeNode = NativeAudioNode(
      kind: nakGain,
      gainValue: 1.0,
      connections: @[]
    )
    ctx.nodes.add(result.nativeNode)

proc setGain*(gain: AudioNode, value: float) =
  ## Set gain value (0.0 = silent, 1.0 = full volume)
  when defined(emscripten):
    jsSetNodeParam(gain.jsNode, "gain", value)
  else:
    if gain.nativeNode != nil and gain.nativeNode.kind == nakGain:
      gain.nativeNode.gainValue = value

# ================================================================
# BUFFER SOURCE NODE
# ================================================================

proc createBufferSource*(ctx: AudioContext): AudioNode =
  ## Create a buffer source node for playing audio samples
  result = new(AudioNode)
  result.ctx = ctx
  
  when defined(emscripten):
    result.jsNode = jsCreateAudioBufferSource(ctx.jsContext)
  else:
    result.nativeNode = NativeAudioNode(
      kind: nakBufferSource,
      bufferData: @[],
      bufferSampleRate: ctx.sampleRate,
      bufferPosition: 0,
      sourceRunning: false,
      connections: @[]
    )
    ctx.nodes.add(result.nativeNode)

proc setBuffer*(source: AudioNode, data: seq[float32], sampleRate: int = 44100) =
  ## Set the audio buffer data
  when defined(emscripten):
    if data.len > 0:
      jsSetBufferData(source.jsNode, unsafeAddr data[0], cint(data.len), cint(sampleRate))
  else:
    if source.nativeNode != nil and source.nativeNode.kind == nakBufferSource:
      source.nativeNode.bufferData = data
      source.nativeNode.bufferSampleRate = sampleRate
      source.nativeNode.bufferPosition = 0

proc startBuffer*(source: AudioNode, time: float = 0.0) =
  ## Start playing the buffer
  when defined(emscripten):
    jsStartNode(source.jsNode, time)
  else:
    if source.nativeNode != nil and source.nativeNode.kind == nakBufferSource:
      source.nativeNode.sourceRunning = true
      source.nativeNode.bufferPosition = 0

proc stopBuffer*(source: AudioNode, time: float = 0.0) =
  ## Stop playing the buffer
  when defined(emscripten):
    jsStopNode(source.jsNode, time)
  else:
    if source.nativeNode != nil and source.nativeNode.kind == nakBufferSource:
      source.nativeNode.sourceRunning = false
