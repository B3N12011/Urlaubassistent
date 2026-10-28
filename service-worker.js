const CACHE_NAME = 'urlaubassistent-shell-v57';
const RUNTIME_CACHE_NAME = 'urlaubassistent-runtime-assets-v1';
const APP_SHELL = [
  './',
  './index.html',
  './manifest.json',
  './icon-192.png',
  './icon-512.png'
];
const REMOTE_SCRIPT_URLS = [
  'https://cdn.tailwindcss.com/',
  'https://unpkg.com/lucide@latest',
  'https://cdn.jsdelivr.net/npm/@supabase/supabase-js@2'
];

function isEssentialRemoteScript(url) {
  return (url.hostname === 'cdn.tailwindcss.com' && url.pathname === '/') ||
    (url.hostname === 'unpkg.com' && url.pathname.startsWith('/lucide@latest')) ||
    (url.hostname === 'cdn.jsdelivr.net' && url.pathname.startsWith('/npm/@supabase/supabase-js@2'));
}

async function cacheRemoteScript(urlString) {
  try {
    const request = new Request(urlString, { mode: 'no-cors' });
    const response = await fetch(request);
    if (!response || (!response.ok && response.type !== 'opaque')) return;
    const cache = await caches.open(RUNTIME_CACHE_NAME);
    await cache.put(request, response.clone());
  } catch {
    // Offline or CDN failure during install is non-fatal; runtime fetch will retry.
  }
}

self.addEventListener('install', event => {
  event.waitUntil(
    caches.open(CACHE_NAME)
      .then(cache => cache.addAll(APP_SHELL))
      .then(async () => {
        await Promise.all(REMOTE_SCRIPT_URLS.map(cacheRemoteScript));
        await self.skipWaiting();
      })
      .catch(() => self.skipWaiting())
  );
});

self.addEventListener('activate', event => {
  event.waitUntil(
    caches.keys().then(keys => Promise.all(
      keys.filter(key => key.startsWith('urlaubassistent-shell-') && key !== CACHE_NAME)
        .map(key => caches.delete(key))
    )).then(() => self.clients.claim())
  );
});

self.addEventListener('notificationclick', event => {
  event.notification.close();
  const requestedUrl = event.notification?.data?.url || './';
  const destination = new URL(requestedUrl, self.registration.scope).href;
  event.waitUntil(
    self.clients.matchAll({ type: 'window', includeUncontrolled: true }).then(async clients => {
      for (const client of clients) {
        try {
          const clientUrl = new URL(client.url);
          if (clientUrl.origin !== self.location.origin) continue;
          if (typeof client.navigate === 'function' && client.url !== destination) {
            await client.navigate(destination);
          }
          return client.focus();
        } catch {
          // If a client cannot be focused, try the next one or open a new window.
        }
      }
      return self.clients.openWindow(destination);
    })
  );
});

self.addEventListener('fetch', event => {
  if (event.request.method !== 'GET') return;
  const url = new URL(event.request.url);

  // Cache the external libraries the app needs in order to boot offline.
  if (isEssentialRemoteScript(url)) {
    event.respondWith((async () => {
      const cache = await caches.open(RUNTIME_CACHE_NAME);
      const cached = await cache.match(event.request);
      try {
        const response = await fetch(event.request);
        if (response && (response.ok || response.type === 'opaque')) {
          cache.put(event.request, response.clone()).catch(() => {});
        }
        return response;
      } catch {
        return cached || Response.error();
      }
    })());
    return;
  }

  if (url.origin !== self.location.origin) return;

  // Always prefer fresh online HTML, with the shell copy as offline fallback.
  if (event.request.mode === 'navigate') {
    event.respondWith(
      fetch(event.request).then(response => {
        if (response && response.ok) {
          const copy = response.clone();
          caches.open(CACHE_NAME).then(cache => cache.put(event.request, copy)).catch(() => {});
        }
        return response;
      }).catch(async () => {
        return await caches.match(event.request)
          || await caches.match('./index.html')
          || await caches.match('./');
      })
    );
    return;
  }

  event.respondWith(
    caches.match(event.request).then(cached => cached || fetch(event.request).then(response => {
      if (response && response.ok) {
        const copy = response.clone();
        caches.open(CACHE_NAME).then(cache => cache.put(event.request, copy)).catch(() => {});
      }
      return response;
    }).catch(() => caches.match('./')))
  );
});
