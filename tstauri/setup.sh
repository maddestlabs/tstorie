#!/bin/bash
# Quick script to prepare tStauri for development or release

set -e

ACTION="${1:-dev}"

case "$ACTION" in
  dev)
    echo "🚀 Preparing for local development..."
    echo ""
    
    # Check if WASM exists
    if [ ! -f "../docs/tstorie.wasm.wasm" ]; then
      echo "⚠️  WASM files not found. Building..."
      cd ..
      ./build-web.sh -o docs
      cd tstauri
    else
      echo "✓ WASM files found"
    fi
    
    # Generate icons if they don't exist
    if [ ! -f "src-tauri/icons/icon.ico" ]; then
      echo "🎨 Generating icons..."
      bash generate-icons.sh
    else
      echo "✓ Icons exist"
    fi
    
    # Install dependencies
    if [ ! -d "node_modules" ]; then
      echo "📦 Installing dependencies..."
      npm install
    else
      echo "✓ Dependencies installed"
    fi
    
    echo ""
    echo "✅ Ready for development!"
    echo ""
    echo "Run: npm run dev"
    ;;
    
  release)
    echo "📦 Preparing for release..."
    echo ""
    
    # Rebuild WASM
    echo "🔨 Building latest WASM..."
    cd ..
    ./build-web.sh -o docs
    cd tstauri
    
    # Regenerate icons
    echo "🎨 Regenerating icons..."
    bash generate-icons.sh
    
    # Update dependencies
    echo "📦 Updating dependencies..."
    npm install
    
    # Run a quick test build
    echo "🧪 Testing build..."
    npm run build
    
    echo ""
    echo "✅ Release preparation complete!"
    echo ""
    echo "Next steps:"
    echo "1. Test the built binary in src-tauri/target/release/bundle/"
    echo "2. If good, create a git tag: git tag tstauri-v0.1.0"
    echo "3. Push the tag: git push origin tstauri-v0.1.0"
    echo "4. Or use manual dispatch on GitHub Actions"
    ;;
    
  clean)
    echo "🧹 Cleaning build artifacts..."
    rm -rf node_modules
    rm -rf src-tauri/target
    echo "✅ Clean complete"
    ;;
    
  icons)
    echo "🎨 Regenerating icons only..."
    bash generate-icons.sh
    echo "✅ Icons updated"
    ;;
    
  *)
    echo "tStauri Quick Setup Script"
    echo ""
    echo "Usage: ./setup.sh [command]"
    echo ""
    echo "Commands:"
    echo "  dev       Prepare for local development (default)"
    echo "  release   Prepare for a release build"
    echo "  icons     Regenerate icons only"
    echo "  clean     Remove build artifacts"
    echo ""
    echo "Examples:"
    echo "  ./setup.sh dev       # Get ready to develop"
    echo "  ./setup.sh release   # Prepare a release"
    echo "  ./setup.sh icons     # Update icons"
    ;;
esac
