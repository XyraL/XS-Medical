(() => {
    const root = document.getElementById('xsm-hud');
    const stage = XS.stage(root, 'hd-stage');
    stage.innerHTML = '<div id="hd-strip" class="xsm-hidden"></div><div id="hd-bed" class="xsm-hidden"></div><div class="pg-stack" id="hd-pager"></div>';
    const strip = stage.querySelector('#hd-strip');
    const bed = stage.querySelector('#hd-bed');
    const pager = stage.querySelector('#hd-pager');
    let bedInfo = null;

    XS.Hud = {
        state(pub) {
            if (!pub || XS.config.hud === false) { strip.classList.add('xsm-hidden'); return; }
            const injuries = XS.list(pub.injuries);
            const show = pub.status === 'alive' && (injuries.length > 0 || Number(pub.blood) < 95);
            strip.classList.toggle('xsm-hidden', !show || !!(bedInfo && bedInfo.sedated));
            if (!show) return;
            const v = pub.vitals || {};
            const worst = injuries.reduce((m, i) => Math.max(m, i.bleed || 0), 0);
            strip.className = 'hd-strip';
            strip.innerHTML = `
                <div class="hd-cell" style="color:#3dff7a"><small>HR</small><b>${XS.esc(v.hr || '--')}</b></div>
                <div class="hd-cell" style="color:#ff4b4b"><small>BP</small><b>${XS.esc(`${v.sys || '--'}/${v.dia || '--'}`)}</b></div>
                <div class="hd-cell" style="color:#36d8ff"><small>SpO2</small><b>${XS.esc(v.spo2 || '--')}</b></div>
                <div class="hd-cell" style="color:#ffe14a"><small>${XS.esc(XS.t('hud_pain', null, 'PAIN'))}</small><b>${XS.esc(v.pain != null ? v.pain : '-')}</b></div>
                ${worst > 0 ? `<div class="hd-bleed xsm-blink">${XS.esc(XS.t('hud_bleeding', null, 'BLEEDING'))}</div>` : ''}`;
        },
    };

    function renderBed(data) {
        bedInfo = data;
        bed.className = 'bd-box';
        if (data.sedated) {
            bed.innerHTML = `<b>${XS.esc(data.label || '')}</b><span>${XS.esc(XS.t('bed_sedated', null, 'Under anaesthetic. The team is working on you.'))}</span>`;
            return;
        }
        const left = Number(data.left != null ? data.left : data.seconds) || 0;
        let line = data.treat ? XS.t('bed_treating', { time: XS.clock(left) }, `Being treated · ${XS.clock(left)}`) : XS.t('bed_resting', null, 'Resting');
        if (data.canLeave) line = `<span class="bd-go">${XS.esc(XS.t('bed_leave', null, '[E] Get up'))}</span>`;
        else line = XS.esc(line);
        bed.innerHTML = `<b>${XS.esc(data.label || XS.t('bed_title', null, 'Hospital bed'))}</b><span>${line}</span>`;
    }

    function addPager(head, big, lines, ttl) {
        const card = document.createElement('div');
        card.className = 'pg-card';
        card.innerHTML = `<div class="pg-lcd"><div class="pg-hd"><span>${XS.esc(head)}</span><span>${XS.esc(XS.time(Date.now() / 1000))}</span></div><div class="pg-big">${XS.esc(big)}</div>${lines.map((l) => `<div>${XS.esc(l)}</div>`).join('')}</div>`;
        pager.prepend(card);
        while (pager.children.length > 3) pager.lastElementChild.remove();
        setTimeout(() => card.remove(), ttl || 12000);
    }

    XS.apps.bed = {
        on(action, data) {
            if (action === 'open') {
                bed.classList.remove('xsm-hidden');
                renderBed(Object.assign({ left: data.seconds }, data));
            } else if (action === 'tick') {
                if (!bedInfo) return;
                renderBed(Object.assign({}, bedInfo, data, { label: bedInfo.label }));
            } else if (action === 'close') {
                bedInfo = null;
                bed.className = 'xsm-hidden';
                bed.innerHTML = '';
            }
        },
    };

    XS.apps.pager = {
        on(action, data) {
            if (action === 'call' && data.call) {
                const c = data.call;
                const lines = [c.street || '', c.description || ''];
                if (data.dist != null) lines.push(XS.t('pager_dist', { m: data.dist }, `${data.dist} m away`));
                addPager(XS.t('pager_head', null, 'EMS PAGE'), ((c.code || '') + ' ' + (c.title || '')).trim().toUpperCase(), lines.filter(Boolean), 15000);
            } else if (action === 'page') {
                addPager(XS.t('pager_head', null, 'EMS PAGE'), (data.title || '').toUpperCase(), [data.text || ''], 12000);
            }
        },
    };
})();
