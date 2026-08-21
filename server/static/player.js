'use strict';

const Player = (() => {
  const audio = document.getElementById('audio');
  let unit = null;
  let nodes = [];
  let active = -1;

  function currentSentence() {
    return active >= 0 ? unit.sentences[active] : null;
  }

  function paint(idx) {
    if (idx === active) return;
    if (active >= 0 && nodes[active]) nodes[active].classList.remove('activa');
    active = idx;
    if (idx >= 0 && nodes[idx]) {
      nodes[idx].classList.add('activa');
      nodes[idx].scrollIntoView({ block: 'center', behavior: 'smooth' });
    }
  }

  function findSentence(t) {
    // Búsqueda lineal desde la posición actual: los apartados tienen pocas frases.
    for (let i = Math.max(0, active); i < unit.sentences.length; i += 1) {
      if (t < unit.sentences[i].t_end) return i;
    }
    for (let i = 0; i < unit.sentences.length; i += 1) {
      if (t < unit.sentences[i].t_end) return i;
    }
    return unit.sentences.length - 1;
  }

  function seekToSentence(idx) {
    const s = unit.sentences[idx];
    if (!s) return;
    audio.currentTime = s.t_start + 0.01;
    paint(idx);
  }

  function renderBody() {
    const main = document.getElementById('texto');
    main.innerHTML = '';
    nodes = [];

    const byPosition = new Map();
    for (const block of unit.blocks) {
      const key = block.after_sentence;
      if (!byPosition.has(key)) byPosition.set(key, []);
      byPosition.get(key).push(block);
    }

    unit.sentences.forEach((s, i) => {
      const span = document.createElement('span');
      span.className = 'frase';
      span.textContent = s.text + ' ';
      span.onclick = () => seekToSentence(i);
      main.appendChild(span);
      nodes.push(span);

      for (const block of byPosition.get(i) || []) {
        const details = document.createElement('details');
        details.className = `bloque bloque-${block.type}`;
        const summary = document.createElement('summary');
        summary.textContent = block.caption || `Bloque ${block.type}`;
        details.appendChild(summary);
        const body = document.createElement('div');
        if (block.html) {
          // El HTML de los bloques (figuras, tablas) lo genera el propio
          // pipeline de audiorev; es contenido de confianza, no texto libre.
          body.innerHTML = block.html;
        } else {
          const p = document.createElement('p');
          p.textContent = `Contenido visual: ${block.caption}`;
          body.appendChild(p);
        }
        details.appendChild(body);
        main.appendChild(details);
      }
    });
  }

  function saveProgress(state) {
    const body = JSON.stringify({ state, position_s: audio.currentTime || 0 });
    // sendBeacon SIEMPRE envía POST: el servidor acepta esa ruta además de
    // PUT precisamente por esto (ver put_progress en main.py).
    navigator.sendBeacon
      ? navigator.sendBeacon(`/api/progress/${unit.unit_id}`, new Blob([body], { type: 'application/json' }))
      : AudioRev.api(`/api/progress/${unit.unit_id}`, { method: 'PUT', body });
  }

  async function load(unitId) {
    unit = await AudioRev.api(`/api/units/${unitId}`);
    document.getElementById('titulo').textContent = unit.title;
    audio.src = `/audio/${unit.unit_id}.opus`;
    renderBody();

    audio.ontimeupdate = () => paint(findSentence(audio.currentTime));
    audio.onended = () => saveProgress('escuchado');

    document.getElementById('play').onclick = () => {
      if (audio.paused) { audio.play(); saveProgress('en_curso'); }
      else audio.pause();
      document.getElementById('play').textContent = audio.paused ? '▶' : '❚❚';
    };
    document.getElementById('atras').onclick = () => { audio.currentTime -= 10; };
    document.getElementById('adelante').onclick = () => { audio.currentTime += 10; };
    document.getElementById('anterior').onclick = () => seekToSentence(Math.max(0, active - 1));
    document.getElementById('siguiente').onclick = () =>
      seekToSentence(Math.min(unit.sentences.length - 1, active + 1));

    const vel = document.getElementById('velocidad');
    vel.oninput = () => {
      audio.playbackRate = Number(vel.value);
      document.getElementById('velocidad-valor').textContent =
        `${vel.value.replace('.', ',')}×`;
    };

    if ('mediaSession' in navigator) {
      navigator.mediaSession.metadata = new MediaMetadata({
        title: unit.title,
        artist: `Capítulo ${unit.chapter}. ${unit.chapter_title}`,
        album: 'TFM, revisión hablada',
      });
      navigator.mediaSession.setActionHandler('play', () => audio.play());
      navigator.mediaSession.setActionHandler('pause', () => audio.pause());
      navigator.mediaSession.setActionHandler('seekbackward', () => { audio.currentTime -= 10; });
      navigator.mediaSession.setActionHandler('seekforward', () => { audio.currentTime += 10; });
      navigator.mediaSession.setActionHandler('previoustrack', () =>
        seekToSentence(Math.max(0, active - 1)));
      navigator.mediaSession.setActionHandler('nexttrack', () =>
        seekToSentence(Math.min(unit.sentences.length - 1, active + 1)));
    }

    window.addEventListener('pagehide', () => saveProgress('en_curso'));
    document.addEventListener('visibilitychange', () => {
      if (document.visibilityState === 'hidden') saveProgress('en_curso');
    });
  }

  return { load, currentSentence, seekToSentence, get audio() { return audio; },
           get unit() { return unit; } };
})();

window.Player = Player;

const Notes = (() => {
  const dialog = document.getElementById('hoja-notas');
  const form = document.getElementById('form-nota');
  let resumeAfter = false;

  // localStorage y no sessionStorage: un navegador móvil descarta la
  // pestaña en segundo plano a mitad de escucha y con ella el
  // sessionStorage, partiendo la sesión de escucha en varias. La sesión se
  // termina explícitamente con el botón "Cerrar sesión y publicar".
  const SESSION_KEY = 'audiorev_session_id';

  async function sessionId() {
    let id = localStorage.getItem(SESSION_KEY);
    if (!id) {
      try {
        id = (await AudioRev.api('/api/sessions', { method: 'POST' })).session_id;
      } catch (err) {
        // Sin red: no hay forma de pedirle un identificador al servidor.
        // Se genera uno aquí mismo para no bloquear la anotación; el
        // servidor no distingue el origen del session_id (es sólo una
        // cadena que agrupa notas), así que una vez enviada la nota tras
        // recuperar la conexión funciona igual que uno emitido por él.
        id = crypto.randomUUID();
      }
      localStorage.setItem(SESSION_KEY, id);
    }
    return id;
  }

  // Cierre de sesión: publica las revisiones de la sesión actual en
  // revisiones/ y las empuja a GitHub. Es la única forma desde el móvil de
  // llamar a POST /api/sessions/{id}/publicar.
  async function publish() {
    const estado = document.getElementById('estado-sesion');
    const boton = document.getElementById('cerrar-sesion');
    const id = localStorage.getItem(SESSION_KEY);
    if (!id) {
      estado.textContent = 'No hay ninguna sesión abierta todavía.';
      return;
    }
    boton.disabled = true;
    estado.textContent = 'Publicando…';
    try {
      // Se vacía primero la cola: si quedan notas sin enviar, publicar
      // ahora dejaría fuera del fichero las que aún están en IndexedDB.
      await AudioRev.flushQueue();
      const res = await AudioRev.api(`/api/sessions/${id}/publicar`, { method: 'POST' });
      estado.textContent = `Sesión publicada en ${res.path} (${res.notes} revisiones).`;
      localStorage.removeItem(SESSION_KEY);
    } catch (err) {
      estado.textContent = err && err.status === 503
        ? 'No se pudo publicar: el servidor no pudo escribir o empujar al repositorio. La sesión sigue abierta.'
        : 'No se pudo publicar la sesión. Comprueba la conexión e inténtalo de nuevo.';
    } finally {
      boton.disabled = false;
    }
  }

  function open() {
    const sentence = Player.currentSentence();
    if (!sentence) return;
    resumeAfter = !Player.audio.paused;
    Player.audio.pause();
    document.getElementById('frase-anclada').textContent = sentence.text;
    form.reset();
    dialog.showModal();
    document.getElementById('comentario').focus();
  }

  function close() {
    dialog.close();
    if (resumeAfter) Player.audio.play();
  }

  async function save() {
    const sentence = Player.currentSentence();
    const tags = [...form.querySelectorAll('input[name=tag]:checked')].map((i) => i.value);
    const comment = document.getElementById('comentario').value.trim();
    if (!tags.length && !comment) { close(); return; }

    // `payload` se declara fuera del try (necesita seguir siendo visible en
    // el catch) pero todo lo que necesita red -incluido obtener el
    // session_id la primera vez que se anota en esta pestaña- se construye
    // y envía dentro del mismo try: si falla en cualquier punto (sin
    // cobertura desde el primer instante, o se pierde a media petición),
    // cae al mismo catch y la nota se encola en vez de perderse.
    let payload;
    try {
      payload = {
        session_id: await sessionId(),
        unit_id: Player.unit.unit_id,
        sentence_idx: sentence.idx,
        sentence_hash: sentence.hash,
        sentence_text: sentence.text,
        tex_file: Player.unit.tex_file,
        tex_line: sentence.tex_line,
        audio_ts: Player.audio.currentTime,
        tags,
        comment,
      };
      await AudioRev.api('/api/notes', { method: 'POST', body: JSON.stringify(payload) });
    } catch (err) {
      // Sin red: se encola en IndexedDB y se envía sola al recuperar
      // conexión, para no perder la anotación. Si el fallo fue el propio
      // sessionId() (sin sesión aún y sin red), sessionId() ya generó y
      // cacheó un id local antes de lanzar, así que `payload` está completo.
      await AudioRev.enqueue(payload);
    }
    close();
  }

  form.addEventListener('submit', (e) => {
    if (e.submitter && e.submitter.value === 'guardar') { e.preventDefault(); save(); }
    else close();
  });

  document.getElementById('anotar').onclick = open;
  document.getElementById('cerrar-sesion').onclick = publish;

  return { open, close, save, publish };
})();

window.Notes = Notes;
