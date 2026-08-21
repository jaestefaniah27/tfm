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
        a.innerHTML =
          `<span class="titulo">${unit.title}</span>` +
          `<span class="meta">${fmtDuration(unit.duration_s)}` +
          (unit.n_notes ? ` · ${unit.n_notes} revisiones` : '') +
          ` · ${stateLabel(unit.state)}</span>`;
        details.appendChild(a);
      }
      lista.appendChild(details);
    }
  }

  return { api, fmtDuration, stateLabel, renderList };
})();

window.AudioRev = AudioRev;
