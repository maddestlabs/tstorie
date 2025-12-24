// JavaScript library for URL parameter bridge
// This is loaded by Emscripten and allows Nim to call JavaScript functions

mergeInto(LibraryManager.library, {
  jsGetUrlParam: function(namePtr) {
    var name = UTF8ToString(namePtr);
    var value = '';
    
    // Use quoted property access to prevent Closure Compiler from mangling
    var store = window['urlParamStore'];
    
    if (store && typeof store === 'object') {
      value = store[name] || '';
    }
    
    // Allocate memory for the return string
    var lengthBytes = lengthBytesUTF8(value) + 1;
    var stringOnWasmHeap = _malloc(lengthBytes);
    stringToUTF8(value, stringOnWasmHeap, lengthBytes);
    return stringOnWasmHeap;
  }
});
