## Shared utilities for nimini binding files
##
## This module provides common helper functions used across all *_bindings.nim files.
## It eliminates duplication by centralizing type conversion and utility functions.

import ../nimini/runtime
import ../nimini/type_converters

# Re-export core conversion functions for convenience
# This allows binding files to just import binding_utils instead of multiple modules
export toInt, toBool, toFloat  # From nimini/runtime
export valueToStyle             # From nimini/type_converters
