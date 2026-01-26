/**
 * TStorie Service Worker
 * Aggressive caching strategy for optimal performance
 */

const CACHE_VERSION = 'tstorie-v3-debug';
const CORE_CACHE = 'tstorie-core-v3';
const FULL_CACHE = 'tstorie-full-v3';
const ASSET_CACHE = 'tstorie-assets-v3';

// Files to cache immediately (core)
const CORE_FILES = [
  '/',
  '/index-progressive.html',
  '/progressive-loader.js',
  '/asset-loader.js',
  '/tstorie-core.js',
  '/tstorie-core.wasm',
  '/tstorie-core.data'
];

// Files to cache on-demand (full build)
const FULL_FILES = [
  '/tstorie-sdl3.js',
  '/tstorie-sdl3.wasm',
  '/tstorie-sdl3.data'
];

// Assets to cache on-demand
const ASSET_PATTERNS = [
  /\/demos\/.+\.md$/,
  /\/presets\/.+\.md$/,
  /\/assets\/.+\.(ttf|woff2|png|svg)$/
];

self.addEventListener('install', (event) => {
  console.log('[SW] Installing...');
  
  event.waitUntil(
    caches.open(CORE_CACHE).then((cache) => {
      console.log('[SW] Caching core files');
      return cache.addAll(CORE_FILES);
    })
  );
  
  // Skip waiting to activate immediately
  self.skipWaiting();
});

self.addEventListener('activate', (event) => {
  console.log('[SW] Activating...');
  
  event.waitUntil(
    caches.keys().then((cacheNames) => {
      return Promise.all(
        cacheNames
          .filter((name) => name.startsWith('tstorie-') && name !== CACHE_VERSION)
          .map((name) => {
            console.log('[SW] Deleting old cache:', name);
            return caches.delete(name);
          })
      );
    })
  );
  
  // Take control of all pages immediately
  return self.clients.claim();
});

self.addEventListener('fetch', (event) => {
  const url = new URL(event.request.url);
  
  // Only handle same-origin requests
  if (url.origin !== location.origin) {
    return;
  }
  
  // Strategy: Cache first for core, network first for dynamic content
  if (isCoreFile(url.pathname)) {
    event.respondWith(cacheFirst(event.request, CORE_CACHE));
  } else if (isFullFile(url.pathname)) {
    event.respondWith(cacheFirst(event.request, FULL_CACHE));
  } else if (isAsset(url.pathname)) {
    event.respondWith(staleWhileRevalidate(event.request, ASSET_CACHE));
  } else {
    event.respondWith(networkFirst(event.request));
  }
});

// Check if file is part of core build
function isCoreFile(pathname) {
  return CORE_FILES.some(file => pathname.endsWith(file) || pathname === file);
}

// Check if file is part of full build
function isFullFile(pathname) {
  return FULL_FILES.some(file => pathname.endsWith(file));
}

// Check if file is an asset
function isAsset(pathname) {
  return ASSET_PATTERNS.some(pattern => pattern.test(pathname));
}

// Cache-first strategy (for core files)
async function cacheFirst(request, cacheName) {
  const cachedResponse = await caches.match(request);
  if (cachedResponse) {
    console.log('[SW] Cache hit:', request.url);
    return cachedResponse;
  }
  
  console.log('[SW] Cache miss, fetching:', request.url);
  const response = await fetch(request);
  
  if (response.ok) {
    const cache = await caches.open(cacheName);
    cache.put(request, response.clone());
  }
  
  return response;
}

// Network-first strategy (for dynamic content)
async function networkFirst(request) {
  try {
    const response = await fetch(request);
    return response;
  } catch (error) {
    console.log('[SW] Network failed, trying cache:', request.url);
    const cachedResponse = await caches.match(request);
    if (cachedResponse) {
      return cachedResponse;
    }
    throw error;
  }
}

// Stale-while-revalidate (for assets)
async function staleWhileRevalidate(request, cacheName) {
  const cachedResponse = await caches.match(request);
  
  const fetchPromise = fetch(request).then((response) => {
    if (response.ok) {
      const cache = caches.open(cacheName);
      cache.then(c => c.put(request, response.clone()));
    }
    return response;
  });
  
  return cachedResponse || fetchPromise;
}
