# PNG Workflow Integration Guide

## Quick Start: Adding PNG Export/Import to Your UI

### Step 1: Add Export Button
```nim
# In your editor UI code:
proc onExportPNG() =
  let content = getEditorContent()  # Your current editor content
  let filename = "my-workflow"      # Or get from user
  
  # Start export
  exportToPNG(content, filename)
  showStatus("Exporting PNG...")
  
  # Poll for completion
  scheduleAsyncCheck(checkPNGExportStatus)

proc checkPNGExportStatus() =
  if checkPngExportReady() == "true":
    let error = getPngExportError()
    if error == "":
      showStatus("✓ PNG exported!")
    else:
      showError("Export failed: " & error)
  else:
    # Check again in 100ms
    scheduleAsyncCheck(checkPNGExportStatus, 100)
```

### Step 2: Add Import Button
```nim
proc onImportPNG() =
  # Open file picker
  importFromPNG()
  showStatus("Select PNG file...")
  
  # Poll for completion
  scheduleAsyncCheck(checkPNGImportStatus)

proc checkPNGImportStatus() =
  if checkPngImportReady() == "true":
    let content = getPngImportContent()
    if content != "":
      loadEditorContent(content)
      showStatus("✓ Workflow loaded!")
    else:
      showStatus("No workflow found in PNG")
  else:
    # Check again in 100ms
    scheduleAsyncCheck(checkPNGImportStatus, 100)
```

## Available Functions

### Export Functions
```nim
# Trigger PNG export (captures terminal screenshot + embeds content)
exportToPNG(content: string, filename: string)

# Check if export completed
checkPngExportReady() → "true" | "false"

# Get error message if export failed
getPngExportError() → string  # Empty if no error
```

### Import Functions
```nim
# Open file picker to select PNG
importFromPNG()

# Check if import completed
checkPngImportReady() → "true" | "false"

# Get imported content (clears after reading)
getPngImportContent() → string  # Empty if no content
```

## Integration Examples

### Example 1: Simple Export Dialog
```nim
proc showExportDialog() =
  let dialog = createDialog("Export Workflow")
  
  dialog.addButton("Export as URL"):
    generateAndCopyShareUrl(getEditorContent())
    showStatus("URL copied to clipboard!")
  
  dialog.addButton("Export as PNG"):
    let name = dialog.getFilename() or "workflow"
    exportToPNG(getEditorContent(), name)
    waitForExport()
  
  dialog.show()

proc waitForExport() =
  if checkPngExportReady() == "true":
    if getPngExportError() == "":
      showStatus("✓ PNG saved!")
    else:
      showError(getPngExportError())
  else:
    sleep(50)
    waitForExport()
```

### Example 2: Menu Integration
```nim
# Add to your main menu
menu.addItem("File"):
  submenu.addItem("Export to PNG", onExportPNG)
  submenu.addItem("Import from PNG", onImportPNG)
  submenu.addSeparator()
  submenu.addItem("Share via URL", onShareURL)

proc onExportPNG() =
  exportToPNG(getEditorContent(), "workflow")
  asyncWait(checkPngExportReady, onExportComplete)

proc onExportComplete() =
  let error = getPngExportError()
  if error == "":
    notify("PNG exported successfully!")
  else:
    notify("Export failed: " & error)

proc onImportPNG() =
  importFromPNG()
  asyncWait(checkPngImportReady, onImportComplete)

proc onImportComplete() =
  let content = getPngImportContent()
  if content != "":
    if confirmOverwrite():
      setEditorContent(content)
      notify("Workflow loaded!")
  else:
    notify("No workflow in PNG")
```

### Example 3: Drag-and-Drop (Future Enhancement)
```nim
# This would require additional JS code to handle drop events
proc enableDragDrop() =
  # JavaScript side would be:
  # document.addEventListener('drop', async (e) => {
  #   const file = e.dataTransfer.files[0]
  #   if (file.type === 'image/png') {
  #     const content = await extractWorkflowFromPNG(file)
  #     window.tStorie_droppedContent = content
  #   }
  # })
  
  # Nim side polls for dropped content:
  proc checkForDrops() =
    let dropped = getDroppedContent()
    if dropped != "":
      loadEditorContent(dropped)
      showStatus("✓ Loaded from dropped PNG!")
```

### Example 4: Auto-Save with PNG Snapshots
```nim
proc autoSavePNG() =
  # Save current work as PNG every 5 minutes
  while true:
    sleep(300_000)  # 5 minutes
    
    let timestamp = getTimestamp()
    let filename = "autosave-" & timestamp
    
    exportToPNG(getEditorContent(), filename)
    
    # Wait for completion
    while checkPngExportReady() != "true":
      sleep(100)
    
    if getPngExportError() == "":
      echo "Auto-saved: ", filename, ".png"

# Start auto-save in background
spawn autoSavePNG()
```

## UI Design Tips

### Export Button
- **Icon**: 📷 or 💾 or 🖼️
- **Tooltip**: "Export as PNG (screenshot + workflow)"
- **Shortcut**: Ctrl/Cmd + Shift + E
- **Feedback**: Show progress spinner, then checkmark

### Import Button
- **Icon**: 📂 or 📥 or 🖼️
- **Tooltip**: "Import workflow from PNG"
- **Shortcut**: Ctrl/Cmd + Shift + I
- **Feedback**: Show file picker, then loading state

### Status Messages
```
Exporting...
✓ PNG exported!
⚠ Export failed: Canvas not ready
Loading workflow...
✓ Workflow loaded!
⚠ No workflow found in PNG
```

## Error Handling

### Common Errors
```nim
proc safePNGExport(content: string, filename: string) =
  # Check if canvas is ready
  if not isCanvasReady():
    showError("Please wait for terminal to initialize")
    return
  
  # Check content size
  if content.len == 0:
    showError("Nothing to export")
    return
  
  # Start export
  exportToPNG(content, filename)
  
  # Wait and check for errors
  while checkPngExportReady() != "true":
    sleep(50)
  
  let error = getPngExportError()
  if error != "":
    showError("Export failed: " & error)
    logError(error)

proc safePNGImport() =
  importFromPNG()
  
  # Set timeout in case user cancels
  var timeout = 0
  while checkPngImportReady() != "true":
    sleep(100)
    timeout += 100
    if timeout > 30000:  # 30 second timeout
      showError("Import timeout (user may have cancelled)")
      return
  
  let content = getPngImportContent()
  if content == "":
    showInfo("No workflow found or import cancelled")
  else:
    loadEditorContent(content)
```

### Validation
```nim
proc validatePNGContent(content: string): bool =
  # Check if content looks valid
  if content.len == 0:
    return false
  
  # Check for expected markers/format
  if not content.startsWith("#") and not content.contains("proc"):
    showWarning("Content may not be a valid tStorie workflow")
  
  return true

proc safeLoadPNG() =
  importFromPNG()
  
  while checkPngImportReady() != "true":
    sleep(50)
  
  let content = getPngImportContent()
  if content != "" and validatePNGContent(content):
    loadEditorContent(content)
  elif content != "":
    if confirmLoad("Content looks unusual, load anyway?"):
      loadEditorContent(content)
```

## Performance Considerations

### Large Content
```nim
proc smartPNGExport(content: string) =
  # Warn for very large content
  if content.len > 1_000_000:  # 1MB
    if not confirm("Content is very large. Continue export?"):
      return
  
  # Show progress for large exports
  if content.len > 100_000:  # 100KB
    showProgress("Compressing content...")
  
  exportToPNG(content, "large-workflow")
  
  # Poll with progress updates
  var dots = ""
  while checkPngExportReady() != "true":
    dots = if dots.len > 3: "" else: dots & "."
    showProgress("Exporting" & dots)
    sleep(200)
  
  hideProgress()
```

### Async Patterns
```nim
# Use callbacks to avoid blocking
type ExportCallback = proc()

var exportCallbacks: seq[ExportCallback]

proc exportPNGAsync(content: string, filename: string, onComplete: ExportCallback) =
  exportToPNG(content, filename)
  exportCallbacks.add(onComplete)
  startPolling()

proc pollExports() =
  if checkPngExportReady() == "true":
    for cb in exportCallbacks:
      cb()
    exportCallbacks.setLen(0)
    stopPolling()

# Usage:
exportPNGAsync(content, "workflow"):
  echo "Export completed!"
  showNotification("PNG saved")
```

## Testing

### Manual Test Checklist
- [ ] Export creates PNG file
- [ ] PNG shows correct terminal screenshot
- [ ] Import restores exact content
- [ ] Large content (>100KB) works
- [ ] Unicode content works
- [ ] Empty content handled gracefully
- [ ] User cancel handled gracefully
- [ ] Multiple exports in sequence work
- [ ] Export + immediate import works

### Automated Tests
```nim
proc testPNGWorkflow() =
  let original = "# Test Workflow\necho 'Hello PNG!'"
  
  # Export
  exportToPNG(original, "test")
  while checkPngExportReady() != "true":
    sleep(10)
  
  assert getPngExportError() == "", "Export failed"
  
  # Import
  importFromPNG()
  while checkPngImportReady() != "true":
    sleep(10)
  
  let imported = getPngImportContent()
  assert imported == original, "Content mismatch"
  
  echo "✓ PNG workflow test passed"
```

## Next Steps

1. Add buttons to your UI
2. Test with small content first
3. Test with large content (>100KB)
4. Add keyboard shortcuts
5. Add status indicators
6. Consider auto-save feature
7. Add to documentation
8. Test on different browsers
