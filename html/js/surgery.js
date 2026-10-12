(() => {
    const root = document.getElementById('xsm-surgery');
    let open = false;
    let op = null;
    let vitals = {};
    let stage = null;
    let deadline = 0;
    let timerId = null;
    let game = null;

    const PHASES = ['incise', 'repair', 'suture'];
    const ARROWS = ['ArrowUp', 'ArrowDown', 'ArrowLeft', 'ArrowRight'];
    const GLYPH = { ArrowUp: '↑', ArrowDown: '↓', ArrowLeft: '←', ArrowRight: '→' };

    function label(injury) {
        const bits = [];
        if (injury.bulletIn) bits.push(XS.t('sg_bullet', null, 'Remove the bullet'));
        if (injury.internal) bits.push(XS.t('sg_internal', null, 'Stop internal bleeding'));
        if (injury.fracture) bits.push(XS.t('sg_fracture', null, 'Set the fracture'));
        return `${XS.part(injury.part)} · ${bits.join(', ')}`;
    }

    function stepsHtml() {
        return XS.list(op.injuries).map((inj, i) => {
            const r = op.results[inj.id];
            const cls = r === true ? 's-ok' : (r === false ? 's-bad' : (i === op.index ? 's-now' : ''));
            const state = r === true ? XS.t('sg_done', null, 'Done') : (r === false ? XS.t('sg_failed', null, 'Complication') : (i === op.index ? XS.t('sg_now', null, 'In progress') : XS.t('sg_waiting', null, 'Waiting')));
            return `<div class="sg-step ${cls}"><b>${XS.esc(label(inj))}</b><span>${XS.esc(state)}</span></div>`;
        }).join('');
    }

    function vit(label, value, colour) {
        return `<div class="vt-cell" style="color:${colour}"><small>${XS.esc(label)}</small><b style="font-size:38px">${XS.esc(value)}</b></div>`;
    }

    function render() {
        stage = XS.stage(root);
        stage.innerHTML = `
            <div class="sg-box">
                <div class="sg-head"><b>${XS.esc(XS.t('sg_title', null, 'Operating theatre'))}</b><span style="color:var(--m-dim)">${XS.esc(op.patient || '')}</span><span class="sg-timer" id="sg-timer"></span></div>
                <div class="sg-vitals"><canvas id="sg-ecg" height="150"></canvas><div id="sg-v"></div></div>
                <div class="sg-main"><div class="sg-steps xsm-scroll" id="sg-steps"></div><div class="sg-game" id="sg-game"></div></div>
                <div class="sg-foot"><button class="xsm-key k-warn" id="sg-stop">${XS.esc(XS.t('sg_stop', null, 'Stop and close up'))}</button><span style="margin-left:auto;color:var(--m-faint)">${XS.esc(XS.t('sg_hint', null, 'Space or click to act · arrow keys to suture'))}</span></div>
            </div>`;
        stage.querySelector('#sg-v').outerHTML = `${vit('HR', vitals.hr || '--', '#3dff7a')}${vit('NIBP', `${vitals.sys || '--'}/${vitals.dia || '--'}`, '#ff4b4b')}${vit('SpO2', vitals.spo2 || '--', '#36d8ff')}${vit('RESP', vitals.resp || '--', '#ffe14a')}`;
        const canvas = stage.querySelector('#sg-ecg');
        canvas.width = 560;
        XS.Wave.attach(canvas, { kind: 'ecg', color: '#3dff7a', hr: () => vitals.hr || 80, rhythm: () => 'sinus', speed: 160 });
        stage.querySelector('#sg-stop').addEventListener('click', () => finish());
        stage.querySelector('#sg-steps').innerHTML = stepsHtml();
        nextPhase();
    }

    function refreshVitals() {
        if (!stage) return;
        const cells = stage.querySelectorAll('.sg-vitals .vt-cell b');
        if (cells.length === 4) {
            cells[0].textContent = vitals.hr || '--';
            cells[1].textContent = `${vitals.sys || '--'}/${vitals.dia || '--'}`;
            cells[2].textContent = vitals.spo2 || '--';
            cells[3].textContent = vitals.resp || '--';
        }
    }

    function stopGame() {
        if (game && game.raf) cancelAnimationFrame(game.raf);
        if (game && game.keyHandler) window.removeEventListener('keydown', game.keyHandler);
        if (game && game.clickHandler) stage.querySelector('#sg-game').removeEventListener('mousedown', game.clickHandler);
        game = null;
    }

    function phaseDone(ok) {
        const g = game;
        stopGame();
        op.score += ok ? 1 : 0;
        op.phase += 1;
        const box = stage.querySelector('#sg-game');
        box.insertAdjacentHTML('beforeend', `<div class="sg-result" style="color:${ok ? '#3dff7a' : '#ff4b4b'}">${XS.esc(ok ? XS.t('sg_clean', null, 'Clean.') : XS.t('sg_slip', null, 'Slipped.'))}</div>`);
        setTimeout(() => { if (open && g) nextPhase(); }, 650);
    }

    function barGame(title, text, zoneWidth, speed, hold) {
        const box = stage.querySelector('#sg-game');
        box.innerHTML = `<h3>${XS.esc(title)}</h3><p>${XS.esc(text)}</p><div class="sg-bar"><div class="sg-zone"></div><div class="sg-needle"></div></div>`;
        const bar = box.querySelector('.sg-bar');
        const zone = box.querySelector('.sg-zone');
        const needle = box.querySelector('.sg-needle');
        const width = 640;
        const zw = width * zoneWidth;
        let zx = Math.random() * (width - zw);
        zone.style.left = `${zx}px`;
        zone.style.width = `${zw}px`;
        let pos = 0;
        let dir = 1;
        let held = 0;
        let pressed = false;
        game = {};
        const start = performance.now();
        let prev = start;
        const tick = (now) => {
            const dt = (now - prev) / 1000;
            prev = now;
            if (hold) {
                zx += Math.sin(now / 520) * 2.2;
                zx = Math.max(0, Math.min(width - zw, zx));
                zone.style.left = `${zx}px`;
                pos += (pressed ? 1 : -1) * speed * dt;
                pos = Math.max(0, Math.min(width - 4, pos));
                const inside = pos >= zx && pos <= zx + zw;
                held = inside ? held + dt : Math.max(0, held - dt * 0.6);
                needle.style.left = `${pos}px`;
                if (held >= 2.6) return phaseDone(true);
                if (now - start > 9000) return phaseDone(false);
            } else {
                pos += dir * speed * dt;
                if (pos > width - 4) { pos = width - 4; dir = -1; }
                if (pos < 0) { pos = 0; dir = 1; }
                needle.style.left = `${pos}px`;
                if (now - start > 9000) return phaseDone(false);
            }
            game.raf = requestAnimationFrame(tick);
        };
        game.raf = requestAnimationFrame(tick);
        if (hold) {
            game.clickHandler = () => { pressed = true; };
            box.addEventListener('mousedown', game.clickHandler);
            const up = () => { pressed = false; };
            window.addEventListener('mouseup', up, { once: false });
            game.keyHandler = (e) => { if (e.code === 'Space') pressed = e.type === 'keydown'; };
            window.addEventListener('keydown', game.keyHandler);
            window.addEventListener('keyup', game.keyHandler);
        } else {
            const act = () => phaseDone(pos >= zx && pos <= zx + zw);
            game.clickHandler = act;
            box.addEventListener('mousedown', act);
            game.keyHandler = (e) => { if (e.code === 'Space') { e.preventDefault(); act(); } };
            window.addEventListener('keydown', game.keyHandler);
        }
    }

    function sutureGame() {
        const box = stage.querySelector('#sg-game');
        const seq = Array.from({ length: 5 }, () => ARROWS[Math.floor(Math.random() * 4)]);
        let at = 0;
        box.innerHTML = `<h3>${XS.esc(XS.t('sg_suture', null, 'Suture'))}</h3><p>${XS.esc(XS.t('sg_suture_text', null, 'Press the arrows in order.'))}</p><div class="sg-keys">${seq.map((k) => `<span>${GLYPH[k]}</span>`).join('')}</div>`;
        const spans = box.querySelectorAll('.sg-keys span');
        game = {};
        const start = performance.now();
        game.keyHandler = (e) => {
            if (!ARROWS.includes(e.key)) return;
            e.preventDefault();
            if (e.key === seq[at]) {
                spans[at].classList.add('k-done');
                at += 1;
                if (at >= seq.length) phaseDone(true);
            } else {
                phaseDone(false);
            }
        };
        window.addEventListener('keydown', game.keyHandler);
        const watch = () => {
            if (!game) return;
            if (performance.now() - start > 7000) return phaseDone(false);
            game.raf = requestAnimationFrame(watch);
        };
        game.raf = requestAnimationFrame(watch);
    }

    function nextPhase() {
        if (!open) return;
        const injuries = XS.list(op.injuries);
        if (op.phase >= PHASES.length) {
            const inj = injuries[op.index];
            op.results[inj.id] = op.score >= 2;
            op.index += 1;
            op.phase = 0;
            op.score = 0;
            stage.querySelector('#sg-steps').innerHTML = stepsHtml();
        }
        if (op.index >= injuries.length) return finish();
        const phase = PHASES[op.phase];
        if (phase === 'incise') barGame(XS.t('sg_incise', null, 'Incision'), XS.t('sg_incise_text', null, 'Cut when the blade is inside the green.'), 0.16, 520, false);
        else if (phase === 'repair') barGame(XS.t('sg_repair', null, 'Repair'), XS.t('sg_repair_text', null, 'Hold the mouse or space to keep the forceps on target.'), 0.2, 260, true);
        else sutureGame();
    }

    async function finish() {
        if (!open || op.finishing) return;
        op.finishing = true;
        stopGame();
        clearInterval(timerId);
        const results = {};
        XS.list(op.injuries).forEach((inj) => { results[String(inj.id)] = op.results[inj.id] === true; });
        const res = await XS.rpc('surgery:end', { results });
        XS.toast(res.ok ? res.data : res.error, res.ok ? 'ok' : 'error');
        XS.close('surgery');
    }

    XS.apps.surgery = {
        isOpen: () => open,
        escape: () => finish(),
        on(action, data) {
            if (action === 'open') {
                op = Object.assign({ index: 0, phase: 0, score: 0, results: {} }, data);
                vitals = data.vitals || {};
                open = true;
                XS.show('xsm-surgery', true);
                deadline = Date.now() + (Number(data.seconds) || 45) * 1000;
                render();
                clearInterval(timerId);
                timerId = setInterval(() => {
                    const left = Math.max(0, Math.round((deadline - Date.now()) / 1000));
                    const el = stage && stage.querySelector('#sg-timer');
                    if (el) el.textContent = XS.clock(left);
                    if (left <= 0) finish();
                }, 250);
            } else if (action === 'vitals') {
                vitals = data || {};
                refreshVitals();
            } else if (action === 'close') {
                open = false;
                stopGame();
                clearInterval(timerId);
                XS.show('xsm-surgery', false);
                root.innerHTML = '';
            }
        },
    };
})();
