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
    
    elif "@vertex" in trimmed:
      result.kind = VertexShader
    
    elif "@fragment" in trimmed:
      result.kind = FragmentShader
    
    # Detect uniform struct start
    if trimmed.startsWith("struct") and "uniform" in code.toLower():
      # Look for: struct UniformName {
      let parts = trimmed.split()
      if parts.len >= 2:
        uniformStructName = parts[1].replace("{", "").strip()
        inUniformStruct = trimmed.endsWith("{")
        continue
    
    # Collect uniform field names
    if inUniformStruct:
      if trimmed.endsWith("}") or trimmed == "}":
        inUniformStruct = false
      elif ':' in trimmed:
        # Parse field: fieldName: type,
        let parts = trimmed.split(':')
        if parts.len >= 1:
          let fieldName = parts[0].strip()
          if fieldName.len > 0 and not fieldName.startsWith("//"):
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
