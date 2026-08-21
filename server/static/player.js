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
        body.innerHTML = block.html || `<p>Contenido visual: ${block.caption}</p>`;
        details.appendChild(body);
        main.appendChild(details);
      }
    });
  }

  function saveProgress(state) {
    const body = JSON.stringify({ state, position_s: audio.currentTime || 0 });
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

  async function sessionId() {
    let id = sessionStorage.getItem('audiorev_session_id');
    if (!id) {
      id = (await AudioRev.api('/api/sessions', { method: 'POST' })).session_id;
      sessionStorage.setItem('audiorev_session_id', id);
    }
    return id;
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

    await AudioRev.api('/api/notes', {
      method: 'POST',
      body: JSON.stringify({
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
      }),
    });
    close();
  }

  form.addEventListener('submit', (e) => {
    if (e.submitter && e.submitter.value === 'guardar') { e.preventDefault(); save(); }
    else close();
  });

  document.getElementById('anotar').onclick = open;

  return { open, close, save };
})();

window.Notes = Notes;
