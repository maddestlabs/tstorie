# PNG Workflow Sharing Example
# Demonstrates ComfyUI-style workflow embedding in PNG screenshots

# Example 1: Export current content as PNG
proc exportCurrentWorkflow() =
  let content = """
# My tStorie Workflow
This content will be embedded in the PNG!

You can store:
- Scripts
- Terminal art
- Configurations
- Any text content

The PNG will show a screenshot of your terminal,
but also contain this hidden data!
"""
  
  # Trigger PNG export (captures terminal canvas + embeds content)
  exportToPNG(content, "my-workflow")
  
  # Wait for completion
  while checkPngExportReady() != "true":
    sleep(100)
  
  let error = getPngExportError()
  if error != "":
    echo "Export failed: ", error
  else:
    echo "✓ PNG exported successfully!"


# Example 2: Import workflow from PNG
proc importWorkflow() =
  echo "Select a PNG file with embedded workflow..."
  
  # Open file picker
  importFromPNG()
  
  # Wait for user to select file and processing to complete
  while checkPngImportReady() != "true":
    sleep(100)
  
  # Get the imported content
  let content = getPngImportContent()
  
  if content == "":
    echo "No workflow found in PNG (or user cancelled)"
  else:
    echo "✓ Imported workflow:"
    echo content
    echo ""
    echo "You can now use this content to restore the session!"


# Example 3: Share workflow via URL OR PNG (user choice)
proc shareWorkflow(content: string) =
  echo "Share options:"
  echo "1. URL (copy to clipboard)"
  echo "2. PNG (download file)"
  echo ""
  echo "Choose method [1/2]: "
  
  # In real implementation, you'd get user input
  # For demo, we'll show both methods:
  
  # Method 1: URL sharing
  echo "\n--- URL Sharing ---"
  generateAndCopyShareUrl(content)
  while checkShareUrlReady() != "true":
    sleep(100)
  
  if checkShareUrlCopied() == "true":
    let url = getShareUrl()
    echo "✓ URL copied to clipboard!"
    echo "Share this: ", url
  
  # Method 2: PNG sharing
  echo "\n--- PNG Sharing ---"
  exportToPNG(content, "shared-workflow")
  while checkPngExportReady() != "true":
    sleep(100)
  
  echo "✓ PNG downloaded! Share the image file."
  echo "Anyone can drag & drop it to restore the workflow."


# Example 4: Complete save/load cycle
proc demonstratePngWorkflow() =
  echo "=== PNG Workflow Demo ==="
  echo ""
  
  # Create some content
  let myScript = """
# Terminal Animation Script
for i in range(10):
  print(f"Frame {i}")
  sleep(0.1)
"""
  
  echo "Step 1: Export to PNG"
  exportToPNG(myScript, "demo-workflow")
  
  while checkPngExportReady() != "true":
    sleep(50)
  
  echo "✓ PNG saved with embedded script"
  echo ""
  
  echo "Step 2: Import from PNG"
  echo "(In real use, user would select the saved PNG)"
  importFromPNG()
  
  # Wait for import
  while checkPngImportReady() != "true":
    sleep(50)
  
  let imported = getPngImportContent()
  if imported == myScript:
    echo "✓ Successfully restored workflow!"
  else:
    echo "✗ Import failed or user cancelled"


# Usage in tStorie editor:
# Just call these functions from your UI code:
#
#   exportToPNG(getCurrentEditorContent(), "my-workflow")
#   importFromPNG()  # Opens file picker
#   let content = getPngImportContent()  # After user selects file
