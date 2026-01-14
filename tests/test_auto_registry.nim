## Test module for auto_registry system
## This tests the automatic registry-based binding generation

import ../nimini/auto_registry
import ../nimini/runtime

type
  TestSystem* = ref object
    counter: int
    name: string
    items: seq[string]

# Set up the registry
autoRegistry(TestSystem, "test")

# Constructor - returns string ID
proc createTestSystem*(name: string, initialCount: int): TestSystem {.autoExposeRegistry: "test".} =
  result = TestSystem(name: name, counter: initialCount, items: @[])

# Method that modifies state
proc incrementCounter*(self: TestSystem, amount: int) {.autoExposeRegistryMethod: "test".} =
  self.counter += amount

# Method that returns a value
proc getCounter*(self: TestSystem): int {.autoExposeRegistryMethod: "test".} =
  return self.counter

# Method that adds an item
proc addItem*(self: TestSystem, item: string) {.autoExposeRegistryMethod: "test".} =
  self.items.add(item)

# Method that returns item count
proc getItemCount*(self: TestSystem): int {.autoExposeRegistryMethod: "test".} =
  return self.items.len

# Method that returns string
proc getName*(self: TestSystem): string {.autoExposeRegistryMethod: "test".} =
  return self.name

# Method with boolean return
proc hasItems*(self: TestSystem): bool {.autoExposeRegistryMethod: "test".} =
  return self.items.len > 0

# Register all functions
proc registerTestAutoRegistryBindings*(env: ref Env) =
  register_createTestSystem()
  register_incrementCounter()
  register_getCounter()
  register_addItem()
  register_getItemCount()
  register_getName()
  register_hasItems()
  register_removeTestSystem()

when isMainModule:
  echo "Auto-registry test module compiled successfully!"
  echo "Generated wrappers:"
  echo "  - createTestSystem (returns string ID)"
  echo "  - incrementCounter (void method)"
  echo "  - getCounter (int method)"
  echo "  - addItem (void method)"
  echo "  - getItemCount (int method)"
  echo "  - getName (string method)"
  echo "  - hasItems (bool method)"
  echo "  - removeTestSystem (cleanup)"
