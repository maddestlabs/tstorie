# URL Sharing with Compressed Content

t|Storie now supports sharing content directly via URL using compressed data. This allows you to create shareable links for presentations and small apps without needing to host files separately.

## Features

- **Compression**: Uses `deflate-raw` compression to minimize URL length
- **Base64URL encoding**: URL-safe encoding (no special characters)
- **WASM-only**: Works in the web version without adding weight to the native binary
- **Browser API**: Modern CompressionStream API (no external dependencies)

## Usage

### Automatic URL Loading

Simply add `?content=decode:COMPRESSED_DATA` to your t|Storie URL:

```
https://your-tstorie-url/?content=decode:eJxLTkzOzsxLyy8...
```

The content will be automatically decompressed and loaded when the page loads.

### Generating Shareable URLs

#### Method 1: Using the Test Tool

Open `url-share-test.html` in your browser:
1. Paste your markdown content
2. Click "Generate Shareable URL"
3. Copy and share the generated URL

#### Method 2: Browser Console

On the main t|Storie page, use these functions in the developer console:

```javascript
// Generate a shareable URL
const url = await generateShareableUrl("# My Content\nSlide 1...");
console.log(url);

// Generate and copy to clipboard
await copyShareableUrl("# My Content\nSlide 1...");
```

## Browser Support

Requires browsers with CompressionStream API support:
- Chrome 80+
- Edge 80+
- Safari 16.4+
- Firefox 113+

## Examples

### Simple Presentation

```
?content=decode:eJxLzkzPKC1Kzs8tKEktqlQoSCwpSk0syczP06vIzEvLL8pNLMnMz1NILVZILC5JzS0sSszMSwcA7hgVKA
```

### With Other Parameters

You can combine with other URL parameters:

```
?content=decode:eJx...&font=Fira+Code&fontsize=16
```

## Technical Details

### Compression Process

1. Content is encoded to UTF-8 bytes
2. Compressed using `deflate-raw` algorithm
3. Converted to base64
4. URL-safe encoding applied (replace `+` with `-`, `/` with `_`, remove `=`)

### Decompression Process

1. URL-safe encoding reversed
2. Base64 decoded to bytes
3. Decompressed using `deflate-raw`
4. Decoded back to UTF-8 string

### Implementation

The implementation uses the modern Compression Streams API:

```javascript
async function compress(string) {
    const byteArray = new TextEncoder().encode(string);
    const stream = new CompressionStream('deflate-raw');
    const writer = stream.writable.getWriter();
    writer.write(byteArray);
    writer.close();
    const buffer = await new Response(stream.readable).arrayBuffer();
    return btoa(String.fromCharCode(...new Uint8Array(buffer)))
        .replace(/\+/g, '-')
        .replace(/\//g, '_')
        .replace(/=/g, '');
}
```

## Best Practices

1. **Keep it reasonable**: While compression helps, URLs over 2000 characters may have compatibility issues with some servers/browsers
2. **Test before sharing**: Use the test tool or `testDecompression()` to verify your content compresses and decompresses correctly
3. **Consider alternatives**: For very large content, use gist: or demo: loading methods instead

## URL Parameter Precedence

When multiple content sources are specified, t|Storie checks in this order:
1. `decode:` - Compressed inline content
2. `browser:` / `local:` - localStorage
3. `gist:` - GitHub Gist ID
4. `demo:` - Local demo file

## Compression Ratios

Typical compression ratios for markdown content:
- Plain text: 30-40% of original size
- Markdown with code: 35-45% of original size
- Highly repetitive content: 20-30% of original size

Example:
- 500 bytes of markdown → ~175 bytes compressed (35%)
- 1KB of markdown → ~350 bytes compressed (35%)
- 2KB of markdown → ~700 bytes compressed (35%)

## Limitations

- **URL length**: Most browsers support URLs up to 2000+ characters, but keep URLs shorter when possible
- **Browser support**: Older browsers without CompressionStream API cannot use this feature
- **Size**: Best for small to medium content (< 5KB original size recommended)
- **Web-only**: This feature only works in the WASM/web build, not in the native terminal version
