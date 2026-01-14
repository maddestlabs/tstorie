## Generic Nimini Binding Helpers
## 
## Provides template helpers to reduce boilerplate in binding files.
## These templates generate common binding patterns automatically.

import ../nimini
import ../nimini/runtime
import tables

# ============================================================================
# SETTER TEMPLATES - For simple property assignment
# ============================================================================

template defSetter1Float*(registryVar: untyped, TSystem: typedesc, 
                          funcName, lib, desc: string, 
                          propName: untyped): untyped =
  ## Define a setter that takes (name: string, value: float)
  registerNative(funcName,
    proc(env: ref Env; args: seq[Value]): Value {.nimini.} =
      if args.len >= 2 and registryVar.hasKey(args[0].s):
        registryVar[args[0].s].propName = args[1].f
      return valNil(),
    storieLibs = @[lib], description = desc)

template defSetter1String*(registryVar: untyped, TSystem: typedesc,
                           funcName, lib, desc: string,
                           propName: untyped): untyped =
  ## Define a setter that takes (name: string, value: string)
  registerNative(funcName,
    proc(env: ref Env; args: seq[Value]): Value {.nimini.} =
      if args.len >= 2 and registryVar.hasKey(args[0].s):
        registryVar[args[0].s].propName = args[1].s
      return valNil(),
    storieLibs = @[lib], description = desc)

template defSetter1Bool*(registryVar: untyped, TSystem: typedesc,
                         funcName, lib, desc: string,
                         propName: untyped): untyped =
  ## Define a setter that takes (name: string, value: bool)
  registerNative(funcName,
    proc(env: ref Env; args: seq[Value]): Value {.nimini.} =
      if args.len >= 2 and registryVar.hasKey(args[0].s):
        registryVar[args[0].s].propName = args[1].b
      return valNil(),
    storieLibs = @[lib], description = desc)

template defSetter1Int*(registryVar: untyped, TSystem: typedesc,
                        funcName, lib, desc: string,
                        propName: untyped): untyped =
  ## Define a setter that takes (name: string, value: int)
  registerNative(funcName,
    proc(env: ref Env; args: seq[Value]): Value {.nimini.} =
      if args.len >= 2 and registryVar.hasKey(args[0].s):
        registryVar[args[0].s].propName = args[1].i
      return valNil(),
    storieLibs = @[lib], description = desc)

template defSetter2Float*(registryVar: untyped, TSystem: typedesc,
                          funcName, lib, desc: string,
                          propName: untyped): untyped =
  ## Define a setter that takes (name: string, x: float, y: float) -> tuple
  registerNative(funcName,
    proc(env: ref Env; args: seq[Value]): Value {.nimini.} =
      if args.len >= 3 and registryVar.hasKey(args[0].s):
        registryVar[args[0].s].propName = (args[1].f, args[2].f)
      return valNil(),
    storieLibs = @[lib], description = desc)

# ============================================================================
# COMPLEX SETTERS - For properties that need custom logic
# ============================================================================

template defSetterCustom*(funcName, lib, desc: string, body: untyped): untyped =
  ## Define a custom setter with provided body
  registerNative(funcName,
    proc(env: ref Env; args: seq[Value]): Value {.nimini.} =
      body,
    storieLibs = @[lib], description = desc)

# ============================================================================
# GETTER TEMPLATES - For simple property access
# ============================================================================

template defGetter1Int*(registryVar: untyped, TSystem: typedesc,
                        funcName, lib, desc: string,
                        propName: untyped): untyped =
  ## Define a getter that returns an int property
  registerNative(funcName,
    proc(env: ref Env; args: seq[Value]): Value {.nimini.} =
      if args.len < 1 or not registryVar.hasKey(args[0].s):
        return valInt(0)
      return valInt(registryVar[args[0].s].propName),
    storieLibs = @[lib], description = desc)

# ============================================================================
# ACTION TEMPLATES - For functions that perform actions
# ============================================================================

template defAction0*(registryVar: untyped, TSystem: typedesc,
                     funcName, lib, desc: string,
                     methodName: untyped): untyped =
  ## Define an action that calls a method with no args
  registerNative(funcName,
    proc(env: ref Env; args: seq[Value]): Value {.nimini.} =
      if args.len >= 1 and registryVar.hasKey(args[0].s):
        registryVar[args[0].s].methodName()
      return valNil(),
    storieLibs = @[lib], description = desc)

template defAction1Float*(registryVar: untyped, TSystem: typedesc,
                          funcName, lib, desc: string,
                          methodName: untyped): untyped =
  ## Define an action that calls a method with 1 float arg
  registerNative(funcName,
    proc(env: ref Env; args: seq[Value]): Value {.nimini.} =
      if args.len >= 2 and registryVar.hasKey(args[0].s):
        registryVar[args[0].s].methodName(args[1].f)
      return valNil(),
    storieLibs = @[lib], description = desc)

template defAction1Int*(registryVar: untyped, TSystem: typedesc,
                        funcName, lib, desc: string,
                        methodName: untyped): untyped =
  ## Define an action that calls a method with 1 int arg
  registerNative(funcName,
    proc(env: ref Env; args: seq[Value]): Value {.nimini.} =
      if args.len >= 2 and registryVar.hasKey(args[0].s):
        let count = if args.len >= 2: args[1].i else: 1
        registryVar[args[0].s].methodName(count)
      return valNil(),
    storieLibs = @[lib], description = desc)
