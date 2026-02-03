// JavaScript bridge for document title manipulation
// Used by Nim/WASM code to update browser tab title

mergeInto(LibraryManager.library, {
  tStorie_setDocumentTitle: function(titlePtr) {
    if (typeof document !== 'undefined' && titlePtr) {
      var title = UTF8ToString(titlePtr);
      document.title = title;
    }
  },

  // Generic function callers for browser API
  tStorie_callFunction: function(funcNamePtr) {
    if (!funcNamePtr) return allocateUTF8('');
    var funcName = UTF8ToString(funcNamePtr);
    try {
      var func = window[funcName];
      if (typeof func === 'function') {
        var result = func();
        return allocateUTF8(String(result || ''));
      }
      return allocateUTF8('');
    } catch (e) {
      console.error('Error calling', funcName, ':', e);
      return allocateUTF8('');
    }
  },

  tStorie_callFunctionWithArg: function(funcNamePtr, argPtr) {
    if (!funcNamePtr) return allocateUTF8('');
    var funcName = UTF8ToString(funcNamePtr);
    var arg = argPtr ? UTF8ToString(argPtr) : '';
    try {
      var func = window[funcName];
      if (typeof func === 'function') {
        var result = func(arg);
        return allocateUTF8(String(result || ''));
      }
      return allocateUTF8('');
    } catch (e) {
      console.error('Error calling', funcName, 'with arg:', e);
      return allocateUTF8('');
    }
  },

  tStorie_callFunctionWith2Args: function(funcNamePtr, arg1Ptr, arg2Ptr) {
    if (!funcNamePtr) return allocateUTF8('');
    var funcName = UTF8ToString(funcNamePtr);
    var arg1 = arg1Ptr ? UTF8ToString(arg1Ptr) : '';
    var arg2 = arg2Ptr ? UTF8ToString(arg2Ptr) : '';
    try {
      var func = window[funcName];
      if (typeof func === 'function') {
        var result = func(arg1, arg2);
        return allocateUTF8(String(result || ''));
      }
      return allocateUTF8('');
    } catch (e) {
      console.error('Error calling', funcName, 'with 2 args:', e);
      return allocateUTF8('');
    }
  }
});
