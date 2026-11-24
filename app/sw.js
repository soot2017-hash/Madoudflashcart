const VER='fc-v4';
const SHELL=['./','./index.html','./manifest.webmanifest','./fonts/fonts.css','./fonts/vazirmatn-400.ttf','./fonts/vazirmatn-600.ttf','./fonts/vazirmatn-800.ttf','./icon-192.png','./icon-512.png'];
self.addEventListener('install',e=>{e.waitUntil(caches.open(VER).then(c=>c.addAll(SHELL)).then(()=>self.skipWaiting()))});
self.addEventListener('activate',e=>{e.waitUntil(caches.keys().then(ks=>Promise.all(ks.filter(k=>k!==VER).map(k=>caches.delete(k)))).then(()=>self.clients.claim()))});
const APIHOSTS=['api.dictionaryapi.dev','api.mymemory.translated.net','api.datamuse.com'];
self.addEventListener('fetch',e=>{
 if(e.request.method!=='GET')return;
 const u=new URL(e.request.url);
 if(u.origin===location.origin){
  e.respondWith(caches.match(e.request).then(c=>c||fetch(e.request).then(r=>{const cp=r.clone();caches.open(VER).then(x=>x.put(e.request,cp));return r}).catch(()=>caches.match('./index.html'))));
  return;
 }
 if(APIHOSTS.includes(u.host)){
  e.respondWith(fetch(e.request).then(r=>{if(r.ok){const cp=r.clone();caches.open(VER).then(x=>x.put(e.request,cp))}return r}).catch(()=>caches.match(e.request)));
 }
});
