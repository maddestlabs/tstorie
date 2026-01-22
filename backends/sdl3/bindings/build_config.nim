## Build Configuration for SDL3
## Compiler flags and linking setup

when not defined(emscripten):
  # Native builds: Need SDL3 installed on system or specify path
  # For now, assume SDL3 is in standard locations or will be provided
  {.passL: "-lSDL3".}
  {.passL: "-lSDL3_ttf".}
else:
  # Emscripten builds: SDL3 is built-in
  # Emscripten provides SDL3 automatically, no additional linking needed
  discard
