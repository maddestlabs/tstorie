mergeInto(LibraryManager.library, {
  fetchFontFile: function(url, callback) {
    var urlStr = UTF8ToString(url);
    fetch(urlStr)
      .then(response => {
        if (!response.ok) throw new Error('Font not found: ' + urlStr);
        return response.text();
      })
      .then(content => {
        var contentPtr = allocateUTF8(content);
        var errorPtr = allocateUTF8('');
        dynCall('vii', callback, [contentPtr, errorPtr]);
        _free(contentPtr);
        _free(errorPtr);
      })
      .catch(error => {
        var contentPtr = allocateUTF8('');
        var errorPtr = allocateUTF8(error.message);
        dynCall('vii', callback, [contentPtr, errorPtr]);
        _free(contentPtr);
        _free(errorPtr);
      });
  }
});
