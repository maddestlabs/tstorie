## Test module for auto_pointer system
## This tests the automatic pointer-based binding generation

import ../nimini/auto_pointer
import ../nimini/runtime

type
  TestGenerator* = ref object
    value: int
    name: string
    active: bool

# Set up the pointer system
autoPointer(TestGenerator)

# Constructor - returns pointer ID
proc createTestGenerator*(initialValue: int, name: string): TestGenerator {.autoExposePointer.} =
  result = TestGenerator(value: initialValue, name: name, active: true)

# Method that modifies state
proc addToValue*(self: TestGenerator, amount: int) {.autoExposePointerMethod.} =
  self.value += amount

# Method that returns a value
proc getValue*(self: TestGenerator): int {.autoExposePointerMethod.} =
  return self.value

# Method with no return
proc deactivate*(self: TestGenerator) {.autoExposePointerMethod.} =
  self.active = false

# Method that returns bool
proc isActive*(self: TestGenerator): bool {.autoExposePointerMethod.} =
  return self.active

# Method that returns string
proc getName*(self: TestGenerator): string {.autoExposePointerMethod.} =
  return self.name

# Register all functions
proc registerTestAutoPointerBindings*(env: ref Env) =
  register_createTestGenerator()
  register_addToValue()
  register_getValue()
  register_deactivate()
  register_isActive()
  register_getName()
  register_releaseTestGenerator()

when isMainModule:
  echo "Auto-pointer test module compiled successfully!"
  echo "Generated wrappers:"
  echo "  - createTestGenerator (returns pointer ID)"
  echo "  - addToValue (void method)"
  echo "  - getValue (int method)"
  echo "  - deactivate (void method)"
  echo "  - isActive (bool method)"
  echo "  - getName (string method)"
  echo "  - releaseTestGenerator (cleanup)"
