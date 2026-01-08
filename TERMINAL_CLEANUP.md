# Terminal Cleanup on Crash or CTRL-C

## Problem

When tstorie apps crash or users hit CTRL-C, the terminal can be left in raw mode. This causes the terminal to become unusable because:
- Characters are not echoed when typed
- Line buffering is disabled
- The cursor may remain hidden
- Mouse reporting stays enabled

Users must then run `reset` or close and reopen their terminal to fix it.

## Solution

The fix implements a multi-layered approach to ensure terminal restoration:

### 1. **Exit Handler via `addQuitProc`**
When `setupRawMode()` is called, we register an emergency cleanup handler using Nim's `system.addQuitProc()`. This handler runs when the program exits normally or abnormally, including:
- Normal program termination
- Unhandled exceptions
- Fatal errors
- Memory access violations (in some cases)

### 2. **Enhanced Signal Handlers**
Signal handlers for SIGINT (CTRL-C) and SIGTERM now immediately restore terminal state before calling the user's handler. This ensures cleanup happens even if the user handler doesn't complete.

### 3. **Emergency Cleanup Function**
The `emergencyCleanup()` function:
- Restores the original terminal settings (termios on POSIX)
- Shows the cursor (`\e[?25h`)
- Disables mouse reporting (`\e[?1006l\e[?1003l`)
- Disables enhanced keyboard protocol (`\e[<u`)
- Outputs a newline for clean prompt positioning

## Implementation Details

### POSIX (Linux/macOS/BSD)

File: `src/platform/platform_posix.nim`

```nim
var globalTerminalState: TerminalState
var cleanupRegistered = false
var globalUserHandler: proc(sig: cint) {.noconv.}

proc emergencyCleanup() {.noconv.} =
  if globalTerminalState.isRawMode:
    discard tcSetAttr(STDIN_FILENO, TCSAFLUSH, unsafeAddr globalTerminalState.oldTermios)
    stdout.write("\e[?25h\e[?1006l\e[?1003l\e[<u\n")
    stdout.flushFile()

proc signalHandler(sig: cint) {.noconv.} =
  emergencyCleanup()
  if globalUserHandler != nil:
    globalUserHandler(sig)

proc setupRawMode*(): TerminalState =
  # ... terminal setup code ...
  
  # Register emergency cleanup handler (only once)
  if not cleanupRegistered:
    system.addQuitProc(emergencyCleanup)
    cleanupRegistered = true

proc setupSignalHandlers*(handler: proc(sig: cint) {.noconv.}) =
  globalUserHandler = handler
  signal(SIGINT, signalHandler)
  signal(SIGTERM, signalHandler)
```

### Windows

File: `src/platform/platform_win.nim`

Similar implementation using Windows Console API (`SetConsoleMode`) instead of termios.

### Exported Apps

Apps exported via `tstorie export` automatically include both cleanup mechanisms:

1. **`setupRawMode()` registration** - The exported code calls `setupRawMode()` which registers the emergency cleanup handler
2. **Signal handler setup** - The exported code explicitly calls:
   ```nim
   setupSignalHandlers(proc(sig: cint) {.noconv.} = gRunning = false)
   ```

This ensures that exported standalone applications have the same terminal cleanup protection as the main tstorie runtime.

## Testing

To test the fix:

1. **Normal CTRL-C**: Run any tstorie app and press CTRL-C - terminal should be restored
2. **Simulated crash**: Add a deliberate error in a script to trigger an exception
3. **Rapid exit**: Start an app and immediately press CTRL-C multiple times
4. **Check terminal state**: After each test, verify:
   - Characters are echoed when typed
   - Cursor is visible
   - Terminal behaves normally

## Limitations

Some crash scenarios may still leave the terminal in raw mode:
- **SIGKILL (kill -9)**: Cannot be caught by signal handlers
- **Hardware failures**: System-level failures
- **Some segmentation faults**: Depending on where they occur

For these cases, users can still run `reset` or `stty sane` to restore the terminal.

## Benefits

- **Improved user experience**: Terminal remains usable after crashes
- **No extra user action**: Automatic cleanup in most scenarios
- **Minimal overhead**: Cleanup only runs once at initialization
- **Platform-agnostic**: Works on both POSIX and Windows systems
- **Exported apps included**: All apps exported via `tstorie export` automatically include the cleanup mechanism
