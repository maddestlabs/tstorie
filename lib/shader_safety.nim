## Shader Safety Validation Layer
## Prevents malformed data from reaching WebGPU and causing browser hangs

import strutils

const
  MAX_SHADER_CODE_SIZE* = 500_000  # 500KB max shader code
  MAX_UNIFORM_COUNT* = 64          # Reasonable limit
  MAX_UNIFORM_NAME_LEN* = 64       # Max uniform identifier length

type
  ValidationError* = object
    message*: string
    field*: string

  ValidationResult* = object
    valid*: bool
    errors*: seq[ValidationError]

proc newValidationError(field, message: string): ValidationError =
  ValidationError(field: field, message: message)

proc isValidIdentifierChar(c: char, isFirst: bool): bool =
  ## Check if character is valid in an identifier
  if isFirst:
    return c in {'a'..'z', 'A'..'Z', '_'}
  else:
    return c in {'a'..'z', 'A'..'Z', '0'..'9', '_'}

proc isValidIdentifier(name: string, mustStartWithLetter: bool = false): bool =
  ## Validate identifier without regex (compile-time safe)
  if name.len == 0 or name.len > 64:
    return false
  
  for i, c in name:
    if i == 0:
      if mustStartWithLetter and c == '_':
        return false
      if not isValidIdentifierChar(c, true):
        return false
    else:
      if not isValidIdentifierChar(c, false):
        return false
  
  return true

proc validateShaderName*(name: string): ValidationResult =
  ## Validate shader identifier is safe and well-formed
  result = ValidationResult(valid: true, errors: @[])
  
  if name.len == 0:
    result.valid = false
    result.errors.add(newValidationError("name", "Shader name cannot be empty"))
    return
  
  if name.len > 64:
    result.valid = false
    result.errors.add(newValidationError("name", "Shader name too long (max 64 chars)"))
    return
  
  if not isValidIdentifier(name, mustStartWithLetter = true):
    result.valid = false
    result.errors.add(newValidationError("name", 
      "Shader name must start with letter and contain only alphanumeric and underscore"))

proc validateUniformName*(name: string): ValidationResult =
  ## Validate uniform identifier is safe and well-formed
  result = ValidationResult(valid: true, errors: @[])
  
  if name.len == 0:
    result.valid = false
    result.errors.add(newValidationError("uniform", "Uniform name cannot be empty"))
    return
  
  if name.len > MAX_UNIFORM_NAME_LEN:
    result.valid = false
    result.errors.add(newValidationError("uniform", 
      "Uniform name too long (max " & $MAX_UNIFORM_NAME_LEN & " chars)"))
    return
  
  # Check for suspicious characters that might break JSON or JavaScript
  if '@' in name or '(' in name or ')' in name or '{' in name or '}' in name or
     '"' in name or '\'' in name or '\\' in name or '\n' in name or '\r' in name:
    result.valid = false
    result.errors.add(newValidationError("uniform", 
      "Uniform name contains illegal characters: " & name))
    return
  
  if not isValidIdentifier(name, mustStartWithLetter = false):
    result.valid = false
    result.errors.add(newValidationError("uniform", 
      "Uniform name must start with letter/underscore and contain only alphanumeric and underscore"))

proc validateShaderCode*(code: string): ValidationResult =
  ## Validate shader code is safe to send to WebGPU
  result = ValidationResult(valid: true, errors: @[])
  
  if code.len == 0:
    result.valid = false
    result.errors.add(newValidationError("code", "Shader code cannot be empty"))
    return
  
  if code.len > MAX_SHADER_CODE_SIZE:
    result.valid = false
    result.errors.add(newValidationError("code", 
      "Shader code too large (max " & $MAX_SHADER_CODE_SIZE & " bytes)"))
    return
  
  # Check for null bytes or other binary data
  if '\0' in code:
    result.valid = false
    result.errors.add(newValidationError("code", "Shader code contains null bytes"))

proc validateUniforms*(uniforms: seq[string]): ValidationResult =
  ## Validate all uniform names in a collection
  result = ValidationResult(valid: true, errors: @[])
  
  if uniforms.len > MAX_UNIFORM_COUNT:
    result.valid = false
    result.errors.add(newValidationError("uniforms", 
      "Too many uniforms (max " & $MAX_UNIFORM_COUNT & ")"))
    return
  
  for uniformName in uniforms:
    let validation = validateUniformName(uniformName)
    if not validation.valid:
      result.valid = false
      result.errors.add(validation.errors)

proc sanitizeJSON*(json: string): string =
  ## Sanitize JSON string to prevent injection attacks
  ## Replace dangerous characters that could break out of JSON context
  result = json
  result = result.replace("</script>", "<\\/script>")
  result = result.replace("<!--", "<\\!--")
  result = result.replace("-->", "--\\>")

proc formatValidationErrors*(errors: seq[ValidationError]): string =
  ## Format validation errors for logging
  if errors.len == 0:
    return "No errors"
  
  var lines: seq[string] = @[]
  for err in errors:
    lines.add("  [" & err.field & "] " & err.message)
  
  return lines.join("\n")

proc validateComputeShader*(shader: auto): ValidationResult =
  ## Validate compute shader is safe and well-formed
  ## Checks workgroup size, bindings, and entry point
  result = ValidationResult(valid: true, errors: @[])
  
  # Check workgroup size limits
  let totalThreads = shader.workgroupSize.x * shader.workgroupSize.y * shader.workgroupSize.z
  if totalThreads > 256:
    result.valid = false
    result.errors.add(newValidationError("workgroupSize", 
      "Workgroup size too large: " & $totalThreads & " threads (max 256)"))
  
  if shader.workgroupSize.x == 0 or shader.workgroupSize.y == 0 or shader.workgroupSize.z == 0:
    result.valid = false
    result.errors.add(newValidationError("workgroupSize", 
      "Workgroup size dimensions must be > 0"))
  
  # Check for infinite loops
  if "while(true)" in shader.code or "for(;;)" in shader.code:
    result.valid = false
    result.errors.add(newValidationError("code", 
      "Potential infinite loop detected"))
  
  # Validate bindings
  if shader.bindings.len < 2:
    result.valid = false
    result.errors.add(newValidationError("bindings", 
      "Compute shader requires at least 2 bindings (input/output buffers)"))
  
  # Check entry point
  if "fn main" notin shader.code:
    result.valid = false
    result.errors.add(newValidationError("code", 
      "Compute shader missing 'fn main' entry point"))
  
  # Check for @compute decorator
  if "@compute" notin shader.code:
    result.valid = false
    result.errors.add(newValidationError("code", 
      "Compute shader missing '@compute' decorator"))
