(() => {
    const root = document.getElementById('xsm-tablet');
    let open = false;
    let data = null;
    let page = 'patient';
    let patient = null;
    let patientId = null;
    let refreshTimer = null;
    const view = {};
    const PAGES = ['patient', 'calls', 'records', 'prescribe', 'roster', 'reports', 'hospital'];

    const t = XS.t;
    const esc = XS.esc;

    async function call(name, ...args) {
        const res = await XS.rpc(`tablet:${name}`, { args });
        if (!res.ok && res.error) XS.toast(res.error, 'error');
        return res;
    }

    function shell() {
        const stage = XS.stage(root);
        const calls = XS.list(data.calls).filter((c) => c.status !== 'closed').length;
        const me = data.me || {};
        stage.innerHTML = `
            <div class="tb-dim"></div>
            <div class="tb-case"><div class="tb-screen">
                <div class="tb-top">
                    <span class="tb-brand">${esc(me.jobLabel || 'EMS')} · XS-MEDICAL</span>
                    <span class="tb-who">${esc(t('tb_medic', null, 'Medic'))}: ${esc((me.name || '').toUpperCase())}${me.callsign ? ` · ${esc(me.callsign)}` : ''}</span>
                    <span class="tb-clock" id="tb-clock"></span>
                    <span class="tb-right"><span id="tb-alarm"></span><button class="tb-close" id="tb-close">✕</button></span>
                </div>
                <div class="tb-rail">${PAGES.map((p) => `<div class="tb-tab ${p === page ? 't-on' : ''}" data-page="${p}">${esc(t(`tab_${p}`, null, p))}${p === 'calls' && calls ? `<em>${calls}</em>` : ''}</div>`).join('')}</div>
                <div class="tb-page" id="tb-page"></div>
                <div class="tb-bar" id="tb-bar"></div>
            </div></div>`;
        stage.querySelector('#tb-close').addEventListener('click', () => XS.close('tablet'));
        stage.querySelectorAll('[data-page]').forEach((tab) => tab.addEventListener('click', () => go(tab.dataset.page)));
        const tickClock = () => {
            const el = stage.querySelector('#tb-clock');
            if (!el) return;
            const d = new Date();
            el.textContent = `${String(d.getHours()).padStart(2, '0')}:${String(d.getMinutes()).padStart(2, '0')}`;
        };
        tickClock();
        return stage;
    }

    function go(next) {
        page = next;
        shell();
        renderPage();
    }

    function pageEl() { return root.querySelector('#tb-page'); }
    function barEl() { return root.querySelector('#tb-bar'); }

    function bar(buttons, right) {
        const el = barEl();
        if (!el) return;
        el.innerHTML = buttons.map((b) => `<button class="xsm-key ${b.cls || ''}" data-act="${b.id}" ${b.disabled ? 'disabled' : ''}>${esc(b.label)}${b.key ? `<small>${esc(b.key)}</small>` : ''}</button>`).join('') + (right ? `<span class="tb-inv">${esc(right)}</span>` : '');
        el.querySelectorAll('[data-act]').forEach((btn) => {
            const b = buttons.find((x) => x.id === btn.dataset.act);
            btn.addEventListener('click', () => { if (!btn.disabled && b && b.run) b.run(); });
        });
    }

    function renderPage() {
        clearInterval(refreshTimer);
        const alarm = root.querySelector('#tb-alarm');
        if (alarm) alarm.innerHTML = '';
        if (page === 'patient') return pagePatient();
        if (page === 'calls') return pageCalls();
        if (page === 'records') return pageRecords();
        if (page === 'prescribe') return pagePrescribe();
        if (page === 'roster') return pageRoster();
        if (page === 'reports') return pageReports();
        if (page === 'hospital') return pageHospital();
    }

    function acuityColour(a) {
        return ({ 1: '#ff3b4e', 2: '#ff8a1f', 3: '#ffd22e', 4: '#33c26b', 5: '#4aa3ff' })[a] || '#4aa3ff';
    }

    async function loadPatient(src) {
        patientId = src;
        const res = await call('patient', src);
        patient = res.ok ? res.data : null;
        return patient;
    }

    function vitCell(label, value, sub, colour) {
        return `<div class="vt-cell" style="color:${colour}"><small>${esc(label)}</small><b>${esc(value)}</b><em>${esc(sub || '')}</em></div>`;
    }

    function supplyLabel(key) { return t(`supply_${key}`, null, key); }

    async function treat(supply, injury) {
        await XS.rpc('tablet:treat', { target: patientId, supply, injury });
    }

    function action(name) {
        XS.rpc('tablet:action', { target: patientId, action: name });
    }

    async function pagePatient() {
        const el = pageEl();
        if (!patientId) {
            const near = XS.list(data.nearby);
            el.innerHTML = `<div class="pt-none"><h3>${esc(t('pt_pick', null, 'Pick a patient'))}</h3><div class="near-list">${near.length ? near.map((n) => `
                <div class="near-row" data-src="${n.src}"><span class="ac-dot" style="background:${acuityColour(n.acuity)}"></span><b>${esc(n.name)}</b><span class="xsm-chip ${n.status === 'alive' ? 'c-dim' : 'c-red'}">${esc(t(`status_${n.status}`, null, n.status))}</span><span style="color:var(--m-dim)">${esc(n.dist)} m</span></div>`).join('')
                : `<div class="xsm-empty">${esc(t('pt_nobody', null, 'Nobody close enough. Walk up to your patient.'))}</div>`}</div>
                <button class="xsm-key" id="pt-rescan">${esc(t('pt_rescan', null, 'Look again'))}</button></div>`;
            el.querySelectorAll('[data-src]').forEach((row) => row.addEventListener('click', async () => {
                await loadPatient(Number(row.dataset.src));
                pagePatient();
            }));
            el.querySelector('#pt-rescan').addEventListener('click', async () => {
                const res = await call('nearby');
                if (res.ok) data.nearby = res.data;
                pagePatient();
            });
            bar([]);
            return;
        }
        if (!patient) await loadPatient(patientId);
        if (!patient) {
            patientId = null;
            return pagePatient();
        }
        drawPatient();
        refreshTimer = setInterval(async () => {
            if (!open || page !== 'patient' || !patientId) return;
            const res = await XS.rpc('tablet:patient', { args: [patientId] });
            if (res.ok) {
                patient = res.data;
                updateVitals();
            }
        }, 2500);
    }

    function updateVitals() {
        if (!patient) return;
        const v = (patient.state && patient.state.vitals) || {};
        const dead = v.status === 'arrest' || v.status === 'dead';
        const cells = pageEl().querySelectorAll('.pt-side .vt-cell b');
        if (cells.length >= 4) {
            cells[0].textContent = dead ? '0' : (v.hr || '--');
            cells[1].textContent = dead ? '--/--' : `${v.sys || '--'}/${v.dia || '--'}`;
            cells[2].textContent = dead ? '--' : (v.spo2 || '--');
            cells[3].textContent = dead ? '0' : (v.resp || '--');
        }
        const alarm = root.querySelector('#tb-alarm');
        const alarms = XS.list(v.alarms);
        if (alarm) alarm.innerHTML = alarms.length ? `<span class="tb-alarm ${dead ? 'xsm-blink' : ''}">⚠ ${esc(t(`alarm_${alarms[0]}`, null, alarms[0]).toUpperCase())}</span>` : '';
    }

    function drawPatient() {
        const p = patient;
        const s = p.state || {};
        const v = s.vitals || {};
        const injuries = XS.list(s.injuries);
        const rec = p.record;
        const visit = p.visit;
        const meta = [
            p.female ? t('pt_female', null, 'F') : t('pt_male', null, 'M'),
            rec && rec.blood ? `${t('pt_blood', null, 'blood')} ${rec.blood}` : null,
            rec && rec.allergies ? `${t('pt_allergy', null, 'allergy')}: ${rec.allergies}` : null,
            visit && visit.room ? visit.room : null,
            visit ? t(`visit_${visit.status}`, null, visit.status) : null,
            !p.near ? t('pt_far', { m: p.dist }, `${p.dist} m away`) : null,
        ].filter(Boolean).join(' · ');
        const nearOpts = XS.list(data.nearby).map((n) => `<option value="${n.src}" ${n.src === patientId ? 'selected' : ''}>${esc(n.name)} (${esc(n.dist)} m)</option>`).join('');
        const rows = injuries.length ? injuries.map((i) => {
            const needs = XS.needs(i);
            const chips = needs.map((k) => k === 'surgery'
                ? `<span class="xsm-chip c-pink">${esc(t('need_surgery', null, 'Surgery'))}</span>`
                : `<button class="xsm-chip ${k === 'tourniquet' ? 'c-red' : (k === 'splint' ? 'c-yellow' : 'c-blue')}" data-treat="${k}" data-inj="${i.id}" style="border:0;cursor:pointer">${esc(supplyLabel(k))}</button>`).join(' ');
            return `<div class="ij-row"><b>${esc(XS.part(i.part))}</b><span>${esc(XS.describe(i))}</span><div class="ij-acts">${chips || `<span class="xsm-chip c-green">${esc(t('need_ok', null, 'OK'))}</span>`}</div></div>`;
        }).join('') : `<div class="xsm-empty">${esc(t('pt_no_injuries', null, 'No injuries found'))}</div>`;
        const pain = v.pain != null ? v.pain : '-';
        const tl = XS.list(p.timeline).slice(-12).reverse().map((e) => `<div class="tl-row"><b>${esc(XS.time(e.t))}</b><span>${esc(e.text)}</span><em>${esc(e.by || '')}</em></div>`).join('');
        const dead = v.status === 'arrest' || v.status === 'dead';
        pageEl().innerHTML = `
            <div class="pt-wrap">
                <div class="pt-main">
                    <div class="pt-head"><span class="pt-name">${esc(p.name)}</span><span class="pt-meta">${esc(meta)}</span>
                        <span class="pt-pick"><select id="pt-near"><option value="">${esc(t('pt_switch', null, 'Switch patient…'))}</option>${nearOpts}</select></span></div>
                    <div class="pt-waves">
                        <span class="w-lbl" style="top:2px;color:#3dff7a">II</span><canvas id="pt-ecg" height="100" style="top:14px;height:100px"></canvas>
                        <span class="w-lbl" style="top:118px;color:#36d8ff">PLETH</span><canvas id="pt-pleth" height="66" style="top:130px;height:66px"></canvas>
                    </div>
                    <div class="pt-low">
                        <div class="pt-fig">${XS.Figure.svg(injuries)}</div>
                        <div class="pt-right"><div class="pt-inj xsm-scroll">${rows}</div><div class="pt-tl xsm-scroll">${tl || `<div class="tl-row"><span style="color:var(--m-faint)">${esc(t('pt_no_timeline', null, 'Nothing logged yet'))}</span></div>`}</div></div>
                    </div>
                </div>
                <div class="pt-side">
                    ${vitCell('HR', dead ? '0' : (v.hr || '--'), t(`rhythm_${v.rhythm || 'sinus'}`, null, ''), '#3dff7a')}
                    ${vitCell('NIBP', dead ? '--/--' : `${v.sys || '--'}/${v.dia || '--'}`, 'mmHg', '#ff4b4b')}
                    ${vitCell('SpO2', dead ? '--' : (v.spo2 || '--'), '%', '#36d8ff')}
                    ${vitCell('RESP', dead ? '0' : (v.resp || '--'), '/min', '#ffe14a')}
                    <div class="pt-rec">${esc(t('pt_pain', null, 'Pain'))} <b>${esc(pain)}/10</b> · ${esc(t('pt_blood_level', null, 'Blood'))} <b>${esc(s.blood != null ? s.blood : 100)}%</b> · AVPU <b>${esc(v.avpu || '-')}</b>${s.iv ? ` · IV <b>${esc(s.iv)}</b>` : ''}</div>
                </div>
            </div>`;
        const ecg = pageEl().querySelector('#pt-ecg');
        const pleth = pageEl().querySelector('#pt-pleth');
        const rhythmFn = () => {
            const vv = (patient && patient.state && patient.state.vitals) || {};
            if (vv.status === 'arrest') return vv.rhythm === 'vf' ? 'vf' : 'asystole';
            if (vv.status === 'dead') return 'asystole';
            return 'sinus';
        };
        const hrFn = () => { const vv = (patient && patient.state && patient.state.vitals) || {}; return (vv.status === 'arrest' || vv.status === 'dead') ? 0 : (vv.hr || 0); };
        XS.Wave.attach(ecg, { kind: 'ecg', color: '#3dff7a', hr: hrFn, rhythm: rhythmFn });
        XS.Wave.attach(pleth, { kind: 'pleth', color: '#36d8ff', hr: hrFn, rhythm: rhythmFn, amp: 0.7 });
        pageEl().querySelector('#pt-near').addEventListener('change', async (e) => {
            if (!e.target.value) return;
            await loadPatient(Number(e.target.value));
            drawPatient();
        });
        pageEl().querySelectorAll('[data-treat]').forEach((b) => b.addEventListener('click', () => treat(b.dataset.treat, Number(b.dataset.inj))));
        updateVitals();
        const status = s.status;
        const buttons = [
            { id: 'treat', label: t('act_treat', null, 'Treat'), cls: 'k-go', run: () => treatMenu() },
            { id: 'stretcher', label: t('act_stretcher', null, 'Stretcher'), run: () => action('stretcher') },
            { id: 'bed', label: t('act_bed', null, 'To bed'), run: () => action('bed') },
            { id: 'surgery', label: t('act_surgery', null, 'Surgery'), cls: 'k-surg', disabled: !data.can.surgery || !injuries.some((i) => i.surgery), run: () => action('surgery') },
            { id: 'prescribe', label: t('act_prescribe', null, 'Prescribe'), disabled: !data.can.prescribe || !p.identified, run: () => { view.rxFor = { cid: p.cid, name: p.realName || p.name }; go('prescribe'); } },
        ];
        if (!p.identified) buttons.push({ id: 'checkid', label: t('act_checkid', null, 'Check ID'), cls: 'k-blue', run: () => action('checkid') });
        if (status === 'arrest') buttons.push({ id: 'cpr', label: t('act_cpr', null, 'CPR'), cls: 'k-warn', run: () => action('cpr') });
        buttons.push({ id: 'bill', label: t('act_bill', null, 'Bill'), run: () => action('bill') });
        if (patient.visit && status === 'alive') buttons.push({ id: 'discharge', label: t('act_discharge', null, 'Discharge'), run: async () => { const r = await call('discharge', patientId); if (r.ok) XS.toast(t('discharged', null, 'Discharged.'), 'ok'); } });
        buttons.push({ id: 'report', label: t('act_report', null, 'Report'), run: () => { view.reportFrom = patient; go('reports'); } });
        bar(buttons);
    }

    function treatMenu() {
        const keys = ['bandage', 'tourniquet', 'gauze', 'splint', 'burncream', 'painkillers', 'morphine', 'saline', 'adrenaline', 'defibrillator', 'firstaid', 'ifaks'];
        const el = pageEl();
        const overlay = document.createElement('div');
        overlay.style.cssText = 'position:absolute;inset:0;background:rgba(0,0,0,.72);display:grid;place-items:center;z-index:5';
        overlay.innerHTML = `<div class="mu-box" style="position:relative;left:auto;top:auto;transform:none;width:520px"><div class="mu-head"><b>${esc(t('treat_menu_title', null, 'Treat'))}</b><span>${esc(patient.name)}</span></div>
            <div class="mu-list">${keys.filter((k) => (data.supplies || {})[k]).map((k) => `<div class="mu-row" data-k="${k}"><b>${esc(supplyLabel(k))}</b><span>${esc(t(`supply_hint_${k}`, null, ''))}</span></div>`).join('')}</div>
            <div class="mu-foot"><span></span><span class="xsm-key" id="tm-close">${esc(t('close', null, 'Close'))}</span></div></div>`;
        el.appendChild(overlay);
        overlay.querySelector('#tm-close').addEventListener('click', () => overlay.remove());
        overlay.querySelectorAll('[data-k]').forEach((row) => row.addEventListener('click', () => { overlay.remove(); treat(row.dataset.k, null); }));
    }

    async function pageCalls() {
        const res = await call('calls');
        const calls = res.ok ? XS.list(res.data) : XS.list(data.calls);
        data.calls = calls;
        pageEl().innerHTML = `<div class="pg-pad"><div class="pg-h">${esc(t('calls_title', null, 'Medical calls'))}</div><div class="xsm-scroll" style="display:flex;flex-direction:column;gap:8px;flex:1">
            ${calls.length ? calls.map((c) => {
                const mine = XS.list(c.units).some((u) => u.src === (data.me || {}).src);
                const units = XS.list(c.units).map((u) => u.name).join(', ');
                return `<div class="cl-row p-${c.priority}">
                    <div class="cl-id">#${esc(c.id)}<small>${esc(c.code || '')} · ${esc(XS.ago(c.createdAt))}</small></div>
                    <div class="cl-body"><b>${esc(c.title)}</b><span>${esc([c.street, c.description].filter(Boolean).join(' — '))}</span><span>${esc(t('calls_caller', { name: c.caller || '' }, `Caller: ${c.caller}`))}${units ? ` · ${esc(t('calls_units', { names: units }, units))}` : ''}</span></div>
                    <div class="cl-acts">${mine ? `<button class="xsm-key" data-leave="${c.id}">${esc(t('calls_leave', null, 'Leave'))}</button>` : `<button class="xsm-key k-go" data-take="${c.id}">${esc(t('calls_take', null, 'Take'))}</button>`}
                        <button class="xsm-key" data-wp="${c.id}">${esc(t('calls_gps', null, 'GPS'))}</button><button class="xsm-key k-warn" data-close="${c.id}">${esc(t('calls_close', null, 'Close'))}</button></div>
                </div>`;
            }).join('') : `<div class="xsm-empty">${esc(t('calls_none', null, 'No open calls. Quiet shift.'))}</div>`}</div></div>`;
        const el = pageEl();
        el.querySelectorAll('[data-take]').forEach((b) => b.addEventListener('click', async () => {
            const r = await XS.rpc('tablet:callTake', { id: Number(b.dataset.take) });
            if (r.ok) XS.toast(t('calls_taken', null, 'Call taken. GPS set.'), 'ok'); else XS.toast(r.error, 'error');
            pageCalls();
        }));
        el.querySelectorAll('[data-leave]').forEach((b) => b.addEventListener('click', async () => { await call('callLeave', Number(b.dataset.leave)); pageCalls(); }));
        el.querySelectorAll('[data-close]').forEach((b) => b.addEventListener('click', async () => { await call('callClose', Number(b.dataset.close)); pageCalls(); }));
        el.querySelectorAll('[data-wp]').forEach((b) => b.addEventListener('click', () => {
            const c = calls.find((x) => String(x.id) === b.dataset.wp);
            if (c && c.coords) XS.rpc('tablet:waypoint', c.coords).then(() => XS.toast(t('calls_gps_set', null, 'GPS set.'), 'ok'));
        }));
        bar([{ id: 'refresh', label: t('refresh', null, 'Refresh'), run: pageCalls }]);
    }

    async function pageRecords() {
        const el = pageEl();
        el.innerHTML = `<div class="pg-pad"><div class="pg-row"><input class="xsm-input" id="rc-q" placeholder="${esc(t('rc_search', null, 'Search name or citizen ID'))}" value="${esc(view.rcQuery || '')}"><button class="xsm-key k-go" id="rc-go">${esc(t('search', null, 'Search'))}</button></div>
            <div class="pg-split"><div class="pg-col xsm-scroll" id="rc-list"></div><div class="pg-col xsm-scroll" id="rc-view"><div class="xsm-empty">${esc(t('rc_pick', null, 'Search for a patient to open their record'))}</div></div></div></div>`;
        const run = async () => {
            view.rcQuery = el.querySelector('#rc-q').value.trim();
            const res = await call('recordsSearch', view.rcQuery);
            const list = res.ok ? XS.list(res.data) : [];
            el.querySelector('#rc-list').innerHTML = list.length ? list.map((r) => `<div class="ls-row" data-cid="${esc(r.cid)}"><div><b>${esc(r.name)}</b><span>${esc(r.cid)} · ${esc(r.dob || '')}</span></div></div>`).join('') : `<div class="xsm-empty">${esc(t('rc_none', null, 'No matches'))}</div>`;
            el.querySelectorAll('[data-cid]').forEach((row) => row.addEventListener('click', () => openRecord(row.dataset.cid)));
        };
        el.querySelector('#rc-go').addEventListener('click', run);
        el.querySelector('#rc-q').addEventListener('keydown', (e) => { if (e.key === 'Enter') run(); });
        if (view.rcQuery) run();
        if (view.rcOpen) openRecord(view.rcOpen);
        bar([]);
    }

    async function openRecord(cid) {
        view.rcOpen = cid;
        const res = await call('recordsOpen', cid);
        if (!res.ok) return;
        const r = res.data;
        const can = data.can.editRecords;
        const box = pageEl().querySelector('#rc-view');
        box.innerHTML = `<div class="rc-card">
            <div class="rc-top"><div><small>${esc(t('rc_name', null, 'Name'))}</small><b>${esc(r.name)}</b></div><div><small>${esc(t('rc_dob', null, 'Born'))}</small><b>${esc(r.dob || '—')}</b></div>
                <div><small>${esc(t('rc_blood', null, 'Blood'))}</small><b><input class="xsm-input" id="rc-blood" style="width:70px;padding:4px 6px" value="${esc(r.blood)}" ${can ? '' : 'disabled'}></b></div><div><small>CID</small><b>${esc(r.cid)}</b></div></div>
            <div class="rc-grid">
                <div><label class="xsm-label">${esc(t('rc_allergies', null, 'Allergies'))}</label><textarea class="xsm-input" id="rc-all" rows="3" ${can ? '' : 'disabled'}>${esc(r.allergies)}</textarea></div>
                <div><label class="xsm-label">${esc(t('rc_conditions', null, 'Conditions'))}</label><textarea class="xsm-input" id="rc-con" rows="3" ${can ? '' : 'disabled'}>${esc(r.conditions)}</textarea></div>
                <div style="grid-column:1/-1"><label class="xsm-label">${esc(t('rc_notes', null, 'Notes'))}</label><textarea class="xsm-input" id="rc-notes" rows="3" ${can ? '' : 'disabled'}>${esc(r.notes)}</textarea></div>
            </div>
            ${can ? `<div class="pg-row"><button class="xsm-key k-go" id="rc-save">${esc(t('save', null, 'Save'))}</button>${data.can.prescribe ? `<button class="xsm-key" id="rc-rx">${esc(t('act_prescribe', null, 'Prescribe'))}</button>` : ''}</div>` : ''}
            <div class="pg-h">${esc(t('rc_rx', null, 'Prescriptions'))}</div>
            <div>${XS.list(r.prescriptions).map((x) => `<div class="hs-row"><b>${esc(XS.date(x.createdAt))}</b><span>${esc(x.label)} ${esc(x.dose)}</span><span>${esc(t(`rx_${x.status}`, null, x.status))} · ${esc(x.prescriber)}</span><span>×${esc(x.qty)} +${esc(x.refills)}</span></div>`).join('') || `<div class="hs-row"><span style="color:var(--m-faint)">${esc(t('rc_none_yet', null, 'None yet'))}</span></div>`}</div>
            <div class="pg-h">${esc(t('rc_history', null, 'History'))}</div>
            <div>${XS.list(r.history).map((h) => `<div class="hs-row"><b>${esc(XS.date(h.created_at))}</b><span>${esc(t(`hist_${h.kind}`, null, h.kind))}</span><span>${esc(h.summary)}</span><span>${esc(h.medic_name || '')}</span></div>`).join('') || `<div class="hs-row"><span style="color:var(--m-faint)">${esc(t('rc_none_yet', null, 'None yet'))}</span></div>`}</div>
        </div>`;
        const save = box.querySelector('#rc-save');
        if (save) save.addEventListener('click', async () => {
            const res2 = await call('recordsSave', cid, { blood: box.querySelector('#rc-blood').value, allergies: box.querySelector('#rc-all').value, conditions: box.querySelector('#rc-con').value, notes: box.querySelector('#rc-notes').value });
            if (res2.ok) XS.toast(t('saved', null, 'Saved.'), 'ok');
        });
        const rx = box.querySelector('#rc-rx');
        if (rx) rx.addEventListener('click', () => { view.rxFor = { cid: r.cid, name: r.name }; go('prescribe'); });
    }

    async function pagePrescribe() {
        const meds = XS.list(data.medicines);
        const who = view.rxFor;
        const el = pageEl();
        el.innerHTML = `<div class="pg-pad"><div class="pg-split" style="grid-template-columns:420px 1fr">
            <div class="pg-col"><div class="pg-h">${esc(t('rx_new', null, 'New prescription'))}</div>
                <div class="rc-card"><div class="rc-top"><div><small>${esc(t('ph_patient', null, 'Patient'))}</small><b>${esc(who ? who.name : t('rx_pick_patient', null, 'Open a record or a patient first'))}</b></div></div>
                <div class="tb-form">
                    <div class="f-wide"><label class="xsm-label">${esc(t('rx_medicine', null, 'Medicine'))}</label><select class="xsm-input" id="rx-med">${meds.map((m) => `<option value="${esc(m.item)}">${esc(m.label)} · ${esc(m.dose)}</option>`).join('')}</select></div>
                    <div><label class="xsm-label">${esc(t('rx_dose', null, 'Dose'))}</label><input class="xsm-input" id="rx-dose" placeholder="${esc(meds[0] ? meds[0].dose : '')}"></div>
                    <div><label class="xsm-label">${esc(t('rx_qty', null, 'Quantity'))}</label><input class="xsm-input" id="rx-qty" type="number" min="1" max="30" value="10"></div>
                    <div><label class="xsm-label">${esc(t('rx_refills', null, 'Refills'))}</label><input class="xsm-input" id="rx-ref" type="number" min="0" max="5" value="0"></div>
                    <div class="f-wide"><label class="xsm-label">${esc(t('rx_notes', null, 'Notes for the pharmacist'))}</label><input class="xsm-input" id="rx-notes"></div>
                </div>
                <button class="xsm-key k-go" id="rx-go" ${who && who.cid && data.can.prescribe ? '' : 'disabled'}>${esc(t('rx_write', null, 'Write prescription'))}</button></div>
            </div>
            <div class="pg-col xsm-scroll" id="rx-list"></div></div></div>`;
        if (who && who.cid) {
            const res = await call('recordsOpen', who.cid);
            const list = res.ok ? XS.list(res.data.prescriptions) : [];
            el.querySelector('#rx-list').innerHTML = `<div class="pg-h">${esc(t('rc_rx', null, 'Prescriptions'))}</div>` + (list.length ? list.map((x) => `<div class="ls-row"><div><b>${esc(x.label)} ${esc(x.dose)} · ×${esc(x.qty)} +${esc(x.refills)}</b><span>${esc(t(`rx_${x.status}`, null, x.status))} · ${esc(x.prescriber)} · ${esc(XS.date(x.createdAt))}</span></div>${x.status === 'active' && data.can.prescribe ? `<button class="xsm-key k-warn" data-void="${x.id}">${esc(t('rx_void', null, 'Void'))}</button>` : ''}</div>`).join('') : `<div class="xsm-empty">${esc(t('rc_none_yet', null, 'None yet'))}</div>`);
            el.querySelectorAll('[data-void]').forEach((b) => b.addEventListener('click', async () => { await call('rxVoid', Number(b.dataset.void)); pagePrescribe(); }));
        }
        const goBtn = el.querySelector('#rx-go');
        goBtn.addEventListener('click', async () => {
            if (goBtn.disabled) return;
            const res = await call('rxCreate', who.cid, {
                item: el.querySelector('#rx-med').value, dose: el.querySelector('#rx-dose').value, qty: Number(el.querySelector('#rx-qty').value),
                refills: Number(el.querySelector('#rx-ref').value), notes: el.querySelector('#rx-notes').value,
            });
            if (res.ok) { XS.toast(t('rx_written', null, 'Prescription sent to the pharmacy.'), 'ok'); pagePrescribe(); }
        });
        bar([]);
    }

    async function pageRoster() {
        const res = await call('roster');
        if (!res.ok) return;
        const r = res.data;
        const grades = XS.list(r.grades);
        const gradeOpts = (sel) => grades.map((g) => `<option value="${g.level}" ${Number(sel) === g.level ? 'selected' : ''}>${esc(g.label)}</option>`).join('');
        const el = pageEl();
        el.innerHTML = `<div class="pg-pad"><div class="pg-row"><div class="pg-h" style="flex:1">${esc(t('ro_online', null, 'Staff online'))}</div>
            <input class="xsm-input" id="ro-cs" style="width:140px" placeholder="${esc(t('ro_callsign', null, 'Callsign'))}" value="${esc((data.me || {}).callsign || '')}"><button class="xsm-key" id="ro-cs-save">${esc(t('ro_set_callsign', null, 'Set callsign'))}</button>
            ${r.canManage ? `<span style="color:var(--m-dim)">${esc(t('ro_balance', { amount: r.balance || 0 }, `Account $${r.balance}`))}</span>` : ''}</div>
            <div class="xsm-scroll" style="display:flex;flex-direction:column;gap:6px;max-height:${r.canManage ? '230px' : '560px'}">${XS.list(r.online).map((m) => `<div class="ro-row"><span class="ro-dot ${m.onDuty ? 'd-on' : ''}"></span><b>${esc(m.name)}</b><span>${esc(m.callsign || '—')}</span><span style="color:var(--m-dim)">${esc(m.gradeLabel || m.grade)}</span><span class="xsm-chip ${m.onDuty ? 'c-green' : 'c-dim'}">${esc(m.onDuty ? t('ro_on', null, 'On duty') : t('ro_off', null, 'Off duty'))}</span></div>`).join('') || `<div class="xsm-empty">${esc(t('ro_nobody', null, 'Nobody online'))}</div>`}</div>
            ${r.canManage ? `<div class="pg-row"><div class="pg-h" style="flex:1">${esc(t('ro_staff', null, 'Staff list'))}</div><input class="xsm-input" id="ro-hire-id" style="width:120px" placeholder="${esc(t('ro_server_id', null, 'Server ID'))}"><select class="xsm-input" id="ro-hire-grade" style="width:180px">${gradeOpts(0)}</select><button class="xsm-key k-go" id="ro-hire">${esc(t('ro_hire', null, 'Hire'))}</button></div>
            <div class="xsm-scroll" style="display:flex;flex-direction:column;gap:6px;flex:1">${XS.list(r.staff).map((s) => `<div class="ro-row"><span class="ro-dot ${s.online ? 'd-on' : ''}"></span><b>${esc(s.name)}</b><span style="color:var(--m-dim)">${esc(s.cid)}</span><select class="xsm-input" data-grade="${esc(s.cid)}">${gradeOpts(s.grade)}</select><button class="xsm-key k-warn" data-fire="${esc(s.cid)}">${esc(t('ro_fire', null, 'Fire'))}</button></div>`).join('')}</div>` : ''}
        </div>`;
        el.querySelector('#ro-cs-save').addEventListener('click', async () => {
            const res2 = await call('callsign', el.querySelector('#ro-cs').value);
            if (res2.ok) { data.me.callsign = res2.data; XS.toast(t('saved', null, 'Saved.'), 'ok'); }
        });
        if (r.canManage) {
            el.querySelector('#ro-hire').addEventListener('click', async () => {
                const res2 = await call('hire', Number(el.querySelector('#ro-hire-id').value), Number(el.querySelector('#ro-hire-grade').value));
                if (res2.ok) { XS.toast(t('ro_hired', null, 'Hired.'), 'ok'); pageRoster(); }
            });
            el.querySelectorAll('[data-grade]').forEach((s) => s.addEventListener('change', async () => {
                const res2 = await call('setGrade', s.dataset.grade, Number(s.value));
                if (res2.ok) XS.toast(t('saved', null, 'Saved.'), 'ok');
            }));
            el.querySelectorAll('[data-fire]').forEach((b) => b.addEventListener('click', async () => {
                const res2 = await call('fire', b.dataset.fire);
                if (res2.ok) { XS.toast(t('ro_fired', null, 'Let go.'), 'ok'); pageRoster(); }
            }));
        }
        bar([]);
    }

    async function pageReports() {
        const el = pageEl();
        const from = view.reportFrom;
        view.reportFrom = null;
        el.innerHTML = `<div class="pg-pad"><div class="pg-split" style="grid-template-columns:400px 1fr">
            <div class="pg-col"><div class="pg-row"><input class="xsm-input" id="rp-q" placeholder="${esc(t('rp_search', null, 'Search reports'))}"><button class="xsm-key" id="rp-go">${esc(t('search', null, 'Search'))}</button><button class="xsm-key k-go" id="rp-new">${esc(t('rp_new', null, 'New'))}</button></div><div class="xsm-scroll" id="rp-list" style="display:flex;flex-direction:column;gap:6px;flex:1"></div></div>
            <div class="pg-col xsm-scroll" id="rp-view"></div></div></div>`;
        const list = async () => {
            const res = await call('reportsList', el.querySelector('#rp-q').value);
            const rows = res.ok ? XS.list(res.data) : [];
            el.querySelector('#rp-list').innerHTML = rows.length ? rows.map((r) => `<div class="ls-row" data-id="${r.id}"><div><b>${esc(r.title)}</b><span>${esc(r.patient_name || '')} · ${esc(r.author_name)} · ${esc(XS.date(r.created_at))}</span></div></div>`).join('') : `<div class="xsm-empty">${esc(t('rp_none', null, 'No reports'))}</div>`;
            el.querySelectorAll('#rp-list [data-id]').forEach((row) => row.addEventListener('click', () => showReport(Number(row.dataset.id))));
        };
        el.querySelector('#rp-go').addEventListener('click', list);
        el.querySelector('#rp-new').addEventListener('click', () => editor(null));
        list();
        if (from) editor(from); else el.querySelector('#rp-view').innerHTML = `<div class="xsm-empty">${esc(t('rp_pick', null, 'Open a report or write a new one'))}</div>`;
        bar([]);
    }

    function editor(from) {
        const box = pageEl().querySelector('#rp-view');
        const lines = from ? XS.list(from.timeline).map((e) => XS.time(e.t) + ' ' + e.text).join('\n') : '';
        const inj = from ? XS.list(from.state && from.state.injuries).map((i) => XS.part(i.part) + ': ' + XS.describe(i)).join('\n') : '';
        const v = from && from.state ? from.state.vitals || {} : {};
        const body = from ? `${t('rp_tpl_injuries', null, 'Injuries')}:\n${inj}\n\n${t('rp_tpl_vitals', null, 'Vitals')}: HR ${v.hr || '-'} · BP ${v.sys || '-'}/${v.dia || '-'} · SpO2 ${v.spo2 || '-'}\n\n${t('rp_tpl_timeline', null, 'Timeline')}:\n${lines}` : '';
        box.innerHTML = `<div class="rc-card"><div class="tb-form">
            <div class="f-wide"><label class="xsm-label">${esc(t('rp_title', null, 'Title'))}</label><input class="xsm-input" id="rp-title" value="${esc(from ? t('rp_tpl_title', { name: from.realName || from.name }, `Patient care report — ${from.name}`) : '')}"></div>
            <div><label class="xsm-label">${esc(t('ph_patient', null, 'Patient'))}</label><input class="xsm-input" id="rp-patient" value="${esc(from ? (from.realName || from.name) : '')}"></div>
            <div><label class="xsm-label">CID</label><input class="xsm-input" id="rp-cid" value="${esc(from && from.cid ? from.cid : '')}"></div>
            <div class="f-wide"><label class="xsm-label">${esc(t('rp_body', null, 'Report'))}</label><textarea class="xsm-input" id="rp-body" rows="14">${esc(body)}</textarea></div>
        </div><div class="pg-row"><button class="xsm-key k-go" id="rp-save">${esc(t('save', null, 'Save'))}</button></div></div>`;
        box.querySelector('#rp-save').addEventListener('click', async () => {
            const res = await call('reportsSave', {
                title: box.querySelector('#rp-title').value, patient: box.querySelector('#rp-patient').value, cid: box.querySelector('#rp-cid').value,
                body: box.querySelector('#rp-body').value, timeline: from ? XS.list(from.timeline) : [], vitals: v, injuries: from ? XS.list(from.state && from.state.injuries) : [],
            });
            if (res.ok) { XS.toast(t('saved', null, 'Saved.'), 'ok'); pageReports(); }
        });
    }

    async function showReport(id) {
        const res = await call('reportsGet', id);
        if (!res.ok) return;
        const r = res.data;
        const box = pageEl().querySelector('#rp-view');
        box.innerHTML = `<div class="rc-card"><div class="rc-top"><div><small>${esc(t('rp_title', null, 'Title'))}</small><b>${esc(r.title)}</b></div><div><small>${esc(t('ph_patient', null, 'Patient'))}</small><b>${esc(r.patient_name || '—')}</b></div><div><small>${esc(t('rp_author', null, 'Written by'))}</small><b>${esc(r.author_name)}</b></div><div><small>${esc(t('rp_date', null, 'Date'))}</small><b>${esc(XS.date(r.created_at))}</b></div></div>
            <div style="white-space:pre-wrap;font:13px/1.55 var(--m-mono);color:#c9dccf">${esc(r.body || '')}</div>
            ${data.can.deleteReports ? `<div class="pg-row"><button class="xsm-key k-warn" id="rp-del">${esc(t('delete', null, 'Delete'))}</button></div>` : ''}</div>`;
        const del = box.querySelector('#rp-del');
        if (del) del.addEventListener('click', async () => { const r2 = await call('reportsDelete', id); if (r2.ok) pageReports(); });
    }

    async function pageHospital() {
        const places = XS.list(data.places);
        const el = pageEl();
        if (!places.length) {
            el.innerHTML = `<div class="xsm-empty" style="margin-top:120px">${esc(t('hs_none', null, 'No hospitals built yet. An admin can add one with the builder.'))}</div>`;
            bar([]);
            return;
        }
        const id = view.hospital || places[0].id;
        el.innerHTML = `<div class="pg-pad"><div class="pg-row"><select class="xsm-input" id="hs-pick" style="width:300px">${places.map((p) => `<option value="${p.id}" ${p.id === id ? 'selected' : ''}>${esc(p.name)}</option>`).join('')}</select></div><div class="xsm-scroll" id="hs-body" style="flex:1"></div></div>`;
        el.querySelector('#hs-pick').addEventListener('change', (e) => { view.hospital = Number(e.target.value); pageHospital(); });
        const res = await call('hospital', id);
        if (!res.ok) return;
        const h = res.data;
        const beds = XS.list(h.beds);
        const board = XS.list(h.board);
        el.querySelector('#hs-body').innerHTML = `<div class="pg-h" style="margin:4px 0 10px">${esc(t('hs_beds', null, 'Beds'))}</div><div class="bed-grid">${beds.map((b) => `<div class="bed-card ${b.occupant ? '' : 'b-free'}" style="${b.acuity ? `box-shadow:inset 3px 0 0 ${acuityColour(b.acuity)}` : ''}"><b>${esc(b.room || b.label)} · ${esc(b.label)}</b><span>${esc(b.occupant ? `${b.name} · ${t(`visit_${b.status}`, null, b.status || '')}` : t('hs_free', null, 'Free'))}</span></div>`).join('')}</div>
            <div class="pg-h" style="margin:18px 0 10px">${esc(t('hs_board', null, 'On the board'))}</div>
            ${board.length ? board.map((r) => `<div class="ls-row" data-src="${r.src}"><div><b>${esc(r.name)} · ${esc(r.room || '')}</b><span>${esc(t(`visit_${r.status}`, null, r.status))}${r.medic ? ` · ${esc(r.medic)}` : ''} · ${esc(XS.ago(r.since))}</span></div><span class="ac-dot" style="background:${acuityColour(r.acuity)}"></span></div>`).join('') : `<div class="xsm-empty">${esc(t('hs_board_empty', null, 'Nobody waiting'))}</div>`}`;
        el.querySelectorAll('#hs-body [data-src]').forEach((row) => row.addEventListener('click', async () => {
            await loadPatient(Number(row.dataset.src));
            go('patient');
        }));
        bar([{ id: 'refresh', label: t('refresh', null, 'Refresh'), run: pageHospital }]);
    }

    XS.apps.tablet = {
        isOpen: () => open,
        escape: () => XS.close('tablet'),
        on(action, payload) {
            if (action === 'open') {
                data = payload;
                data.can = data.can || {};
                open = true;
                page = payload.page && PAGES.includes(payload.page) ? payload.page : 'patient';
                patient = null;
                patientId = payload.patient || null;
                XS.show('xsm-tablet', true);
                shell();
                renderPage();
            } else if (action === 'close') {
                open = false;
                clearInterval(refreshTimer);
                XS.show('xsm-tablet', false);
                root.innerHTML = '';
            } else if (action === 'calls') {
                if (!open || !data) return;
                const c = payload.call;
                const list = XS.list(data.calls).filter((x) => x.id !== c.id);
                if (c.status !== 'closed') list.unshift(c);
                data.calls = list;
                if (page === 'calls') pageCalls();
            } else if (action === 'refreshPatient') {
                if (open && page === 'patient' && patientId) loadPatient(patientId).then(() => { if (patient) drawPatient(); });
            }
        },
    };
})();
