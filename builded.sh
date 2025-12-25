#!/bin/bash
# TStoried (TStorie Editor) build script - unified native and web compilation

VERSION="0.1.0"

show_help() {
    cat << EOF
TStoried v$VERSION
TStorie Editor/Daemon - Terminal markdown editor with GitHub Gist integration

Usage: ./builded.sh [OPTIONS]

Build Targets:
  -n, --native          Build native binary (default)
  -w, --web             Build WebAssembly version
  -a, --all             Build both native and web versions

Options:
  -h, --help            Show this help message
  -v, --version         Show version information
  -d, --debug           Compile in debug mode (default is release with size optimization)
  -r, --run             Run after building (native only)
  -s, --serve           Start web server after building (web only)
  -t, --token TOKEN     Inject GitHub token at compile-time (use with caution)
  -c, --compile-only    Compile without running

Output:
  Native:  tstoried (Linux/macOS) or tstoried.exe (Windows)
  Web:     web/tstoried.js and web/tstoried.wasm

Examples:
  ./builded.sh                          # Build native binary
  ./builded.sh -w                       # Build for web
  ./builded.sh -a                       # Build both native and web
  ./builded.sh -r                       # Build and run native
  ./builded.sh -w -s                    # Build web and serve
  ./builded.sh -d -r                    # Build debug native and run
  ./builded.sh -w -t "ghp_..."          # Build web with GitHub token

Security Note:
  Using -t/--token embeds the token in the binary. Only use for:
  - Local/private deployments
  - Educational environments on isolated networks
  See docs/md/CLASSROOM_SETUP.md for secure token handling

EOF
}

# Default values
BUILD_NATIVE=true
BUILD_WEB=false
RELEASE_MODE="-d:release --opt:size -d:strip -d:useMalloc"
RUN_AFTER=false
SERVE_AFTER=false
GITHUB_TOKEN=""
COMPILE_ONLY=false

# Parse arguments
while [[ $# -gt 0 ]]; do
    case $1 in
        -h|--help)
            show_help
            exit 0
            ;;
        -v|--version)
            echo "TStoried v$VERSION"
            exit 0
            ;;
        -n|--native)
            BUILD_NATIVE=true
            BUILD_WEB=false
            shift
            ;;
        -w|--web)
            BUILD_NATIVE=false
            BUILD_WEB=true
            shift
            ;;
        -a|--all)
            BUILD_NATIVE=true
            BUILD_WEB=true
            shift
            ;;
        -d|--debug)
            RELEASE_MODE="-d:debug"
            shift
            ;;
        -r|--run)
            RUN_AFTER=true
            shift
            ;;
        -s|--serve)
            SERVE_AFTER=true
            shift
            ;;
        -t|--token)
            GITHUB_TOKEN="$2"
            shift 2
            ;;
        -c|--compile-only)
            COMPILE_ONLY=true
            shift
            ;;
        *)
            echo "Unknown option: $1"
            echo "Use -h or --help for usage information"
            exit 1
            ;;
    esac
done

# Color output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

echo -e "${BLUE}TStoried Build Script v$VERSION${NC}"
echo ""

# Check if Nim is installed
if ! command -v nim &> /dev/null; then
    echo -e "${RED}Error: Nim compiler not found${NC}"
    echo "Please install Nim: https://nim-lang.org/install.html"
    exit 1
fi

# Build token argument if provided
TOKEN_ARG=""
if [ -n "$GITHUB_TOKEN" ]; then
    echo -e "${YELLOW}Warning: Embedding GitHub token in binary${NC}"
    echo -e "${YELLOW}This should only be used for local/private deployments${NC}"
    echo ""
    TOKEN_ARG="-d:githubToken=\"$GITHUB_TOKEN\""
fi

# ================================================================
# BUILD NATIVE
# ================================================================

if [ "$BUILD_NATIVE" = true ]; then
    echo -e "${GREEN}Building native tstoried...${NC}"
    
    # Determine output name based on platform
    OUTPUT="tstoried"
    if [[ "$OSTYPE" == "msys" || "$OSTYPE" == "win32" ]]; then
        OUTPUT="tstoried.exe"
    fi
    
    # Build command
    BUILD_CMD="nim c $RELEASE_MODE $TOKEN_ARG --out:$OUTPUT tstoried.nim"
    
    echo "Command: $BUILD_CMD"
    echo ""
    
    # Execute build
    eval $BUILD_CMD
    BUILD_EXIT=$?
    
    if [ $BUILD_EXIT -eq 0 ]; then
        echo ""
        echo -e "${GREEN}✓ Native build successful: $OUTPUT${NC}"
        
        # Show binary size
        if command -v ls &> /dev/null; then
            SIZE=$(ls -lh "$OUTPUT" | awk '{print $5}')
            echo -e "  Binary size: $SIZE"
        fi
        
        # Run if requested and not compile-only
        if [ "$RUN_AFTER" = true ] && [ "$COMPILE_ONLY" = false ]; then
            echo ""
            echo -e "${BLUE}Running tstoried...${NC}"
            echo "Press Ctrl+Q to quit"
            echo ""
            ./"$OUTPUT"
        fi
    else
        echo ""
        echo -e "${RED}✗ Native build failed${NC}"
        exit 1
    fi
    
    echo ""
fi

# ================================================================
# BUILD WEB
# ================================================================

if [ "$BUILD_WEB" = true ]; then
    echo -e "${GREEN}Building web tstoried...${NC}"
    
    # Check for Emscripten
    if ! command -v emcc &> /dev/null; then
        echo -e "${RED}Error: Emscripten not found${NC}"
        echo "Emscripten is required for WebAssembly compilation"
        echo ""
        echo "Setup Emscripten:"
        echo "  git clone https://github.com/emscripten-core/emsdk.git"
        echo "  cd emsdk"
        echo "  ./emsdk install latest"
        echo "  ./emsdk activate latest"
        echo "  source ./emsdk_env.sh"
        exit 1
    fi
    
    # Create web output directory
    mkdir -p web
    
    # Build command for web
    WEB_BUILD_CMD="nim js $RELEASE_MODE $TOKEN_ARG --out:web/tstoried.js tstoried.nim"
    
    echo "Command: $WEB_BUILD_CMD"
    echo ""
    
    # Execute build
    eval $WEB_BUILD_CMD
    BUILD_EXIT=$?
    
    if [ $BUILD_EXIT -eq 0 ]; then
        echo ""
        echo -e "${GREEN}✓ Web build successful${NC}"
        echo -e "  Output: web/tstoried.js"
        
        # Show file sizes
        if command -v ls &> /dev/null; then
            if [ -f "web/tstoried.js" ]; then
                SIZE=$(ls -lh web/tstoried.js | awk '{print $5}')
                echo -e "  JS size: $SIZE"
            fi
        fi
        
        # Create minimal HTML wrapper if it doesn't exist
        if [ ! -f "web/tstoried.html" ]; then
            cat > web/tstoried.html << 'HTMLEOF'
<!DOCTYPE html>
<html>
<head>
    <meta charset="utf-8">
    <meta name="viewport" content="width=device-width, initial-scale=1.0">
    <title>TStoried - TStorie Editor</title>
    <style>
        body {
            margin: 0;
            padding: 0;
            background: #1a1a1a;
            color: #ffffff;
            font-family: monospace;
            overflow: hidden;
        }
        #terminal {
            width: 100vw;
            height: 100vh;
        }
    </style>
</head>
<body>
    <div id="terminal"></div>
    <script src="tstoried.js"></script>
</body>
</html>
HTMLEOF
            echo -e "  Created: web/tstoried.html"
        fi
        
        # Serve if requested
        if [ "$SERVE_AFTER" = true ]; then
            echo ""
            echo -e "${BLUE}Starting web server...${NC}"
            
            # Try different server options
            if command -v python3 &> /dev/null; then
                echo "Server running at http://localhost:8000/tstoried.html"
                echo "Press Ctrl+C to stop"
                cd web && python3 -m http.server 8000
            elif command -v python &> /dev/null; then
                echo "Server running at http://localhost:8000/tstoried.html"
                echo "Press Ctrl+C to stop"
                cd web && python -m SimpleHTTPServer 8000
            elif command -v php &> /dev/null; then
                echo "Server running at http://localhost:8000/tstoried.html"
                echo "Press Ctrl+C to stop"
                cd web && php -S localhost:8000
            else
                echo -e "${YELLOW}No web server available (python3, python, or php)${NC}"
                echo "Install one to use -s/--serve option"
                echo "Or manually open: web/tstoried.html"
            fi
        fi
    else
        echo ""
        echo -e "${RED}✗ Web build failed${NC}"
        exit 1
    fi
    
    echo ""
fi

# ================================================================
# DONE
# ================================================================

echo -e "${GREEN}Build complete!${NC}"

if [ "$BUILD_NATIVE" = true ]; then
    echo ""
    echo "Run native editor:"
    echo "  ./tstoried                    # New document"
    echo "  ./tstoried file.md            # Open file"
    echo "  ./tstoried --gist abc123      # Load gist"
fi

if [ "$BUILD_WEB" = true ]; then
    echo ""
    echo "Web version ready:"
    echo "  Open: web/tstoried.html"
    if [ "$SERVE_AFTER" = false ]; then
        echo "  Or run: ./builded.sh -w -s"
    fi
fi

echo ""
echo "For help: ./tstoried --help"
