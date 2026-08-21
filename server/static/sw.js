'use strict';

// Service worker de AudioRev: precachea la interfaz y permite marcar
// apartados concretos para escucharlos y anotarlos sin cobertura.

const CACHE = 'audiorev-v1';
const SHELL = ['/', '/player.html', '/app.js', '/player.js', '/style.css'];

self.addEventListener('install', (e) => {
  e.waitUntil(caches.open(CACHE).then((c) => c.addAll(SHELL)));
  self.skipWaiting();
});

self.addEventListener('activate', (e) => {
  e.waitUntil(
    caches.keys().then((keys) =>
      Promise.all(keys.filter((k) => k !== CACHE).map((k) => caches.delete(k)))
    )
  );
  self.clients.claim();
});

self.addEventListener('message', (e) => {
  if (e.data && e.data.type === 'cache-unit') {
    const id = e.data.unitId;
    e.waitUntil(
      caches.open(CACHE).then((c) => c.addAll([`/api/units/${id}`, `/audio/${id}.opus`]))
    );
  }
});

self.addEventListener('fetch', (e) => {
  const url = new URL(e.request.url);
  const cacheable =
    url.pathname.startsWith('/audio/') ||
    url.pathname.startsWith('/api/units/') ||
    SHELL.includes(url.pathname);

  if (!cacheable || e.request.method !== 'GET') return;

  e.respondWith(
    caches.match(e.request).then((hit) =>
      hit || fetch(e.request).then((res) => {
        const copy = res.clone();
        caches.open(CACHE).then((c) => c.put(e.request, copy));
        return res;
      })
    )
  );
});
