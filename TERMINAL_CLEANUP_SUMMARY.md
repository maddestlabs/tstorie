# Terminal Raw Mode Cleanup Fix - Summary

## Problem
When tstorie apps crashed or users pressed CTRL-C, the terminal was left in raw mode, making it unusable:
- No character echo
- No line buffering
- Hidden cursor
- Mouse reporting still active

Users had to run `reset` or close the terminal to fix it.

## Solution Implemented

### Changes Made

#### 1. `/workspaces/telestorie/src/platform/platform_posix.nim`
- Added `emergencyCleanup()` function that restores terminal state
- Added `signalHandler()` that calls cleanup before user handler
- Modified `setupRawMode()` to register cleanup via `system.addQuitProc()`
- Modified `setupSignalHandlers()` to use the new signal handler
- Added global variables to track state and user handler

#### 2. `/workspaces/telestorie/src/platform/platform_win.nim`
- Same changes as POSIX version, adapted for Windows Console API
- Uses `SetConsoleMode()` instead of `tcSetAttr()`

#### 3. `/workspaces/telestorie/lib/nim_export.nim`
- Added `setupSignalHandlers()` call to all three export modes:
  - Standalone mode
  - Integrated mode
  - Optimized integrated mode
- Ensures exported apps have signal handling for CTRL-C
- Exported apps automatically get `addQuitProc` cleanup via `setupRawMode()`

### How It Works

The fix uses a **multi-layered approach**:

1. **Exit Handler (`addQuitProc`)**: Registered once during `setupRawMode()`
   - Runs on normal termination
   - Runs on unhandled exceptions
   - Runs on some fatal errors

2. **Signal Handlers**: Enhanced to restore terminal immediately
   - SIGINT (CTRL-C)
   - SIGTERM (kill command)
   - Cleanup happens BEFORE user code runs

3. **Emergency Cleanup Function**: Does the actual restoration
   - Restores termios settings (POSIX) or console mode (Windows)
   - Shows cursor: `\e[?25h`
   - Disables mouse: `\e[?1006l\e[?1003l`
   - Disables keyboard protocol: `\e[<u`
   - Outputs newline for clean shell prompt

### Testing

All tests pass:
```bash
./test_terminal_cleanup.sh
```

Results:
- ✓ Terminal cleanup after timeout (simulated CTRL-C)
- ✓ Terminal cleanup after multiple successive runs
- ✓ Echo enabled after cleanup
- ✓ Canonical mode enabled after cleanup

### Documentation

- [TERMINAL_CLEANUP.md](TERMINAL_CLEANUP.md) - Detailed technical documentation
- [README.md](README.md) - Added note in Command-Line Usage section
- [test_terminal_cleanup.sh](test_terminal_cleanup.sh) - Automated test suite

### Limitations

Some scenarios cannot be handled:
- **SIGKILL (kill -9)**: Cannot be caught
- **Segmentation faults**: Depends on location and severity
- **Hardware failures**: System-level issues

For these rare cases, users can still run `reset` or `stty sane`.

## Benefits

✅ **Automatic cleanup** - No user action needed in most crash scenarios
✅ **Minimal overhead** - Registration happens once at startup
✅ **Cross-platform** - Works on POSIX (Linux/macOS/BSD) and Windows
✅ **Non-intrusive** - Doesn't change the app's normal flow
✅ **Immediate** - Signal handlers restore state before propagating

## Files Changed

- `src/platform/platform_posix.nim` - Main implementation for Unix-like systems
- `src/platform/platform_win.nim` - Windows implementation
- `lib/nim_export.nim` - Added signal handler setup to exported code
- `README.md` - Added user-facing documentation
- `TERMINAL_CLEANUP.md` - Technical documentation (new file)
- `test_terminal_cleanup.sh` - Test suite (new file)
- `test_crash.md` - Test document for crash scenarios (new file)
