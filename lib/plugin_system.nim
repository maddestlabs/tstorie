## Plugin System - Dynamic Feature Loading
## Enables incremental loading of functionality based on content analysis

type
  PluginType* = enum
    CoreRendering = "core"      # Always loaded (SDL3 + debug text)
    TTFFonts = "ttf"            # SDL3_ttf + FreeType + HarfBuzz
    AudioEngine = "audio"       # Audio processing
    LayerEffects = "effects"    # Advanced layer effects
    NetworkSync = "network"     # Multiplayer/sync features
  
  PluginStatus* = enum
    NotLoaded
    Loading
    Ready
    Failed
  
  Plugin* = object
    kind*: PluginType
    status*: PluginStatus
    size*: int                  # Bytes
    priority*: int              # Load order (lower = first)
    requiresUserGesture*: bool  # Must wait for user interaction
    symbols*: seq[string]       # Exported function names
  
  PluginManager* = ref object
    plugins*: array[PluginType, Plugin]
    loadedPlugins*: set[PluginType]
    deferredPlugins*: seq[PluginType]

# Plugin definitions
const PluginDefinitions*: array[PluginType, Plugin] = [
  Plugin(
    kind: CoreRendering,
    status: Ready,  # Always loaded
    size: 2_000_000,
    priority: 0,
    requiresUserGesture: false,
    symbols: @["emInit", "emUpdate", "emRender"]
  ),
  Plugin(
    kind: TTFFonts,
    status: NotLoaded,
    size: 1_450_000,
    priority: 1,
    requiresUserGesture: false,
    symbols: @["ttfPluginInit", "ttfPluginLoadFont"]
  ),
  Plugin(
    kind: AudioEngine,
    status: NotLoaded,
    size: 330_000,
    priority: 3,  # Lower priority - defer until needed
    requiresUserGesture: true,  # WebAudio requires user interaction!
    symbols: @["audioInit", "playSound", "setVolume"]
  ),
  Plugin(
    kind: LayerEffects,
    status: NotLoaded,
    size: 200_000,
    priority: 2,
    requiresUserGesture: false,
    symbols: @["applyBlur", "applyGlow", "applyPixelate"]
  ),
  Plugin(
    kind: NetworkSync,
    status: NotLoaded,
    size: 150_000,
    priority: 4,
    requiresUserGesture: false,
    symbols: @["connectPeer", "syncState"]
  )
]

proc newPluginManager*(): PluginManager =
  result = PluginManager()
  result.plugins = PluginDefinitions
  result.loadedPlugins = {CoreRendering}  # Core always loaded

proc isLoaded*(pm: PluginManager, plugin: PluginType): bool =
  plugin in pm.loadedPlugins

proc markAsLoaded*(pm: PluginManager, plugin: PluginType) =
  pm.plugins[plugin].status = Ready
  pm.loadedPlugins.incl plugin

proc getRequiredPlugins*(pm: PluginManager, functionName: string): set[PluginType] =
  ## Determine which plugins are needed for a function
  result = {CoreRendering}  # Always need core
  
  for plugin in PluginDefinitions:
    if functionName in plugin.symbols:
      result.incl plugin.kind

proc analyzeCode*(pm: PluginManager, code: string): set[PluginType] =
  ## Analyze code to determine required plugins
  result = {CoreRendering}
  
  # Check for unicode/emoji in string literals
  var inString = false
  for ch in code:
    if ch == '"' or ch == '\'':
      inString = not inString
    elif inString and ord(ch) > 127:
      # Non-ASCII character found - need TTF fonts
      result.incl TTFFonts
      break
  
  # Check for audio function calls
  if "playSound" in code or "setVolume" in code or "stopSound" in code:
    result.incl AudioEngine
  
  # Check for effect functions
  if "blur" in code or "glow" in code or "pixelate" in code or "chromatic" in code:
    result.incl LayerEffects
  
  # Check for network functions
  if "connect" in code or "sync" in code or "broadcast" in code:
    result.incl NetworkSync

proc getLoadOrder*(pm: PluginManager, needed: set[PluginType]): seq[PluginType] =
  ## Get plugins sorted by priority (lower number = load first)
  var plugins: seq[tuple[plugin: PluginType, priority: int]]
  
  for plugin in needed:
    if plugin != CoreRendering:  # Skip core (already loaded)
      plugins.add (plugin, pm.plugins[plugin].priority)
  
  # Sort by priority
  plugins.sort proc (a, b: tuple[plugin: PluginType, priority: int]): int =
    result = cmp(a.priority, b.priority)
  
  result = plugins.mapIt(it.plugin)

proc getTotalSize*(pm: PluginManager, plugins: set[PluginType]): int =
  ## Calculate total size of plugins to load
  for plugin in plugins:
    result += pm.plugins[plugin].size

# Export to JavaScript for plugin loading
proc emRequestPlugin*(pluginName: cstring): cint {.exportc.} =
  ## Called from JS to request a plugin load
  ## Returns: 0=success, 1=already loaded, -1=not found
  let pm = getGlobalPluginManager()  # Get singleton
  
  for plugin in PluginType:
    if $plugin == $pluginName:
      if pm.isLoaded(plugin):
        return 1  # Already loaded
      
      # Mark as loading
      pm.plugins[plugin].status = Loading
      return 0  # Success, JS should load the module
  
  return -1  # Plugin not found

proc emPluginLoaded*(pluginName: cstring): cint {.exportc.} =
  ## Called from JS when a plugin finishes loading
  let pm = getGlobalPluginManager()
  
  for plugin in PluginType:
    if $plugin == $pluginName:
      pm.markAsLoaded(plugin)
      echo "[PluginManager] Plugin loaded: ", pluginName
      return 0
  
  return -1

proc emAnalyzeContent*(content: cstring): cstring {.exportc.} =
  ## Analyze markdown content and return JSON array of needed plugins
  let pm = getGlobalPluginManager()
  let code = $content
  
  var needed = pm.analyzeCode(code)
  var loadOrder = pm.getLoadOrder(needed)
  
  # Build JSON array: ["ttf", "effects", "audio"]
  var json = "["
  for i, plugin in loadOrder:
    if i > 0: json.add ","
    json.add "\"" & $plugin & "\""
  json.add "]"
  
  result = json.cstring
