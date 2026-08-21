'use strict';

const AudioRev = (() => {
  async function api(path, options = {}) {
    const res = await fetch(path, {
      credentials: 'same-origin',
      headers: { 'Content-Type': 'application/json' },
      ...options,
    });
    if (res.status === 401) { location.href = '/login.html'; throw new Error('401'); }
    if (!res.ok) throw new Error(`${res.status} en ${path}`);
    return res.status === 204 ? null : res.json();
  }

  function fmtDuration(seconds) {
    const s = Math.max(0, Math.round(seconds || 0));
    const h = Math.floor(s / 3600);
    const m = Math.floor((s % 3600) / 60);
    if (h > 0) return `${h} h ${String(m).padStart(2, '0')} min`;
    return `${m} min ${String(s % 60).padStart(2, '0')} s`;
  }

  function stateLabel(state) {
    return {
      pendiente: 'Pendiente',
      en_curso: 'En curso',
      escuchado: 'Escuchado',
      con_notas: 'Con revisiones',
    }[state] || state;
  }

  async function renderList() {
    const data = await api('/api/units');
    document.getElementById('progreso').textContent =
      `${fmtDuration(data.listened_duration_s)} de ${fmtDuration(data.total_duration_s)}`;

    const enCurso = data.chapters
      .flatMap((c) => c.units)
      .find((u) => u.state === 'en_curso' || u.state === 'pendiente');
    const seguir = document.getElementById('seguir');
    if (enCurso) {
      seguir.hidden = false;
      seguir.onclick = () => { location.href = `/player.html?u=${enCurso.unit_id}`; };
    }

    const lista = document.getElementById('lista');
    lista.innerHTML = '';
    for (const chapter of data.chapters) {
      const details = document.createElement('details');
      details.open = chapter.units.some((u) => u.state !== 'escuchado');
      const summary = document.createElement('summary');
      summary.textContent = `${chapter.chapter}. ${chapter.chapter_title}`;
      details.appendChild(summary);

      for (const unit of chapter.units) {
        const a = document.createElement('a');
        a.className = `apartado estado-${unit.state} nivel-${unit.level}`;
        a.href = `/player.html?u=${unit.unit_id}`;
        // Se construyen los nodos con textContent, no con innerHTML: el
        // título y demás textos vienen de la API y no deben interpretarse
        // nunca como HTML (evita una inyección si un título trajera '<').
        const titulo = document.createElement('span');
        titulo.className = 'titulo';
        titulo.textContent = unit.title;
        const meta = document.createElement('span');
        meta.className = 'meta';
        meta.textContent =
          `${fmtDuration(unit.duration_s)}` +
          (unit.n_notes ? ` · ${unit.n_notes} revisiones` : '') +
          ` · ${stateLabel(unit.state)}`;
        a.appendChild(titulo);
        a.appendChild(meta);
        details.appendChild(a);
      }
      lista.appendChild(details);
    }
  }

  // Cola de notas para cuando no hay red: se guardan en IndexedDB y se
  // reintentan al recuperar conexión (evento 'online') o al llamar a
  // flushQueue() a mano.
  const QUEUE_DB = 'audiorev';
  const QUEUE_STORE = 'pendientes';

  function openQueue() {
    return new Promise((resolve, reject) => {
      const req = indexedDB.open(QUEUE_DB, 1);
      req.onupgradeneeded = () =>
        req.result.createObjectStore(QUEUE_STORE, { autoIncrement: true });
      req.onsuccess = () => resolve(req.result);
      req.onerror = () => reject(req.error);
    });
  }

  async function enqueue(note) {
    const db = await openQueue();
    db.transaction(QUEUE_STORE, 'readwrite').objectStore(QUEUE_STORE).add(note);
  }

  async function flushQueue() {
    const db = await openQueue();
    const store = db.transaction(QUEUE_STORE, 'readwrite').objectStore(QUEUE_STORE);
    const all = store.getAll();
    all.onsuccess = async () => {
      for (const note of all.result) {
        try {
          await api('/api/notes', { method: 'POST', body: JSON.stringify(note) });
        } catch (err) { return; }
      }
      db.transaction(QUEUE_STORE, 'readwrite').objectStore(QUEUE_STORE).clear();
    };
  }

  // Pide al service worker que precachee el JSON y el audio de un apartado
  // para poder escucharlo y anotarlo sin cobertura.
  function cacheUnit(unitId) {
    if (navigator.serviceWorker.controller) {
      navigator.serviceWorker.controller.postMessage({ type: 'cache-unit', unitId });
    }
  }

  if ('serviceWorker' in navigator) navigator.serviceWorker.register('/sw.js');
  window.addEventListener('online', flushQueue);

  return { api, fmtDuration, stateLabel, renderList, enqueue, flushQueue, cacheUnit };
})();

window.AudioRev = AudioRev;
