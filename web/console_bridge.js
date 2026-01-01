// Console logging bridge for Nim/WASM
// Provides access to JavaScript console.log from Nim code

mergeInto(LibraryManager.library, {
  emConsoleLog: function(msgPtr) {
    const msg = UTF8ToString(msgPtr);
    console.log('[TSTORIE]', msg);
  }
});
