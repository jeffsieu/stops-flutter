'use strict';
const MANIFEST = 'flutter-app-manifest';
const TEMP = 'flutter-temp-cache';
const CACHE_NAME = 'flutter-app-cache';

const RESOURCES = {"canvaskit/skwasm.wasm": "1c93738510f202d9ff44d36a4760126b",
"canvaskit/chromium/canvaskit.wasm": "c054c2c892172308ca5a0bd1d7a7754b",
"canvaskit/chromium/canvaskit.js": "8191e843020c832c9cf8852a4b909d4c",
"canvaskit/chromium/canvaskit.js.symbols": "f7c5e5502d577306fb6d530b1864ff86",
"canvaskit/canvaskit.wasm": "a37f2b0af4995714de856e21e882325c",
"canvaskit/canvaskit.js": "728b2d477d9b8c14593d4f9b82b484f3",
"canvaskit/skwasm.js": "ea559890a088fe28b4ddf70e17e60052",
"canvaskit/skwasm.js.symbols": "9fe690d47b904d72c7d020bd303adf16",
"canvaskit/canvaskit.js.symbols": "27361387bc24144b46a745f1afe92b50",
"sql-wasm.wasm": "9c67691cdfea004dda62090e49940eac",
"sqlite3.wasm": "fa7637a49a0e434f2a98f9981856d118",
"manifest.json": "7ae9d3e95cb4e31de584658e6b367d81",
"main.dart.js": "d4fa2a310deda5fc13dedd1594b890e8",
"flutter.js": "83d881c1dbb6d6bcd6b42e274605b69c",
"sql-wasm.js": "abe5911756c78d17a8b67a113f4a62b2",
"index.html": "cb9a8176c281fc8efc6b25fef70fb83c",
"/": "cb9a8176c281fc8efc6b25fef70fb83c",
"assets/packages/cupertino_icons/assets/CupertinoIcons.ttf": "825e75415ebd366b740bb49659d7a5c6",
"assets/AssetManifest.bin.json": "2ed92c1811599656f42e3cc6ae46d5c0",
"assets/AssetManifest.bin": "abe2aa87391df065cdb9c0adc2d23403",
"assets/NOTICES": "9685e7846fb379d6d88ffb76412cb74a",
"assets/shaders/ink_sparkle.frag": "ecc85a2e95f5e9f53123dcaf8cb9b6ce",
"assets/assets/maps/map_style_dark.json": "ead04b4ee37c59a7018d29f129b2886f",
"assets/assets/secrets.json": "6b1ba9dea14c9b57df9f75d674bf6689",
"assets/assets/fonts/Cousine-Bold.ttf": "06dae6a1a3247bd76125cfe3b3480557",
"assets/assets/fonts/NunitoSans-Bold.ttf": "08e53a516d2ba719d98da46c49b3c369",
"assets/assets/images/bus-stop.svg": "11e83cdb07764a4c6fa2da7481edeb04",
"assets/assets/images/pin.svg": "27061303cab82408e955f32f39d5ee48",
"assets/assets/images/bus-double-decker.svg": "89db7cb67b5fc154fa2101b3ecb795ef",
"assets/assets/images/icon/icon.png": "ff53c984c08596ab98e2bb71c5c8ad01",
"assets/assets/images/icon/icon_squircle.png": "3584214db157df1cc61f295639e0fbb4",
"assets/assets/images/icon/icon_fg.png": "288f2788a77c6fcd5fb163680f2d4a63",
"assets/assets/images/icon/icon_bg.png": "3bc9b4a2c2626d46dd06f3b61377db0a",
"assets/assets/images/pin-outline.svg": "fd8ff41a1f9e360696c2faa77749ec1f",
"assets/assets/images/bus-articulated-front.svg": "450c600e34e9168ef97db3472b3b5d38",
"assets/AssetManifest.json": "dd35c5f15104ac629b24dc1537f3d0f1",
"assets/fonts/MaterialIcons-Regular.otf": "8f5d22cc375d57876e102d145509a499",
"assets/FontManifest.json": "dc3d03800ccca4601324923c0b1d6d57",
"favicon.png": "f680b891df3775d7d6f3403bb2138dba",
"icons/Icon-512.png": "8db3632f4be0e6a4ceb852d4e392c3c6",
"icons/Icon-maskable-192.png": "c1f7b71509dcec35473b03b5850c5b65",
"icons/Icon-192.png": "8119be0c201769f51e1d576b2ded1a27",
"icons/Icon-maskable-512.png": "19cfb2ba9b28e727fa27931933d14153",
"drift_worker.js": "553fc7ecf77c015fbd55dbe8c3d08b67",
"flutter_bootstrap.js": "b6074abe113634ce2e79a0c037e92f0b",
"version.json": "d684745d2a182521fd1eec4f8217b16c"};
// The application shell files that are downloaded before a service worker can
// start.
const CORE = ["main.dart.js",
"index.html",
"flutter_bootstrap.js",
"assets/AssetManifest.bin.json",
"assets/FontManifest.json"];

// During install, the TEMP cache is populated with the application shell files.
self.addEventListener("install", (event) => {
  self.skipWaiting();
  return event.waitUntil(
    caches.open(TEMP).then((cache) => {
      return cache.addAll(
        CORE.map((value) => new Request(value, {'cache': 'reload'})));
    })
  );
});
// During activate, the cache is populated with the temp files downloaded in
// install. If this service worker is upgrading from one with a saved
// MANIFEST, then use this to retain unchanged resource files.
self.addEventListener("activate", function(event) {
  return event.waitUntil(async function() {
    try {
      var contentCache = await caches.open(CACHE_NAME);
      var tempCache = await caches.open(TEMP);
      var manifestCache = await caches.open(MANIFEST);
      var manifest = await manifestCache.match('manifest');
      // When there is no prior manifest, clear the entire cache.
      if (!manifest) {
        await caches.delete(CACHE_NAME);
        contentCache = await caches.open(CACHE_NAME);
        for (var request of await tempCache.keys()) {
          var response = await tempCache.match(request);
          await contentCache.put(request, response);
        }
        await caches.delete(TEMP);
        // Save the manifest to make future upgrades efficient.
        await manifestCache.put('manifest', new Response(JSON.stringify(RESOURCES)));
        // Claim client to enable caching on first launch
        self.clients.claim();
        return;
      }
      var oldManifest = await manifest.json();
      var origin = self.location.origin;
      for (var request of await contentCache.keys()) {
        var key = request.url.substring(origin.length + 1);
        if (key == "") {
          key = "/";
        }
        // If a resource from the old manifest is not in the new cache, or if
        // the MD5 sum has changed, delete it. Otherwise the resource is left
        // in the cache and can be reused by the new service worker.
        if (!RESOURCES[key] || RESOURCES[key] != oldManifest[key]) {
          await contentCache.delete(request);
        }
      }
      // Populate the cache with the app shell TEMP files, potentially overwriting
      // cache files preserved above.
      for (var request of await tempCache.keys()) {
        var response = await tempCache.match(request);
        await contentCache.put(request, response);
      }
      await caches.delete(TEMP);
      // Save the manifest to make future upgrades efficient.
      await manifestCache.put('manifest', new Response(JSON.stringify(RESOURCES)));
      // Claim client to enable caching on first launch
      self.clients.claim();
      return;
    } catch (err) {
      // On an unhandled exception the state of the cache cannot be guaranteed.
      console.error('Failed to upgrade service worker: ' + err);
      await caches.delete(CACHE_NAME);
      await caches.delete(TEMP);
      await caches.delete(MANIFEST);
    }
  }());
});
// The fetch handler redirects requests for RESOURCE files to the service
// worker cache.
self.addEventListener("fetch", (event) => {
  if (event.request.method !== 'GET') {
    return;
  }
  var origin = self.location.origin;
  var key = event.request.url.substring(origin.length + 1);
  // Redirect URLs to the index.html
  if (key.indexOf('?v=') != -1) {
    key = key.split('?v=')[0];
  }
  if (event.request.url == origin || event.request.url.startsWith(origin + '/#') || key == '') {
    key = '/';
  }
  // If the URL is not the RESOURCE list then return to signal that the
  // browser should take over.
  if (!RESOURCES[key]) {
    return;
  }
  // If the URL is the index.html, perform an online-first request.
  if (key == '/') {
    return onlineFirst(event);
  }
  event.respondWith(caches.open(CACHE_NAME)
    .then((cache) =>  {
      return cache.match(event.request).then((response) => {
        // Either respond with the cached resource, or perform a fetch and
        // lazily populate the cache only if the resource was successfully fetched.
        return response || fetch(event.request).then((response) => {
          if (response && Boolean(response.ok)) {
            cache.put(event.request, response.clone());
          }
          return response;
        });
      })
    })
  );
});
self.addEventListener('message', (event) => {
  // SkipWaiting can be used to immediately activate a waiting service worker.
  // This will also require a page refresh triggered by the main worker.
  if (event.data === 'skipWaiting') {
    self.skipWaiting();
    return;
  }
  if (event.data === 'downloadOffline') {
    downloadOffline();
    return;
  }
});
// Download offline will check the RESOURCES for all files not in the cache
// and populate them.
async function downloadOffline() {
  var resources = [];
  var contentCache = await caches.open(CACHE_NAME);
  var currentContent = {};
  for (var request of await contentCache.keys()) {
    var key = request.url.substring(origin.length + 1);
    if (key == "") {
      key = "/";
    }
    currentContent[key] = true;
  }
  for (var resourceKey of Object.keys(RESOURCES)) {
    if (!currentContent[resourceKey]) {
      resources.push(resourceKey);
    }
  }
  return contentCache.addAll(resources);
}
// Attempt to download the resource online before falling back to
// the offline cache.
function onlineFirst(event) {
  return event.respondWith(
    fetch(event.request).then((response) => {
      return caches.open(CACHE_NAME).then((cache) => {
        cache.put(event.request, response.clone());
        return response;
      });
    }).catch((error) => {
      return caches.open(CACHE_NAME).then((cache) => {
        return cache.match(event.request).then((response) => {
          if (response != null) {
            return response;
          }
          throw error;
        });
      });
    })
  );
}
