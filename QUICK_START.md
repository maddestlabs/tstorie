# Quick Start - URL Content Sharing

## What's New?

t|Storie now supports sharing content via compressed URL parameters! 🎉

## Usage

### 1. Load Compressed Content

Add `?content=decode:COMPRESSED_DATA` to your URL:

```
http://localhost:8001/?content=decode:TZC9TsRADIT7fYo5pQ4V4gWQEAUF4gWQE...
```

### 2. Generate Shareable URLs

Open your browser console on the t|Storie page and use:

```javascript
// Generate URL
await generateShareableUrl("# My Story\nSlide 1...");

// Generate and copy to clipboard
await copyShareableUrl("# My Story\nSlide 1...");
```

### 3. Use the Test Tool

Open `http://localhost:8001/url-share-test.html` for an interactive UI to:
- Paste markdown content
- Generate shareable URLs
- View compression statistics
- Test the round-trip compression

## Example

Test this URL (paste into your browser):
```
http://localhost:8001/?content=decode:TZC9TsRADIT7fYo5pQ4V4gWQEAUF4u5E7dt1iHX7E9kOkRAPj_ZEEK3t-cYzA945x1YY3uDfR28qHE6zGMRAMClLZizKxtXJpVX4TI5IFReGzaSc8CmE89vLIYRxHMMw4InJV2ULIx5b6XJDIb2mtlXEVp2rhxHHLt_VWEipsLP2TaGcMUlmmHyxYROfkXjK5Iz4y5RW_yyf2wZxbE2vFk4z7zY9yH7PCatJ_dhBo9IGqglcY0ucIBUXMn64XzVjalrI70J4ZZ04eh_cEneC3R6kZbEb4H9DdvgB
```

This will load a sample presentation about t|Storie features!

## Files Changed

- ✏️ `/web/index.html` - Added compression support (source file)
- ✨ `/docs/url-share-test.html` - Interactive test tool
- 📚 `/docs/md/url-sharing.md` - Complete documentation
- 🧪 `/test-compression.js` - Node.js test script

## How It Works

1. Content is compressed using `deflate-raw`
2. Encoded in base64url format (URL-safe)
3. Added as `?content=decode:XXX` parameter
4. Automatically decompressed and loaded on page load

## Benefits

- ✓ No server needed - share content in the URL itself
- ✓ Good compression (~35-45% of original size)
- ✓ Simple - just add to URL parameter
- ✓ Secure - no data stored on servers
- ✓ Web-only - no bloat in native builds

## Browser Support

Works in modern browsers with CompressionStream API:
- Chrome 80+
- Edge 80+
- Safari 16.4+
- Firefox 113+

## Testing

The server is running at `http://localhost:8001`

Try:
1. Main page: http://localhost:8001/
2. Test tool: http://localhost:8001/url-share-test.html
3. Example URL with content (from above)

## Next Steps

You can now:
1. Share small t|Storie apps via URL
2. Embed presentations in links
3. Create shareable demos without hosting files
4. Use in documentation, emails, social media, etc.

Enjoy! 🚀
