# PNG Workflow Sharing System

## Overview

tStorie now supports ComfyUI-style workflow sharing via PNG images. This allows you to:
- **Export**: Capture a terminal screenshot as PNG with embedded workflow data
- **Import**: Load workflow data from PNG files by drag-and-drop or file picker
- **Share**: Share both visual output AND executable content in a single image file

## How It Works

### Zero Dependencies
The system uses **no external libraries** - just browser built-ins:
- **Canvas API** - Captures terminal screenshots
- **PNG Chunk Manipulation** - Pure JavaScript binary manipulation
- **Compression Streams API** - Compresses workflow data
- **Base64** - Encodes compressed data for storage

### PNG Metadata Storage
Content is stored in PNG `tEXt` chunks (standard PNG metadata):
- Chunk keyword: `tStorie-workflow`
- Chunk data: Compressed + base64url-encoded content
- Compliant with PNG specification
- Readable by any PNG decoder
- Does not affect image display

### Architecture
```
Terminal Canvas → PNG Screenshot → Inject tEXt Chunk → Download
                                         ↓
                              [tStorie-workflow: compressed_data]

PNG File → Extract tEXt Chunks → Decompress → Restore Content
```

## API Functions

### JavaScript API (web/index.html)

#### Core Functions
```javascript
// Capture terminal and export as PNG with embedded workflow
await captureTerminalToPNG(content) → Blob

// Extract workflow from PNG file
await extractWorkflowFromPNG(pngFile) → string

// Create PNG tEXt chunk
createPNGTextChunk(keyword, text) → Uint8Array

// Extract all tEXt chunks from PNG
extractPNGTextChunks(pngData) → object

// Inject chunk before IEND
injectChunkBeforeIEND(pngData, chunk) → Uint8Array

// Calculate CRC32 for PNG chunks
calculateCRC32(data) → number
```

#### User-Facing API
```javascript
// Export content as PNG (triggers download)
window.tStorie_exportToPNG(content, filename)
window.tStorie_checkPngExportReady() → "true" | "false"
window.tStorie_getPngExportError() → error_message

// Import workflow from PNG (opens file picker)
window.tStorie_importFromPNG()
window.tStorie_checkPngImportReady() → "true" | "false"
window.tStorie_getPngImportContent() → content
```

### Nim/WASM API (src/runtime_api.nim)

```nim
# Export current content as PNG
exportToPNG(content: string, filename: string)
checkPngExportReady() → "true" | "false"
getPngExportError() → string

# Import workflow from PNG
importFromPNG()
checkPngImportReady() → "true" | "false"
getPngImportContent() → string
```

## Usage Examples

### Basic Export
```nim
# Export current editor content
let content = getEditorContent()
exportToPNG(content, "my-workflow")

# Wait for completion
while checkPngExportReady() != "true":
  sleep(100)

if getPngExportError() != "":
  echo "Export failed!"
else:
  echo "✓ PNG saved!"
```

### Basic Import
```nim
# Open file picker
importFromPNG()

# Wait for user selection
while checkPngImportReady() != "true":
  sleep(100)

# Get content
let content = getPngImportContent()
if content != "":
  loadWorkflow(content)
```

### Async Pattern (Recommended)
```nim
proc onExportClick() =
  exportToPNG(getCurrentContent(), "workflow")
  startPolling(checkExportComplete)

proc checkExportComplete() =
  if checkPngExportReady() == "true":
    let error = getPngExportError()
    if error == "":
      showNotification("✓ PNG exported!")
    else:
      showError("Export failed: " & error)
    stopPolling()

proc onImportClick() =
  importFromPNG()
  startPolling(checkImportComplete)

proc checkImportComplete() =
  if checkPngImportReady() == "true":
    let content = getPngImportContent()
    if content != "":
      loadWorkflow(content)
      showNotification("✓ Workflow loaded!")
    stopPolling()
```

## PNG File Structure

### Example PNG Layout
```
[PNG Signature: 8 bytes]
[IHDR chunk: Image header]
[... other chunks ...]
[tEXt chunk: "tStorie-workflow" → compressed_data]
[IEND chunk: End marker]
```

### tEXt Chunk Format
```
[Length: 4 bytes, big-endian]
[Type: "tEXt" (4 bytes)]
[Keyword: "tStorie-workflow\0" (null-terminated)]
[Text: base64url(deflate(content))]
[CRC32: 4 bytes, big-endian]
```

## Advantages

### vs URL Sharing
- **No length limits** - URLs have practical limits (2-8KB)
- **Visual preview** - Shows what the workflow creates
- **Offline sharing** - No server needed
- **Platform agnostic** - Works on all file sharing platforms

### vs JSON Files
- **Visual context** - PNG shows output, JSON is just data
- **Social sharing** - Images work on Twitter, Discord, forums
- **Discoverability** - People can see what it does before loading

### vs Gist/Pastebin
- **No external service** - Completely self-contained
- **No accounts** - No API keys or rate limits
- **Permanent** - Won't disappear if service shuts down
- **Privacy** - Content never leaves user's machine

## Technical Details

### CRC32 Implementation
```javascript
function calculateCRC32(data) {
    let crc = 0xFFFFFFFF;
    const crcTable = new Uint32Array(256);
    
    // Build CRC table
    for (let n = 0; n < 256; n++) {
        let c = n;
        for (let k = 0; k < 8; k++) {
            c = (c & 1) ? (0xEDB88320 ^ (c >>> 1)) : (c >>> 1);
        }
        crcTable[n] = c;
    }
    
    // Calculate CRC
    for (let i = 0; i < data.length; i++) {
        crc = crcTable[(crc ^ data[i]) & 0xFF] ^ (crc >>> 8);
    }
    
    return (crc ^ 0xFFFFFFFF) >>> 0;
}
```

### Chunk Injection Strategy
1. Read entire PNG into memory
2. Locate IEND chunk (search backwards for "IEND" signature)
3. Create new tEXt chunk with workflow data
4. Splice new chunk before IEND
5. Write combined data to new Blob

### Compression
- Uses browser's native `CompressionStream` with `deflate-raw`
- Same compression as URL sharing (reuses existing code)
- Typically 70-90% size reduction
- Fast enough for real-time export

## Browser Compatibility

### Required APIs
- ✅ Canvas API (toBlob) - All modern browsers
- ✅ CompressionStream - Chrome 80+, Safari 16.4+, Firefox 113+
- ✅ TextEncoder/TextDecoder - All modern browsers
- ✅ ArrayBuffer/Uint8Array - All modern browsers

### Fallbacks
For older browsers without CompressionStream:
- Could fall back to uncompressed storage
- Or use a polyfill (pako.js ~45KB)
- tStorie already requires CompressionStream for URL sharing

## Security Considerations

### Safe Operations
- ✅ Only reads/writes PNG tEXt chunks
- ✅ No code execution from PNG
- ✅ Validates PNG structure before parsing
- ✅ Sandbox-friendly (works in strict CSP)

### User Control
- User must explicitly import (file picker or drag-drop)
- Content is validated before loading
- No automatic execution
- User sees preview before running

## Future Enhancements

### Potential Features
1. **Drag-and-drop import** - Drop PNG anywhere to load
2. **Multiple workflows** - Store multiple chunks with different names
3. **Metadata** - Author, timestamp, version in separate chunks
4. **Thumbnails** - Generate preview thumbnails for workflow library
5. **iTXt chunks** - Support international text with UTF-8
6. **Encryption** - Optional password-protected workflows

### ComfyUI Compatibility
Could potentially read ComfyUI PNG files if we:
- Parse their `workflow` and `prompt` chunks
- Convert their JSON format to tStorie format
- Provide migration/conversion utilities

## Testing

### Manual Testing
1. Create content in tStorie editor
2. Click "Export to PNG"
3. Verify PNG downloads with visual screenshot
4. Import PNG in new session
5. Verify content matches exactly

### Automated Testing
```nim
# Test compression/decompression round-trip
let original = "test content"
let png = await captureTerminalToPNG(original)
let extracted = await extractWorkflowFromPNG(png)
assert extracted == original

# Test chunk manipulation
let chunk = createPNGTextChunk("test", "data")
assert chunk.length == 4 + 4 + 4 + 1 + 4 + 4  # header + data + crc

# Test CRC32
let crc = calculateCRC32([116, 69, 88, 116])  # "tEXt"
assert crc == 0x5D9E6D2D  # Known value
```

## Troubleshooting

### Export Issues
- **Black screenshot**: Check if terminal canvas is visible
- **No download**: Check browser download permissions
- **Large file**: Normal, PNG is uncompressed image + metadata

### Import Issues
- **No workflow found**: PNG might not have tStorie metadata
- **Corrupt data**: CRC validation failed, file damaged
- **File picker doesn't open**: Check browser file API support

### Performance
- **Slow export**: Large terminal screenshots take time to encode
- **Slow import**: CRC validation on large PNGs is CPU intensive
- **Memory usage**: Entire PNG loaded into memory during processing

## References

- [PNG Specification](http://www.libpng.org/pub/png/spec/1.2/PNG-Structure.html)
- [ComfyUI Workflow Embedding](https://github.com/comfyanonymous/ComfyUI)
- [Compression Streams API](https://developer.mozilla.org/en-US/docs/Web/API/Compression_Streams_API)
- [Canvas API](https://developer.mozilla.org/en-US/docs/Web/API/Canvas_API)
