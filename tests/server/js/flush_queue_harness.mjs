// Arnés de pruebas de la cola de notas de app.js.
//
// No hay navegador en esta batería, así que se carga app.js en un contexto
// de `vm` con un IndexedDB de mentira (en memoria) y un `fetch` de mentira
// que se puede programar frase a frase. Así se ejercita el comportamiento
// real de flushQueue(), no una comprobación de subcadenas.
//
// Uso: node flush_queue_harness.mjs <ruta a app.js> <escenario>
// Imprime en la salida estándar un JSON con lo enviado y lo que queda en la
// cola.

import fs from 'node:fs';
import vm from 'node:vm';

const [, , appJsPath, escenario] = process.argv;

function despues(valor, fallo) {
  // Petición de IndexedDB de mentira: resuelve en un microtask, igual que
  // el original, para que dé tiempo a asignar onsuccess/onerror.
  const req = { result: undefined, error: null, onsuccess: null, onerror: null };
  queueMicrotask(() => {
    if (fallo) { req.error = fallo; if (req.onerror) req.onerror(); return; }
    req.result = valor;
    if (req.onsuccess) req.onsuccess();
  });
  return req;
}

function crearIndexedDB() {
  const datos = new Map();
  let siguiente = 1;

  const store = {
    add(valor) { const k = siguiente++; datos.set(k, valor); return despues(k); },
    getAll() { return despues([...datos.values()]); },
    getAllKeys() { return despues([...datos.keys()]); },
    delete(k) { datos.delete(k); return despues(undefined); },
    clear() { datos.clear(); return despues(undefined); },
  };
  const db = { transaction: () => ({ objectStore: () => store }) };

  return {
    indexedDB: { open() { return despues(db); } },
    contenido: () => [...datos.entries()].map(([k, v]) => ({ key: k, note: v })),
  };
}

const { indexedDB, contenido } = crearIndexedDB();
const enviadas = [];

// Programación del fetch según el escenario.
function respuesta(status) {
  return {
    ok: status >= 200 && status < 300,
    status,
    json: async () => ({ id: 1 }),
  };
}

async function fetchFalso(path, options) {
  const cuerpo = JSON.parse(options.body);
  enviadas.push(cuerpo.comment);
  if (escenario === 'red-cae-en-la-segunda' && cuerpo.comment === 'dos') {
    // fetch() lanza sin respuesta: exactamente lo que hace el navegador
    // cuando no hay red.
    throw new TypeError('Failed to fetch');
  }
  if (escenario === 'servidor-rechaza-la-segunda' && cuerpo.comment === 'dos') {
    return respuesta(422);
  }
  return respuesta(201);
}

const contexto = {
  indexedDB,
  fetch: fetchFalso,
  navigator: {},
  location: { href: '/' },
  window: { addEventListener() {} },
  document: { getElementById: () => null },
  console: { error: () => {}, log: () => {} },
  queueMicrotask,
  setTimeout,
  crypto,
  JSON,
  Promise,
  TypeError,
  Error,
  Map,
  Math,
  URLSearchParams,
};
contexto.globalThis = contexto;
vm.createContext(contexto);
vm.runInContext(fs.readFileSync(appJsPath, 'utf8'), contexto);

// app.js declara AudioRev con const (no cuelga del global), pero lo expone
// en window, igual que en el navegador.
const { AudioRev } = contexto.window;

async function main() {
  for (const comment of ['uno', 'dos', 'tres']) {
    await AudioRev.enqueue({ session_id: 's', unit_id: 'u', comment });
  }
  await AudioRev.flushQueue();
  const trasElPrimerVaciado = { enviadas: [...enviadas], cola: contenido() };

  // Segundo vaciado, ya con red y con el servidor aceptando todo: sirve
  // para comprobar que no se reenvía nada de lo ya aceptado.
  enviadas.length = 0;
  await AudioRev.flushQueue();

  console.log(JSON.stringify({
    primero: trasElPrimerVaciado,
    segundo: { enviadas: [...enviadas], cola: contenido() },
  }));
}

main();
