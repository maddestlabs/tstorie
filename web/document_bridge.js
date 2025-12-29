// JavaScript bridge for document title manipulation
// Used by Nim/WASM code to update browser tab title

mergeInto(LibraryManager.library, {
  tStorie_setDocumentTitle: function(titlePtr) {
    if (typeof document !== 'undefined' && titlePtr) {
      var title = UTF8ToString(titlePtr);
      document.title = title;
    }
  }
});
