# Loading Demos and Examples

TStorie supports multiple ways to load content:

## 1. Local Demos (Recommended)

All examples from the `/examples/` directory are available as locally-hosted demos on GitHub Pages.

**Usage:**
```
https://maddestlabs.github.io/tstorie/?demo=demo_name
```

**Examples:**
- `?demo=canvas_demo` - Canvas drawing demonstration
- `?demo=clock` - Animated clock
- `?demo=tui_simple` - Simple terminal UI
- `?demo=rainclock` - Rain animation with clock

The `.md` extension is optional and will be added automatically.

**Browse All Demos:**
Visit [/demos/](https://maddestlabs.github.io/tstorie/demos/) for a complete list with descriptions.

## 2. GitHub Gist (Optional)

You can still load content from GitHub Gist for custom/external examples:

**Usage:**
```
https://maddestlabs.github.io/tstorie/?gist=YOUR_GIST_ID
```

The app will automatically find and load the first `.md` file in the gist.

## 3. Additional URL Parameters

You can combine the demo/gist parameter with other options:

**Custom Font:**
```
?demo=clock&font=Roboto+Mono
?demo=canvas_demo&font=https://fonts.googleapis.com/css2?family=Source+Code+Pro
```

**Shader Effects:**
```
?demo=rainclock&shader=SHADER_GIST_ID
```

**Custom Parameters:**
Any other URL parameters are available to your Nim code via `getUrlParam()`:
```
?demo=clock&color=blue&speed=fast
```

## Development

### Building for GitHub Pages

To update the demos on GitHub Pages:

```bash
./build-web.sh -o docs
```

This will:
1. Compile TStorie to WebAssembly
2. Copy all required files to `/docs/`
3. Copy all examples from `/examples/` to `/docs/demos/`

### Local Testing

```bash
cd docs && python3 -m http.server 8000
```

Then open:
- `http://localhost:8000/` - Main app
- `http://localhost:8000/demos/` - Demo browser
- `http://localhost:8000/?demo=clock` - Specific demo

## File Structure

```
/examples/          # Source examples (version controlled)
/docs/              # GitHub Pages deployment
  /demos/           # Copied from /examples/ during build
    audio_demo.md
    canvas_demo.md
    clock.md
    ...
    index.html      # Demo browser
    README.md       # Demo documentation
```

## Advantages of Local Demos

1. **Faster Loading** - No external API calls
2. **No Rate Limits** - GitHub API has rate limits for Gist access
3. **Version Control** - Demos are part of the repository
4. **Offline Development** - Works in local development
5. **Better Organization** - Easy to browse and discover

## Migration from Gist

To minimize Gist usage:
1. ✅ Keep ONE example as a Gist demo (for documentation)
2. ✅ All other examples use `?demo=` parameter
3. ✅ Update documentation links to use demo URLs

Example Gist for documentation purposes:
- Create a gist with a custom example
- Use `?gist=abc123` to demonstrate the feature
- Link to it in README as an example of external content loading
