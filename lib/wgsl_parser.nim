## WGSL Parser
##
## Extracts metadata from WGSL shader code:
## - Shader type (compute, vertex, fragment)
## - Uniform struct fields
## - Storage buffer bindings
## - Workgroup size (for compute shaders)
##
## This parser is lightweight and regex-free, designed to extract
## the essential information needed for nimini API generation.

import strutils, storie_types

proc parseWGSLShader*(name: string, code: string): WGSLShader =
  ## Parse WGSL code and extract metadata
  result = WGSLShader(
    name: name,
    code: code,
    kind: ComputeShader,  # Default
    uniforms: @[],
    bindings: @[],
    workgroupSize: (64, 1, 1)  # Default
  )
  
  let lines = code.split('\n')
  var inUniformStruct = false
  var uniformStructName = ""
  
  for line in lines:
    let trimmed = line.strip()
    
    # Detect shader type from @compute, @vertex, @fragment
    # Priority: compute > fragment > vertex (fragment shaders often include vertex code)
    if "@compute" in trimmed:
      result.kind = ComputeShader
      
      # Extract workgroup size: @workgroup_size(64) or @workgroup_size(16, 16, 1)
      if "@workgroup_size" in trimmed:
        let start = trimmed.find("@workgroup_size(")
        if start >= 0:
          let rest = trimmed[start + 16 .. ^1]
          let endIdx = rest.find(')')
          if endIdx >= 0:
            let sizeStr = rest[0 ..< endIdx]
            let parts = sizeStr.split(',')
            if parts.len >= 1:
              try:
                result.workgroupSize.x = parseInt(parts[0].strip())
                if parts.len >= 2:
                  result.workgroupSize.y = parseInt(parts[1].strip())
                if parts.len >= 3:
                  result.workgroupSize.z = parseInt(parts[2].strip())
              except:
                discard  # Keep defaults
    
    elif "@fragment" in trimmed:
      result.kind = FragmentShader
    
    elif "@vertex" in trimmed:
      # Only set as vertex if we haven't found fragment
      if result.kind != FragmentShader:
        result.kind = VertexShader
    
    # Detect uniform struct start
    if trimmed.startsWith("struct"):
      # First, end any previous struct we were parsing
      inUniformStruct = false
      
      # Look for: struct UniformName {
      let parts = trimmed.split()
      if parts.len >= 2:
        let structName = parts[1].replace("{", "").strip()
        # Only parse structs that look like uniform definitions
        # Common names: Uniforms, UniformData, Params, etc.
        if "uniform" in structName.toLower() or structName == "Uniforms":
          uniformStructName = structName
          inUniformStruct = trimmed.endsWith("{") or (parts.len > 2 and parts[2] == "{")
          continue
    
    # Collect uniform field names
    if inUniformStruct:
      # Check for closing brace (with or without semicolon)
      if "}" in trimmed:
        inUniformStruct = false
        continue
      elif ':' in trimmed:
        # Parse field: fieldName: type,
        let parts = trimmed.split(':')
        if parts.len >= 1:
          let fieldName = parts[0].strip()
          # Skip lines with @ decorators (like @builtin, @location) or function signatures
          # Also skip built-in uniforms that the shader system provides automatically
          # Also skip padding fields (e.g., _pad0, _pad1, etc.)
          if fieldName.len > 0 and not fieldName.startsWith("//") and 
             not fieldName.startsWith("@") and not ("fn " in fieldName) and
             not fieldName.startsWith("_pad") and
             fieldName notin ["time", "resolution"]:
            result.uniforms.add(fieldName)
    
    # Detect bindings: @group(0) @binding(N)
    if "@binding(" in trimmed:
      let start = trimmed.find("@binding(")
      if start >= 0:
        let rest = trimmed[start + 9 .. ^1]
        let endIdx = rest.find(')')
        if endIdx >= 0:
          let bindingStr = rest[0 ..< endIdx].strip()
          try:
            let bindingNum = parseInt(bindingStr)
            if bindingNum notin result.bindings:
              result.bindings.add(bindingNum)
          except:
            discard

proc describeShader*(shader: WGSLShader): string =
  ## Generate a human-readable description of the shader
  result = "WGSL Shader: " & shader.name & "\n"
  result &= "  Type: " & $shader.kind & "\n"
  
  if shader.kind == ComputeShader:
    result &= "  Workgroup size: " & $shader.workgroupSize.x
    if shader.workgroupSize.y > 1 or shader.workgroupSize.z > 1:
      result &= " × " & $shader.workgroupSize.y & " × " & $shader.workgroupSize.z
    result &= "\n"
  
  if shader.uniforms.len > 0:
    result &= "  Uniforms: " & shader.uniforms.join(", ") & "\n"
  
  if shader.bindings.len > 0:
    result &= "  Bindings: " & $shader.bindings.len & " detected\n"
