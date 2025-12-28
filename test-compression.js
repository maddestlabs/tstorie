#!/usr/bin/env node

// Simple Node.js test for the compression/decompression logic
// This validates the algorithm works correctly

const { deflateRawSync, inflateRawSync } = require('zlib');

function compress(string) {
    const buffer = Buffer.from(string, 'utf8');
    const compressed = deflateRawSync(buffer);
    return compressed.toString('base64')
        .replace(/\+/g, '-')
        .replace(/\//g, '_')
        .replace(/=/g, '');
}

function decompress(b64) {
    // Convert base64url to base64
    let base64 = b64.replace(/-/g, '+').replace(/_/g, '/');
    // Add padding
    while (base64.length % 4) {
        base64 += '=';
    }
    
    const buffer = Buffer.from(base64, 'base64');
    const decompressed = inflateRawSync(buffer);
    return decompressed.toString('utf8');
}

// Test content
const testContent = `# Welcome to t|Storie
This is a simple presentation that can be shared via URL!

---
## Features
- Compress markdown content
- Share via URL parameter
- Small file sizes with deflate compression

---
## How it works
The content is compressed using deflate-raw and encoded in base64url format.

Perfect for sharing small apps and presentations!`;

console.log('Testing compression/decompression...\n');
console.log('Original content:');
console.log('-'.repeat(60));
console.log(testContent);
console.log('-'.repeat(60));
console.log(`\nOriginal size: ${testContent.length} bytes`);

// Compress
const compressed = compress(testContent);
console.log(`Compressed size: ${compressed.length} bytes`);
console.log(`Compression ratio: ${(compressed.length / testContent.length * 100).toFixed(1)}%`);
console.log(`\nCompressed data (first 100 chars):\n${compressed.substring(0, 100)}...\n`);

// Decompress
const decompressed = decompress(compressed);
console.log(`Decompressed size: ${decompressed.length} bytes`);

// Verify
if (decompressed === testContent) {
    console.log('\n✓ SUCCESS: Decompressed content matches original!');
    
    // Generate example URL
    const exampleUrl = `http://localhost:8001/?content=decode:${compressed}`;
    console.log('\nExample URL:');
    console.log(exampleUrl);
    console.log(`\nURL length: ${exampleUrl.length} characters`);
    
    process.exit(0);
} else {
    console.log('\n✗ FAILED: Decompressed content does not match!');
    console.log('\nExpected:', testContent);
    console.log('\nGot:', decompressed);
    process.exit(1);
}
