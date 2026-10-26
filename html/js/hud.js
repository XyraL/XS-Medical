(() => {
    const root = document.getElementById('xsm-hud');
    const stage = XS.stage(root, 'hd-stage');
    stage.innerHTML = '<div id="hd-strip" class="xsm-hidden"></div><div id="hd-bed" class="xsm-hidden"></div><div class="al-stack" id="hd-alerts"></div>';
    const strip = stage.querySelector('#hd-strip');
    const bed = stage.querySelector('#hd-bed');
    const alerts = stage.querySelector('#hd-alerts');
    const t = XS.t;
    const esc = XS.esc;
    const PIN = '<svg class="al-i" viewBox="0 0 24 24"><path d="M20 10c0 6-8 12-8 12s-8-6-8-12a8 8 0 0 1 16 0Z"/><circle cx="12" cy="10" r="3"/></svg>';
    const BELL = '<svg class="al-i" viewBox="0 0 24 24"><path d="M6 8a6 6 0 0 1 12 0c0 7 3 9 3 9H3s3-2 3-9"/><path d="M10.3 21a1.94 1.94 0 0 0 3.4 0"/></svg>';
    const BED = '<svg class="al-i" viewBox="0 0 24 24"><path d="M2 4v16M2 8h18a2 2 0 0 1 2 2v10M2 17h20M6 8v9"/></svg>';
    const SHADE = { 1: '#ff4d5e', 2: '#ffb020', 3: '#3ddc97' };
    let bedInfo = null;
    let bedTotal = 0;

    function level(value, red, yellow) {
        if (value === null || value === undefined || value === '' || Number.isNaN(Number(value))) return '';
        if (red(Number(value))) return 'r';
        if (yellow(Number(value))) return 'y';
        return '';
    }

    XS.Hud = {
        state(pub) {
            if (!pub || XS.config.hud === false) { strip.className = 'xsm-hidden'; return; }
            const injuries = XS.list(pub.injuries);
            const show = pub.status === 'alive' && (injuries.length > 0 || Number(pub.blood) < 95);
            if (!show || (bedInfo && bedInfo.sedated)) { strip.className = 'xsm-hidden'; return; }
            const v = pub.vitals || {};
            const bleeding = injuries.some((i) => (i.bleed || 0) > 0);
            const cells = [
                ['HR', v.hr || '--', level(v.hr, (n) => n < 50 || n > 130, (n) => n < 60 || n > 100)],
                ['BP', `${v.sys || '--'}/${v.dia || '--'}`, level(v.sys, (n) => n < 85, (n) => n < 100)],
                ['SpO2', v.spo2 || '--', level(v.spo2, (n) => n < 90, (n) => n < 95)],
                [t('hud_pain', null, 'Pain'), v.pain !== null && v.pain !== undefined ? v.pain : '-', level(v.pain, (n) => n >= 7, (n) => n >= 4)],
            ];
            const warn = bleeding ? 'r' : (cells.some((c) => c[2]) ? 'y' : '');
            strip.className = `hd-strip ${warn ? `s-${warn}` : ''}`;
            strip.innerHTML = cells.map(([label, value, tone]) => `<div class="hd-cell"><small>${esc(label)}</small><b class="${tone}">${esc(value)}</b></div>`).join('')
                + (bleeding ? `<div class="hd-bleed"><i></i>${esc(t('hud_bleeding', null, 'Bleeding'))}</div>` : '');
        },
    };

    function renderBed(data) {
        bedInfo = data;
        bed.className = 'bd-box';
        if (data.sedated) {
            bed.innerHTML = `<span class="bd-ic">${BED}</span><div class="bd-txt"><small>${esc(data.label || '')}</small><b>${esc(t('bed_sedated_title', null, 'Under anaesthetic'))}</b><span>${esc(t('bed_sedated', null, 'The team is working on you.'))}</span></div>`;
            return;
        }
        const left = Math.max(0, Number(data.left !== undefined && data.left !== null ? data.left : data.seconds) || 0);
        let title = t('bed_waiting', null, 'Waiting for a medic');
        let right = '';
        let bar = '';
        if (data.canLeave) {
            title = data.treat ? t('bed_ready', null, 'Ready to go') : t('bed_waiting', null, 'Waiting for a medic');
            right = `<span class="bd-key"><span class="al-kbd">E</span>${esc(t('bed_get_up', null, 'Get up'))}</span>`;
        } else if (data.treat) {
            title = t('bed_treat_title', null, 'Being treated');
            right = `<span class="bd-time">${esc(XS.clock(left))}</span>`;
            const done = bedTotal > 0 ? Math.min(100, Math.max(0, (1 - left / bedTotal) * 100)) : 0;
            bar = `<i class="bd-prog" style="width:${done.toFixed(1)}%"></i>`;
        }
        bed.innerHTML = `<span class="bd-ic">${BED}</span><div class="bd-txt"><small>${esc(data.label || t('bed_title', null, 'Hospital bed'))}</small><b>${esc(title)}</b></div>${right}${bar}`;
    }

    XS.apps.bed = {
        on(action, data) {
            if (action === 'open') {
                bedTotal = Number(data.seconds) || 0;
                renderBed(Object.assign({ left: data.seconds }, data));
            } else if (action === 'tick') {
                if (!bedInfo) return;
                renderBed(Object.assign({}, bedInfo, data, { label: bedInfo.label }));
            } else if (action === 'close') {
                bedInfo = null;
                bedTotal = 0;
                bed.className = 'xsm-hidden';
                bed.innerHTML = '';
            }
        },
    };

    function metres(m) {
        if (m === null || m === undefined || m === '') return '';
        const n = Number(m);
        return n >= 1000 ? `${(n / 1000).toFixed(1)} km` : `${Math.round(n)} m`;
    }

    function drop(card) {
        if (!card || card.dataset.gone) return;
        card.dataset.gone = '1';
        card.classList.add('al-out');
        setTimeout(() => card.remove(), 220);
    }

    function push(card, seconds) {
        alerts.prepend(card);
        while (alerts.children.length > 3) alerts.lastElementChild.remove();
        card.timer = setTimeout(() => drop(card), seconds * 1000);
    }

    function addCall(c, dist, given) {
        const old = alerts.querySelector(`.al-card[data-call="${Number(c.id)}"]`);
        if (old) old.remove();
        const pri = Math.min(3, Math.max(1, Number(c.priority) || 2));
        const keys = given || {};
        const seconds = Number(XS.config.alertSeconds) || 15;
        const parts = String(c.description || '').split(' · ').filter(Boolean);
        const asTags = parts.length > 0 && parts.every((p) => p.length <= 28);
        const detail = asTags
            ? `<div class="al-tags">${parts.slice(0, 3).map((p) => `<span class="al-tag ${pri === 1 ? 'g-red' : ''}">${esc(p)}</span>`).join('')}</div>`
            : (c.description ? `<div class="al-text">${esc(c.description)}</div>` : '');
        const where = [c.street, metres(dist)].filter(Boolean).join(' · ');
        const card = document.createElement('div');
        card.className = 'al-card';
        card.dataset.call = String(Number(c.id));
        card.style.setProperty('--q', SHADE[pri]);
        card.innerHTML = `<div class="al-pri"><small>P</small><b>${pri}</b></div>
            <div class="al-body">
                <div class="al-top"><span class="al-live">${esc(t('alert_incoming', { code: c.code || '' }, `Incoming call · ${c.code || ''}`))}</span><span>#${Number(c.id)}</span></div>
                <div class="al-title">${esc(c.title || '')}</div>
                ${where ? `<div class="al-loc">${PIN}<span>${esc(where)}</span></div>` : ''}
                ${detail}
            </div>
            ${keys.respond || keys.hide ? `<div class="al-keys">${keys.respond ? `<span class="al-kbd">${esc(keys.respond)}</span>${esc(t('alert_respond', null, 'Respond'))}` : ''}${keys.hide ? `<span class="al-kbd">${esc(keys.hide)}</span>${esc(t('alert_hide', null, 'Hide'))}` : ''}<span class="al-age" data-since="${Number(c.createdAt) || Math.floor(Date.now() / 1000)}"></span></div>` : ''}
            <i class="al-timer" style="animation-duration:${seconds}s"></i>`;
        push(card, seconds);
        ageTick();
    }

    function addPage(data) {
        const card = document.createElement('div');
        card.className = 'al-card al-page';
        card.style.setProperty('--q', 'var(--x-accent)');
        card.innerHTML = `<div class="al-pri">${BELL}</div>
            <div class="al-body">
                <div class="al-top"><span class="al-live">${esc(t('alert_page', { title: data.title || '' }, `Page · ${data.title || ''}`))}</span><span>${esc(XS.time(Date.now() / 1000))}</span></div>
                <div class="al-title">${esc(data.text || '')}</div>
            </div>
            <i class="al-timer" style="animation-duration:12s"></i>`;
        push(card, 12);
    }

    function ageTick() {
        alerts.querySelectorAll('[data-since]').forEach((el) => {
            const s = Math.max(0, Math.floor(Date.now() / 1000 - Number(el.dataset.since)));
            el.textContent = `${Math.floor(s / 60)}:${String(s % 60).padStart(2, '0')}`;
        });
    }
    setInterval(ageTick, 1000);

    XS.apps.alert = {
        on(action, data) {
            if (action === 'call' && data.call) {
                addCall(data.call, data.dist, data.keys);
            } else if (action === 'page') {
                addPage(data);
            } else if (action === 'taken') {
                const card = alerts.querySelector(`.al-card[data-call="${Number(data.id)}"]`);
                if (!card) return;
                clearTimeout(card.timer);
                card.classList.add('al-ok');
                const live = card.querySelector('.al-live');
                if (live) live.textContent = t('alert_responding', null, 'Responding · GPS set');
                const keys = card.querySelector('.al-keys');
                if (keys) keys.remove();
                setTimeout(() => drop(card), 2600);
            } else if (action === 'hide') {
                const card = data.id ? alerts.querySelector(`.al-card[data-call="${Number(data.id)}"]`) : alerts.querySelector('.al-card:not([data-gone])');
                if (card) { clearTimeout(card.timer); drop(card); }
            } else if (action === 'gone') {
                const card = alerts.querySelector(`.al-card[data-call="${Number(data.id)}"]`);
                if (card) { clearTimeout(card.timer); drop(card); }
            }
        },
    };
})();
