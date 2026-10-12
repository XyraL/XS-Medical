(() => {
    const root = document.getElementById('xsm-down');
    let state = null;
    let open = false;
    let stage = null;
    let called = false;

    const titleFor = (s) => ({
        down: XS.t('down_title', null, 'YOU ARE DOWN'),
        knockout: XS.t('down_title_ko', null, 'KNOCKED OUT'),
        arrest: XS.t('down_title_arrest', null, 'NO PULSE'),
        dead: XS.t('down_title_dead', null, 'FLATLINE'),
    }[s] || XS.t('down_title', null, 'YOU ARE DOWN'));

    function subFor(s) {
        if (s.status === 'knockout') return XS.t('down_sub_ko', null, 'Knocked cold. You will come round on your own.');
        if (s.status === 'arrest') return XS.t('down_sub_arrest', null, 'Your heart has stopped. CPR or a defibrillator can still bring you back.');
        if (s.status === 'dead') return XS.t('down_sub_dead', null, 'Too late for the paramedics. Wake up in hospital when you are ready.');
        const worst = XS.list(s.injuries).reduce((m, i) => Math.max(m, i.bleed || 0), 0);
        const bleeder = XS.list(s.injuries).find((i) => (i.bleed || 0) === worst && worst > 0);
        if (bleeder) return XS.t('down_sub_bleeding', { part: XS.part(bleeder.part).toLowerCase() }, `Bleeding from the ${bleeder.part}. Help is your best chance.`);
        return XS.t('down_sub_stable', null, 'You are not bleeding. Stay put and call for help.');
    }

    function render() {
        if (!state) return;
        stage = XS.stage(root, 'dn-stage');
        const calm = state.status === 'knockout';
        const dead = state.status === 'arrest' || state.status === 'dead';
        stage.innerHTML = `
            <div class="dn-dim"></div>
            <div class="dn-title ${calm ? 't-calm' : ''}">${XS.esc(titleFor(state.status))}<span class="dn-sub">${XS.esc(subFor(state))}</span></div>
            <div class="dn-strip"><canvas id="dn-ecg" width="1250" height="170"></canvas></div>
            <div class="dn-hr ${dead ? 'h-dead' : ''}"><small>HR</small><b id="dn-hr">--</b><em id="dn-rhythm"></em></div>
            <div class="dn-info" id="dn-info"></div>
            <div class="dn-keys" id="dn-keys"></div>
            <div class="dn-note" id="dn-note"></div>`;
        XS.Wave.attach(stage.querySelector('#dn-ecg'), {
            kind: 'ecg', color: dead ? '#ff4b4b' : '#3dff7a', width: 3, speed: 210, amp: 0.38,
            hr: () => (state && state.vitals ? state.vitals.hr : 0),
            rhythm: () => (state && state.status === 'arrest' ? (state.rhythm === 'vf' ? 'vf' : 'asystole') : (state && state.status === 'dead' ? 'asystole' : 'sinus')),
        });
        update();
    }

    function chip(label, value, cls) {
        return `<div class="dn-chip ${cls || ''}"><small>${XS.esc(label)}</small><b>${XS.esc(value)}</b></div>`;
    }

    function update(holding) {
        if (!stage || !state) return;
        const s = state.seconds || {};
        const v = state.vitals || {};
        const dead = state.status === 'arrest' || state.status === 'dead';
        const hr = stage.querySelector('#dn-hr');
        hr.textContent = dead ? '0' : String(v.hr || '--');
        stage.querySelector('#dn-rhythm').textContent = XS.t(`rhythm_${state.status === 'arrest' ? (state.rhythm || 'vf') : (dead ? 'asystole' : (v.rhythm || 'sinus'))}`, null, '');
        const chips = [];
        if (state.status === 'down') {
            chips.push(s.bleedOut != null
                ? chip(XS.t('down_bleeds_out', null, 'BLEEDS OUT IN'), XS.clock(s.bleedOut), 'c-alarm')
                : chip(XS.t('down_stable', null, 'CONDITION'), XS.t('down_stable_value', null, 'Stable'), 'c-ok'));
        } else if (state.status === 'knockout') {
            chips.push(chip(XS.t('down_wakes', null, 'COMING ROUND IN'), XS.clock(s.wake || 0)));
        } else if (state.status === 'arrest') {
            chips.push(chip(XS.t('down_cpr_window', null, 'CPR WINDOW'), XS.clock(s.arrest || 0), 'c-alarm'));
        }
        const ems = Number(state.ems || 0);
        chips.push(chip(XS.t('down_ems', null, 'EMS'), ems > 0
            ? XS.t('down_ems_value', { n: ems }, `${ems} on duty`) + (called ? ` · ${XS.t('down_alerted', null, 'alerted')}` : '')
            : XS.t('down_ems_none', null, 'none on duty')));
        if (state.status !== 'knockout') {
            chips.push(chip(XS.t('down_respawn', null, 'RESPAWN'), (s.respawn || 0) > 0 ? XS.t('down_in', { time: XS.clock(s.respawn) }, `in ${XS.clock(s.respawn)}`) : XS.t('down_hold_e', null, 'hold E'), (s.respawn || 0) > 0 ? '' : 'c-ok'));
        }
        stage.querySelector('#dn-info').innerHTML = chips.join('');
        const canGive = state.status !== 'knockout' && (s.respawn || 0) === 0;
        const keys = [`<span class="xsm-key k-go">${XS.esc(XS.t('down_key_call', null, 'Call for help'))}<small>G</small></span>`];
        if (state.status === 'down') keys.push(`<span class="xsm-key">${XS.esc(XS.t('down_key_crawl', null, 'Crawl'))}<small>WASD</small></span>`);
        if (state.status !== 'knockout') {
            keys.push(`<span class="xsm-key k-warn dn-hold" ${canGive ? '' : 'disabled'}><i style="width:${Math.round((holding || 0) * 100)}%"></i>${XS.esc(XS.t('down_key_giveup', null, 'Give up'))}<small>${XS.esc(XS.t('down_hold', null, 'hold E'))}</small></span>`);
        }
        stage.querySelector('#dn-keys').innerHTML = keys.join('');
    }

    XS.apps.down = {
        isOpen: () => open,
        on(action, data) {
            if (action === 'open') {
                state = data;
                called = false;
                open = true;
                XS.show('xsm-down', true);
                render();
            } else if (action === 'update') {
                const before = state && state.status;
                state = Object.assign(state || {}, data);
                if (!open) {
                    open = true;
                    XS.show('xsm-down', true);
                    render();
                } else if (before !== state.status) {
                    render();
                } else {
                    update();
                }
            } else if (action === 'tick') {
                if (!state) return;
                state.seconds = data.seconds || state.seconds;
                update(data.holding);
            } else if (action === 'called') {
                if (data.ok) called = true;
                XS.toast(data.ok ? XS.t('call_sent', null, 'Help is on the way. Stay put.') : data.message, data.ok ? 'ok' : 'error');
                update();
            } else if (action === 'close') {
                open = false;
                state = null;
                XS.show('xsm-down', false);
                root.innerHTML = '';
            }
        },
    };
})();
