(() => {
    const root = document.getElementById('xsm-self');
    let open = false;
    let state = null;
    let have = {};

    function vitCell(label, value, unit, colour) {
        return `<div class="vt-cell" style="color:${colour}"><small>${XS.esc(label)}</small><b>${XS.esc(value)}</b><em>${XS.esc(unit || '')}</em></div>`;
    }

    function useButtons(injury) {
        const out = [];
        XS.needs(injury).forEach((key) => {
            const supply = (XS.config.supplies || {})[key];
            if (!supply || !supply.self) return;
            const count = Number(have[key] || 0);
            out.push(`<button class="xsm-key ${count > 0 ? 'k-go' : ''}" data-use="${key}" data-injury="${injury.id}" ${count > 0 ? '' : 'disabled'}>${XS.esc(XS.t(`supply_${key}`, null, key))}<small>×${count}</small></button>`);
        });
        return out.join('');
    }

    function render() {
        const stage = XS.stage(root);
        const s = state || {};
        const v = s.vitals || {};
        const injuries = XS.list(s.injuries);
        const rows = injuries.length ? injuries.map((i) => `
            <div class="ij-row"><b>${XS.esc(XS.part(i.part))}</b><span>${XS.esc(XS.describe(i))}</span><div class="ij-acts">${useButtons(i)}</div></div>`).join('')
            : `<div class="xsm-empty">${XS.esc(XS.t('self_none', null, 'No injuries. You are in one piece.'))}</div>`;
        const general = ['painkillers', 'ifaks'].filter((k) => (XS.config.supplies || {})[k] && (XS.config.supplies[k] || {}).self).map((k) => {
            const count = Number(have[k] || 0);
            return `<button class="xsm-key ${count > 0 ? 'k-blue' : ''}" data-use="${k}" ${count > 0 ? '' : 'disabled'}>${XS.esc(XS.t(`supply_${k}`, null, k))}<small>×${count}</small></button>`;
        }).join('');
        stage.innerHTML = `
            <div class="sf-box">
                <div class="sf-head"><b>${XS.esc(XS.t('self_title', null, 'My condition'))}</b><span>${XS.esc(XS.t('self_blood', { n: s.blood != null ? s.blood : 100 }, `Blood ${s.blood}%`))}</span></div>
                <div class="sf-body">
                    <div class="sf-fig">${XS.Figure.svg(injuries)}</div>
                    <div class="sf-list xsm-scroll">${rows}</div>
                    <div class="sf-vit">
                        ${vitCell('HR', v.hr || '--', 'bpm', '#3dff7a')}
                        ${vitCell('NIBP', `${v.sys || '--'}/${v.dia || '--'}`, 'mmHg', '#ff4b4b')}
                        ${vitCell('SpO2', v.spo2 || '--', '%', '#36d8ff')}
                        ${vitCell(XS.t('hud_pain', null, 'PAIN'), v.pain != null ? v.pain : '-', XS.t('self_of_ten', null, 'of 10'), '#ffe14a')}
                    </div>
                </div>
                <div class="sf-foot">${general}<span style="margin-left:auto;color:var(--m-faint)">${XS.esc(XS.t('hint_esc', null, 'ESC to close'))}</span></div>
            </div>`;
        stage.querySelectorAll('[data-use]').forEach((btn) => {
            btn.addEventListener('click', async () => {
                if (btn.disabled) return;
                const res = await XS.rpc('self:use', { supply: btn.dataset.use, injury: btn.dataset.injury ? Number(btn.dataset.injury) : null });
                if (!res.ok) XS.toast(res.error, 'error');
            });
        });
    }

    XS.apps.self = {
        isOpen: () => open,
        escape: () => XS.close('self'),
        on(action, data) {
            if (action === 'state') {
                state = data;
                XS.Hud.state(data);
                if (open) render();
            } else if (action === 'open') {
                state = data.state || state;
                have = data.have || {};
                open = true;
                XS.show('xsm-self', true);
                render();
            } else if (action === 'close') {
                open = false;
                XS.show('xsm-self', false);
                root.innerHTML = '';
            } else if (action === 'reset') {
                state = null;
                XS.Hud.state(null);
            }
        },
    };
})();
