# PNG Workflow System Architecture

## System Overview

```
┌─────────────────────────────────────────────────────────────┐
│                      tStorie Application                     │
│                                                               │
│  ┌───────────────────┐         ┌───────────────────┐       │
│  │   Nim/WASM Code   │────────▶│   JavaScript API  │       │
│  │                   │         │                   │       │
│  │ exportToPNG()     │         │ tStorie_exportTo  │       │
│  │ importFromPNG()   │         │ PNG()             │       │
│  │ checkReady()      │         │ captureTerminal   │       │
│  └───────────────────┘         │ ToPNG()           │       │
│           │                     └─────────┬─────────┘       │
│           │                               │                 │
│           ▼                               ▼                 │
│  ┌─────────────────────────────────────────────────┐       │
│  │         Browser APIs (Zero Dependencies)         │       │
│  │                                                   │       │
│  │  • Canvas.toBlob()  - Screenshot capture         │       │
│  │  • CompressionStream - Data compression          │       │
│  │  • ArrayBuffer/Uint8Array - Binary manipulation  │       │
│  │  • File API - Import/Export                      │       │
│  └───────────────────────────────────────────────────┘       │
└─────────────────────────────────────────────────────────────┘
```

## Data Flow

### Export Process

```
User Content                Terminal Canvas
     │                            │
     │ 1. Capture                 │
     ├────────────────────────────┤
     │                            │
     ▼                            ▼
┌─────────────────────────────────────┐
│  Terminal Screenshot (Canvas API)   │
│  ┌───────────────────────────────┐  │
│  │ $ echo "tStorie"              │  │
│  │ tStorie                       │  │
│  │ $ ls -la                      │  │
│  │ total 42                      │  │
│  └───────────────────────────────┘  │
└──────────────────┬──────────────────┘
                   │
                   │ 2. Convert to PNG
                   ▼
          ┌────────────────┐
          │  PNG Binary    │
          │  [IHDR][IDAT]  │
          │  [IEND]        │
          └────────┬───────┘
                   │
                   │ 3. Compress Content
                   │
        User Content (text)
                   │
                   ▼
        ┌──────────────────┐
        │ CompressionStream│
        │   (deflate-raw)  │
        └──────────┬───────┘
                   │
                   ▼
        ┌──────────────────┐
        │   Base64URL      │
        │   Encoding       │
        └──────────┬───────┘
                   │
                   │ 4. Create PNG Chunk
                   ▼
        ┌──────────────────────────┐
        │ tEXt Chunk               │
        │ ┌──────────────────────┐ │
        │ │ Length: 4 bytes      │ │
        │ │ Type: "tEXt"         │ │
        │ │ Keyword: "tStorie-   │ │
        │ │          workflow\0" │ │
        │ │ Data: compressed...  │ │
        │ │ CRC32: 4 bytes       │ │
        │ └──────────────────────┘ │
        └──────────┬───────────────┘
                   │
                   │ 5. Inject Before IEND
                   ▼
          ┌────────────────────┐
          │  Final PNG         │
          │  [IHDR][IDAT]      │
          │  [tEXt]  ← Data!   │
          │  [IEND]            │
          └──────────┬─────────┘
                     │
                     │ 6. Download
                     ▼
             ┌──────────────┐
             │ workflow.png │
             └──────────────┘
```

### Import Process

```
    workflow.png (File)
           │
           │ 1. Read File
           ▼
    ┌──────────────┐
    │ ArrayBuffer  │
    │ (PNG bytes)  │
    └──────┬───────┘
           │
           │ 2. Parse PNG Structure
           ▼
    ┌───────────────────────────┐
    │ PNG Chunks                │
    │ ┌─────────────────────┐   │
    │ │ IHDR (header)       │   │
    │ │ IDAT (image data)   │   │
    │ │ tEXt (metadata) ←───┼───┤ Extract this!
    │ │ IEND (end marker)   │   │
    │ └─────────────────────┘   │
    └───────────────┬───────────┘
                    │
                    │ 3. Extract tEXt Chunks
                    ▼
         ┌─────────────────────┐
         │ Find "tStorie-      │
         │      workflow"      │
         └──────────┬──────────┘
                    │
                    │ 4. Get Compressed Data
                    ▼
         ┌─────────────────────┐
         │ Base64URL Decode    │
         └──────────┬──────────┘
                    │
                    ▼
         ┌─────────────────────┐
         │ DecompressionStream │
         │   (deflate-raw)     │
         └──────────┬──────────┘
                    │
                    │ 5. Restore Content
                    ▼
         ┌─────────────────────┐
         │  Original Content   │
         │  # My Workflow      │
         │  echo "Hello"       │
         │  ...                │
         └─────────────────────┘
```

## Component Interaction

```
┌──────────────────────────────────────────────────────────────┐
│                        UI Layer (Your Code)                   │
│                                                                │
│  ┌────────────┐  ┌────────────┐  ┌──────────────┐           │
│  │ [Export]   │  │ [Import]   │  │ [Save/Load]  │           │
│  │  Button    │  │  Button    │  │   Dialog     │           │
│  └─────┬──────┘  └──────┬─────┘  └──────┬───────┘           │
│        │                 │                │                   │
└────────┼─────────────────┼────────────────┼───────────────────┘
         │                 │                │
         ▼                 ▼                ▼
┌──────────────────────────────────────────────────────────────┐
│                    Nim API Layer                              │
│                                                                │
│  exportToPNG(content, filename)                               │
│  importFromPNG()                                              │
│  checkPngExportReady() → "true"/"false"                       │
│  checkPngImportReady() → "true"/"false"                       │
│  getPngExportError() → string                                 │
│  getPngImportContent() → string                               │
└────────────────────────┬─────────────────────────────────────┘
                         │
                         ▼
┌──────────────────────────────────────────────────────────────┐
│              JavaScript Bridge (Emscripten)                   │
│                                                                │
│  js_callFunctionWithArg("tStorie_exportToPNG", ...)           │
│  js_callFunction("tStorie_checkPngExportReady")               │
└────────────────────────┬─────────────────────────────────────┘
                         │
                         ▼
┌──────────────────────────────────────────────────────────────┐
│                JavaScript Implementation                       │
│                                                                │
│  ┌──────────────────────────────────────────────────┐        │
│  │ PNG Chunk Manipulation (Pure JS)                 │        │
│  │  • calculateCRC32()                              │        │
│  │  • createPNGTextChunk()                          │        │
│  │  • injectChunkBeforeIEND()                       │        │
│  │  • extractPNGTextChunks()                        │        │
│  └──────────────────────────────────────────────────┘        │
│                                                                │
│  ┌──────────────────────────────────────────────────┐        │
│  │ High-Level Functions                             │        │
│  │  • captureTerminalToPNG()                        │        │
│  │  • extractWorkflowFromPNG()                      │        │
│  └──────────────────────────────────────────────────┘        │
└────────────────────────┬─────────────────────────────────────┘
                         │
                         ▼
┌──────────────────────────────────────────────────────────────┐
│                    Browser APIs                               │
│                                                                │
│  Canvas API           CompressionStream      File API         │
│  • toBlob()          • deflate-raw          • FileReader      │
│  • getContext()      • DecompressionStream  • createObject    │
│                                               URL              │
└──────────────────────────────────────────────────────────────┘
```

## File Organization

```
tstorie/
│
├── PNG_WORKFLOW_README.md          ← Start here!
│
├── web/
│   └── index.html                  ← Implementation (PNG functions)
│
├── src/
│   └── runtime_api.nim             ← Nim API bindings
│
├── docs/
│   ├── PNG_WORKFLOW_SHARING.md     ← Technical deep-dive
│   ├── PNG_WORKFLOW_INTEGRATION.md ← Integration guide
│   ├── PNG_IMPLEMENTATION_SUMMARY.md ← Overview
│   └── png-test.html               ← Test page
│
└── examples/
    └── png_workflow_sharing.nim    ← Usage examples
```

## API Call Flow

### Export Example

```
User Click "Export"
       │
       ▼
┌──────────────────────────────────┐
│ Your UI Code (Nim)               │
│                                  │
│ let content = getEditorContent() │
│ exportToPNG(content, "workflow") │
└──────────────┬───────────────────┘
               │
               ▼
┌──────────────────────────────────────────┐
│ runtime_api.nim                          │
│                                          │
│ proc nimini_exportToPNG():               │
│   js_callFunctionWith2Args(              │
│     "tStorie_exportToPNG",               │
│     content, filename)                   │
└──────────────┬───────────────────────────┘
               │
               ▼
┌──────────────────────────────────────────┐
│ web/index.html                           │
│                                          │
│ window.tStorie_exportToPNG = function(): │
│   const blob = await                     │
│     captureTerminalToPNG(content)        │
│   downloadFile(blob, filename)           │
└──────────────┬───────────────────────────┘
               │
               ▼
┌──────────────────────────────────────────┐
│ async function captureTerminalToPNG():   │
│   1. canvas.toBlob()                     │
│   2. compress(content)                   │
│   3. createPNGTextChunk()                │
│   4. injectChunkBeforeIEND()             │
│   5. return Blob                         │
└──────────────┬───────────────────────────┘
               │
               ▼
         File Download
       (workflow.png)
```

### Import Example

```
User Click "Import"
       │
       ▼
┌──────────────────────────────────┐
│ Your UI Code (Nim)               │
│                                  │
│ importFromPNG()                  │
│ # ... poll for ready ...         │
│ let content =                    │
│   getPngImportContent()          │
└──────────────┬───────────────────┘
               │
               ▼
┌──────────────────────────────────────────┐
│ runtime_api.nim                          │
│                                          │
│ proc nimini_importFromPNG():             │
│   js_callFunction("tStorie_importFromPNG")│
│                                          │
│ proc nimini_getPngImportContent():       │
│   return js_callFunction(                │
│     "tStorie_getPngImportContent")       │
└──────────────┬───────────────────────────┘
               │
               ▼
┌──────────────────────────────────────────┐
│ web/index.html                           │
│                                          │
│ window.tStorie_importFromPNG = function():│
│   openFilePicker()                       │
│   onFileSelected:                        │
│     extractWorkflowFromPNG(file)         │
└──────────────┬───────────────────────────┘
               │
               ▼
┌──────────────────────────────────────────┐
│ async function extractWorkflowFromPNG(): │
│   1. file.arrayBuffer()                  │
│   2. extractPNGTextChunks()              │
│   3. decompress(chunkData)               │
│   4. store in global var                 │
└──────────────┬───────────────────────────┘
               │
               ▼
      Content Available
    (getPngImportContent)
```

## PNG Chunk Structure Detail

```
┌─────────────────────────────────────────────────────┐
│                   PNG File Format                    │
├─────────────────────────────────────────────────────┤
│                                                      │
│  Signature (8 bytes):                               │
│  [137 80 78 71 13 10 26 10]                        │
│  (PNG magic number)                                 │
│                                                      │
├─────────────────────────────────────────────────────┤
│                                                      │
│  IHDR Chunk (Image Header):                         │
│  ┌────────────────────────────────────────────┐    │
│  │ Length:  4 bytes (big-endian)              │    │
│  │ Type:    "IHDR" (4 bytes)                  │    │
│  │ Data:    width, height, bit depth, etc     │    │
│  │ CRC32:   4 bytes (validates type + data)   │    │
│  └────────────────────────────────────────────┘    │
│                                                      │
├─────────────────────────────────────────────────────┤
│                                                      │
│  IDAT Chunk(s) (Image Data):                        │
│  ┌────────────────────────────────────────────┐    │
│  │ Length:  4 bytes                           │    │
│  │ Type:    "IDAT"                            │    │
│  │ Data:    compressed pixel data             │    │
│  │ CRC32:   4 bytes                           │    │
│  └────────────────────────────────────────────┘    │
│  (may have multiple IDAT chunks)                    │
│                                                      │
├─────────────────────────────────────────────────────┤
│                                                      │
│  tEXt Chunk (Our Workflow Data): ◄── WE ADD THIS   │
│  ┌────────────────────────────────────────────┐    │
│  │ Length:  N bytes (size of keyword + text)  │    │
│  │ Type:    "tEXt" (4 bytes)                  │    │
│  │ Data:                                      │    │
│  │   Keyword:  "tStorie-workflow\0"           │    │
│  │             (null-terminated)              │    │
│  │   Text:     base64url(deflate(content))    │    │
│  │             (not null-terminated)          │    │
│  │ CRC32:   4 bytes (validates type + data)   │    │
│  └────────────────────────────────────────────┘    │
│                                                      │
├─────────────────────────────────────────────────────┤
│                                                      │
│  IEND Chunk (End Marker):                           │
│  ┌────────────────────────────────────────────┐    │
│  │ Length:  0 (4 bytes = 0x00000000)          │    │
│  │ Type:    "IEND" (4 bytes)                  │    │
│  │ Data:    (none)                            │    │
│  │ CRC32:   0xAE426082 (known constant)       │    │
│  └────────────────────────────────────────────┘    │
│                                                      │
└─────────────────────────────────────────────────────┘
```

## Memory Flow

```
Export:
  User Content (text)
        │
        ▼
  TextEncoder → Uint8Array
        │
        ▼
  CompressionStream → ArrayBuffer
        │
        ▼
  Base64URL → String
        │
        ▼
  PNG tEXt Chunk → Uint8Array
        │
        ▼
  Canvas Screenshot → ArrayBuffer
        │
        ▼
  Inject Chunk → Uint8Array (PNG + chunk)
        │
        ▼
  Blob → File Download

Import:
  File Upload → File
        │
        ▼
  FileReader → ArrayBuffer
        │
        ▼
  Parse PNG → Uint8Array
        │
        ▼
  Extract tEXt → String (base64url)
        │
        ▼
  Base64URL Decode → Uint8Array
        │
        ▼
  DecompressionStream → ArrayBuffer
        │
        ▼
  TextDecoder → String (content)
```

This architecture provides a clean, maintainable, and efficient system for
PNG-based workflow sharing with zero external dependencies!
