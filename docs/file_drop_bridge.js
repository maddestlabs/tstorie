// File Drop Bridge - Helper for transferring binary data to WASM
// This is included as a --js-library in the Emscripten build

mergeInto(LibraryManager.library, {
  // Helper called from JavaScript to write binary data to WASM memory
  // Returns a pointer to the allocated memory
  jsCopyBinaryToWasm: function(jsDataArray, length) {
    var ptr = _malloc(length);
    if (ptr === 0) {
      return 0;  // Allocation failed
    }
    
    // Write each byte to WASM heap
    for (var i = 0; i < length; i++) {
      HEAP8[ptr + i] = jsDataArray[i];
    }
    
    return ptr;
  }
});
