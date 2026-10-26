(() => {
    const root = document.getElementById('xsm-tablet');
    const t = XS.t;
    const esc = XS.esc;
    const NAV = [['shift', ['patient', 'calls', 'hospital']], ['records', ['records', 'prescribe', 'reports']], ['staff', ['roster']]];
    const PAGES = NAV.reduce((all, group) => all.concat(group[1]), []);
    const OPTIONAL = ['records', 'prescribe', 'reports', 'roster'];
    const on = (p) => !OPTIONAL.includes(p) || ((XS.config || {}).pages || {})[p] !== false;
    const ICON = {
        patient: '<path d="M22 12h-4l-3 9L9 3l-3 9H2"/>',
        calls: '<path d="M7 18v-6a5 5 0 1 1 10 0v6"/><path d="M5 21a1 1 0 0 1-1-1v-1a2 2 0 0 1 2-2h12a2 2 0 0 1 2 2v1a1 1 0 0 1-1 1z"/><path d="M21 12h1M18.5 4.5 18 5M2 12h1M12 2v1M4.9 4.9l.7.7"/>',
        hospital: '<path d="M2 4v16M2 8h18a2 2 0 0 1 2 2v10M2 17h20M6 8v9"/>',
        records: '<path d="M4 20h16a2 2 0 0 0 2-2V8a2 2 0 0 0-2-2h-7.9a2 2 0 0 1-1.7-.9l-.8-1.2A2 2 0 0 0 7.9 3H4a2 2 0 0 0-2 2v13a2 2 0 0 0 2 2z"/>',
        prescribe: '<path d="m10.5 20.5 10-10a4.95 4.95 0 1 0-7-7l-10 10a4.95 4.95 0 1 0 7 7z"/><path d="m8.5 8.5 7 7"/>',
        reports: '<path d="M15 2H6a2 2 0 0 0-2 2v16a2 2 0 0 0 2 2h12a2 2 0 0 0 2-2V7z"/><path d="M14 2v4a2 2 0 0 0 2 2h4M16 13H8M16 17H8M10 9H8"/>',
        roster: '<path d="M16 21v-2a4 4 0 0 0-4-4H6a4 4 0 0 0-4 4v2"/><circle cx="9" cy="7" r="4"/><path d="M22 21v-2a4 4 0 0 0-3-3.87M16 3.13a4 4 0 0 1 0 7.75"/>',
        search: '<circle cx="11" cy="11" r="8"/><path d="m21 21-4.3-4.3"/>',
        close: '<path d="M18 6 6 18M6 6l12 12"/>',
        pin: '<path d="M20 10c0 6-8 12-8 12s-8-6-8-12a8 8 0 0 1 16 0Z"/><circle cx="12" cy="10" r="3"/>',
        clock: '<circle cx="12" cy="12" r="10"/><path d="M12 6v6l4 2"/>',
        gps: '<polygon points="3 11 22 2 13 21 11 13 3 11"/>',
        body: '<circle cx="12" cy="8" r="5"/><path d="M20 21a8 8 0 0 0-16 0"/>',
        log: '<path d="M8 6h13M8 12h13M8 18h13M3 6h.01M3 12h.01M3 18h.01"/>',
        wound: '<rect x="2" y="6" width="20" height="12" rx="2"/><path d="M10 10.01h.01M10 14.01h.01M14 10.01h.01M14 14.01h.01M18 6v12M6 6v12"/>',
        refresh: '<path d="M3 12a9 9 0 0 1 9-9 9.75 9.75 0 0 1 6.74 2.74L21 8"/><path d="M21 3v5h-5"/><path d="M21 12a9 9 0 0 1-9 9 9.75 9.75 0 0 1-6.74-2.74L3 16"/><path d="M8 16H3v5"/>',
        plus: '<path d="M12 5v14M5 12h14"/>',
        cross: '<path d="M9 3h6v6h6v6h-6v6H9v-6H3V9h6z"/>',
    };
    const TONE = { 1: 'red', 2: 'orange', 3: 'yellow', 4: 'green', 5: 'blue' };
    const SHADE = { 1: '#ff4d5e', 2: '#ff8a3d', 3: '#ffb020', 4: '#3ddc97', 5: '#4d8dff' };
    const TREAT_KEYS = ['bandage', 'tourniquet', 'gauze', 'splint', 'burncream', 'painkillers', 'morphine', 'saline', 'adrenaline', 'defibrillator', 'firstaid', 'ifaks'];

    let open = false;
    let data = null;
    let page = 'patient';
    let patient = null;
    let patientId = null;
    let pageTimer = null;
    let clockTimer = null;
    const view = { callFilter: 'open', callSel: null };

    function icon(name) {
        return `<svg class="tb-i" viewBox="0 0 24 24">${ICON[name] || ''}</svg>`;
    }

    async function call(name, ...args) {
        const res = await XS.rpc(`tablet:${name}`, { args });
        if (!res.ok && res.error) XS.toast(res.error, 'error');
        return res;
    }

    function tag(text, tone, attrs) {
        return `<span class="tb-tag${tone ? ` g-${tone}` : ''}"${attrs || ''}>${esc(text)}</span>`;
    }

    function btn(id, label, cls, opts) {
        const o = opts || {};
        return `<button class="tb-btn ${cls || ''}" data-act="${id}"${o.disabled ? ' disabled' : ''}${o.style ? ` style="${o.style}"` : ''}>${o.icon ? icon(o.icon) : ''}${esc(label)}</button>`;
    }

    function stat(label, value, tone, trend) {
        return `<div class="tb-st"><div class="l">${esc(label)}</div><div class="v ${tone || ''}">${esc(value)}</div><div class="t">${esc(trend || '')}</div></div>`;
    }

    function card(iconName, title, right, body, cls) {
        return `<div class="tb-card ${cls || ''}"><div class="tb-ch">${iconName ? icon(iconName) : ''}<span>${esc(title)}</span><span class="tb-ch-r">${right || ''}</span></div>${body}</div>`;
    }

    function empty(iconName, title, text) {
        return `<div class="tb-empty">${icon(iconName)}<b>${esc(title)}</b>${text ? `<span>${esc(text)}</span>` : ''}</div>`;
    }

    function header(sub, title, right) {
        return `<div class="tb-ph"><div class="tb-ph-l"><div class="tb-ph-sub">${sub}</div><div class="tb-ph-title">${title}</div></div><div class="tb-ph-r">${right || ''}</div></div>`;
    }

    function bind(el, acts) {
        el.querySelectorAll('[data-act]').forEach((node) => {
            const fn = acts[node.dataset.act];
            if (fn) node.addEventListener('click', () => { if (!node.disabled) fn(node); });
        });
    }

    function main() { return root.querySelector('#tb-main'); }

    function initials(name) {
        return String(name || '').split(/\s+/).filter(Boolean).slice(0, 2).map((w) => w[0]).join('').toUpperCase();
    }

    function span(seconds) {
        const s = Math.max(0, Math.floor(Number(seconds) || 0));
        if (s >= 3600) return `${Math.floor(s / 3600)}h ${String(Math.floor((s % 3600) / 60)).padStart(2, '0')}m`;
        return `${Math.floor(s / 60)}:${String(s % 60).padStart(2, '0')}`;
    }

    function toUnix(value) {
        if (typeof value === 'number') return value > 1e12 ? Math.floor(value / 1000) : value;
        const ms = Date.parse(String(value || ''));
        return Number.isNaN(ms) ? 0 : Math.floor(ms / 1000);
    }

    function since(ts) {
        return span(Date.now() / 1000 - Number(ts || 0));
    }

    function metres(m) {
        if (m === null || m === undefined || m === '') return '';
        const n = Number(m);
        return n >= 1000 ? `${(n / 1000).toFixed(1)} km` : `${Math.round(n)} m`;
    }

    function ageOf(dob) {
        if (!dob) return '';
        const s = String(dob);
        let year = null;
        let d = null;
        const iso = s.match(/^(\d{4})-(\d{1,2})-(\d{1,2})/);
        if (iso) d = new Date(Number(iso[1]), Number(iso[2]) - 1, Number(iso[3]));
        else {
            const other = s.match(/(\d{4})/);
            if (other) year = Number(other[1]);
        }
        const now = new Date();
        if (d && !Number.isNaN(d.getTime())) {
            let age = now.getFullYear() - d.getFullYear();
            if (now.getMonth() < d.getMonth() || (now.getMonth() === d.getMonth() && now.getDate() < d.getDate())) age -= 1;
            return age > 0 && age < 130 ? String(age) : '';
        }
        if (year) {
            const age = now.getFullYear() - year;
            return age > 0 && age < 130 ? String(age) : '';
        }
        return '';
    }

    function tick() {
        const c = root.querySelector('#tb-clock');
        const d = root.querySelector('#tb-date');
        if (!c || !d) return;
        const now = new Date();
        c.textContent = [now.getHours(), now.getMinutes(), now.getSeconds()].map((n) => String(n).padStart(2, '0')).join(':');
        d.textContent = now.toLocaleDateString(undefined, { weekday: 'long', month: 'short', day: 'numeric' });
        root.querySelectorAll('[data-since]').forEach((el) => {
            const secs = Date.now() / 1000 - Number(el.dataset.since);
            const label = el.querySelector('span');
            if (label) label.textContent = span(secs);
            if (el.classList.contains('cl-age') && el.dataset.p === '1') el.classList.toggle('crit', true);
            else if (el.classList.contains('cl-age')) el.classList.toggle('warn', secs > 300);
        });
    }

    function openCalls() {
        return XS.list(data.calls).filter((c) => c.status !== 'closed');
    }

    function bedTotals() {
        return XS.list(data.places).reduce((acc, p) => {
            acc.beds += Number(p.beds) || 0;
            acc.free += Number(p.free) || 0;
            acc.waiting += Number(p.waiting) || 0;
            return acc;
        }, { beds: 0, free: 0, waiting: 0 });
    }

    function nav() {
        const el = root.querySelector('#tb-nav');
        if (!el) return;
        const calls = openCalls().length;
        const beds = bedTotals();
        el.innerHTML = NAV.map(([group, all]) => [group, all.filter(on)]).filter(([, pages]) => pages.length).map(([group, pages]) => `<div class="tb-sec">${esc(t(`nav_${group}`, null, group))}</div>${pages.map((p) => {
            let badge = '';
            if (p === 'calls' && calls) badge = `<span class="tb-badge">${calls}</span>`;
            if (p === 'hospital' && beds.beds) badge = `<span class="tb-badge n">${beds.free}/${beds.beds}</span>`;
            return `<div class="tb-item${p === page ? ' on' : ''}" data-page="${p}">${icon(p)}<span>${esc(t(`tab_${p}`, null, p))}</span>${badge}</div>`;
        }).join('')}`).join('');
        el.querySelectorAll('[data-page]').forEach((n) => n.addEventListener('click', () => go(n.dataset.page)));
    }

    function shell() {
        const stage = XS.stage(root, 'tb-stage');
        const me = data.me || {};
        stage.innerHTML = `<div class="tb-dim"></div><div class="tb-win">
            <nav class="tb-rail">
                <div class="tb-logo"><span class="tb-hex"><svg viewBox="0 0 24 24">${ICON.cross}</svg></span><div><div class="tb-brand">${esc(t('tb_brand', null, 'XS-'))}<span>${esc(t('tb_brand_accent', null, 'Medical'))}</span></div><div class="tb-brand-sub">${esc(me.jobLabel || 'EMS')} · ${esc(t('tb_live', null, 'Live'))}</div></div></div>
                ${on('records') ? `<div class="tb-find">${icon('search')}<input id="tb-find" maxlength="40" placeholder="${esc(t('tb_find', null, 'Find a patient…'))}"></div>` : ''}
                <div class="tb-nav" id="tb-nav"></div>
                <div class="tb-clock"><b id="tb-clock"></b><span id="tb-date"></span></div>
                <div class="tb-me"><span class="tb-av">${esc(initials(me.name))}</span><div class="tb-me-info"><b>${esc(me.name || '')}</b><span>${esc([me.gradeLabel, me.callsign].filter(Boolean).join(' · '))}</span></div><span class="tb-dot ${me.onDuty === false ? 'off' : ''}"></span></div>
                <div class="tb-close" id="tb-close">${icon('close')}${esc(t('tb_close', null, 'Close tablet'))}</div>
            </nav>
            <main class="tb-main" id="tb-main"></main>
        </div>`;
        nav();
        stage.querySelector('#tb-close').addEventListener('click', () => XS.close('tablet'));
        const find = stage.querySelector('#tb-find');
        if (find) find.addEventListener('keydown', (e) => {
            if (e.key !== 'Enter') return;
            view.rcQuery = e.target.value.trim();
            view.rcOpen = null;
            go('records');
        });
        clearInterval(clockTimer);
        tick();
        clockTimer = setInterval(tick, 1000);
    }

    function go(next) {
        page = PAGES.includes(next) && on(next) ? next : 'patient';
        root.querySelectorAll('.tb-item').forEach((n) => n.classList.toggle('on', n.dataset.page === page));
        renderPage();
    }

    function renderPage() {
        clearInterval(pageTimer);
        pageTimer = null;
        if (page === 'patient') return pagePatient();
        if (page === 'calls') return pageCalls();
        if (page === 'records') return pageRecords();
        if (page === 'prescribe') return pagePrescribe();
        if (page === 'roster') return pageRoster();
        if (page === 'reports') return pageReports();
        if (page === 'hospital') return pageHospital();
        return null;
    }

    async function loadPatient(src) {
        patientId = src;
        const res = await call('patient', src);
        patient = res.ok ? res.data : null;
        return patient;
    }

    async function treat(supply, injury) {
        await XS.rpc('tablet:treat', { target: patientId, supply, injury });
    }

    function action(name) {
        XS.rpc('tablet:action', { target: patientId, action: name });
    }

    function pickPatient() {
        const near = XS.list(data.nearby);
        const rows = near.map((n) => `<div class="tb-row pk-r r-click" data-src="${Number(n.src)}"><span class="pk-dot" style="background:${SHADE[n.acuity] || SHADE[5]}"></span><b>${esc(n.name)}</b>${tag(t(`status_${n.status}`, null, n.status), n.status === 'alive' ? '' : 'red')}<span class="m">${esc(metres(n.dist))}</span></div>`).join('');
        main().innerHTML = header(esc(t('ph_patient', null, 'Patient care')), esc(t('pt_pick', null, 'Pick a patient')), btn('rescan', t('pt_rescan', null, 'Look again'), 'b-ghost', { icon: 'refresh' }))
            + `<div class="tb-body">${card('body', t('pt_nearby', null, 'People near you'), tag(t('pt_nearby_n', { n: near.length }, `${near.length} close`)),
                near.length ? `<div class="tb-scroll">${rows}</div>` : empty('body', t('pt_nobody_title', null, 'Nobody close enough'), t('pt_nobody', null, 'Walk up to your patient and look again.')))}</div>`;
        main().querySelectorAll('[data-src]').forEach((row) => row.addEventListener('click', async () => {
            await loadPatient(Number(row.dataset.src));
            if (page === 'patient') pagePatient();
        }));
        bind(main(), {
            rescan: async () => {
                const res = await call('nearby');
                if (res.ok) data.nearby = res.data;
                if (page === 'patient') pickPatient();
            },
        });
    }

    async function pagePatient() {
        if (!patientId) return pickPatient();
        if (!patient) await loadPatient(patientId);
        if (page !== 'patient') return null;
        if (!patient) {
            patientId = null;
            return pickPatient();
        }
        drawPatient();
        pageTimer = setInterval(async () => {
            if (!open || page !== 'patient' || !patientId) return;
            const res = await XS.rpc('tablet:patient', { args: [patientId] });
            if (res.ok && page === 'patient' && patientId) {
                patient = res.data;
                updatePatient();
            }
        }, 2500);
        return null;
    }

    function patientStats() {
        const s = patient.state || {};
        const v = s.vitals || {};
        const injuries = XS.list(s.injuries);
        const bleeding = injuries.filter((i) => i.bleed > 0).length;
        const todo = injuries.filter((i) => XS.needs(i).length > 0);
        const surgery = todo.filter((i) => i.surgery).length;
        const pain = v.pain !== null && v.pain !== undefined ? Number(v.pain) : null;
        const blood = s.blood !== null && s.blood !== undefined ? Number(s.blood) : 100;
        const visit = patient.visit;
        const firstLog = XS.list(patient.timeline)[0];
        const start = (visit && visit.since) || (firstLog && firstLog.t) || null;
        const avpu = v.avpu || '-';
        const temp = v.temp !== null && v.temp !== undefined ? Number(v.temp) : null;
        return [
            stat(t('st_pain', null, 'Pain'), pain === null ? '-' : `${pain}/10`, pain >= 7 ? 'r' : (pain >= 4 ? 'y' : ''), Number(s.relief) > 0 ? t('st_relief', null, 'Pain relief working') : (pain >= 4 ? t('st_needs_relief', null, 'Needs relief') : '')),
            stat(t('st_blood', null, 'Blood'), `${Math.round(blood)}%`, blood < 60 ? 'r' : (blood < 85 ? 'y' : ''), bleeding ? t('st_bleeding', { n: bleeding }, `${bleeding} bleeding`) : t('st_not_bleeding', null, 'Not bleeding')),
            stat('AVPU', avpu, avpu === 'U' ? 'r' : (avpu === 'P' ? 'y' : ''), t(`avpu_${String(avpu).toLowerCase()}`, null, '')),
            stat(t('st_wounds', null, 'To treat'), String(todo.length), todo.length ? (bleeding ? 'r' : 'y') : 'g', todo.length ? (surgery ? t('st_wounds_surgery', { n: surgery }, `${surgery} need surgery`) : t('st_wounds_left', null, 'Wounds left')) : t('st_wounds_none', null, 'Nothing left')),
            stat(t('st_temp', null, 'Temp'), temp === null ? '-' : temp.toFixed(1), temp !== null && (temp < 35 || temp > 38.5) ? 'y' : '', '°C'),
            start ? `<div class="tb-st"><div class="l">${esc(t('st_in_care', null, 'In care'))}</div><div class="v" data-since="${Number(start)}"><span>${esc(since(start))}</span></div><div class="t">${esc(t('st_since', { time: XS.time(start) }, `Since ${XS.time(start)}`))}</div></div>`
                : stat(t('st_in_care', null, 'In care'), '—', 'f', ''),
        ].join('');
    }

    function injuryRows() {
        const injuries = XS.list((patient.state || {}).injuries);
        if (!injuries.length) return empty('wound', t('pt_no_injuries', null, 'No injuries found'), t('pt_no_injuries_hint', null, 'Nothing to treat right now.'));
        return injuries.map((i) => {
            const needs = XS.needs(i);
            const chips = needs.map((k) => {
                if (k === 'surgery') return tag(t('need_surgery', null, 'Needs surgery'), 'purple');
                if (k === 'antibiotics') return tag(t('need_antibiotics', null, 'Needs antibiotics'), 'yellow');
                const tone = k === 'tourniquet' ? 'red' : (k === 'splint' ? 'yellow' : 'blue');
                return `<span class="tb-tag t-act g-${tone}" data-treat="${k}" data-inj="${Number(i.id)}">${esc(t(`supply_${k}`, null, k))}</span>`;
            }).join('');
            const rest = XS.describe(i).split(' · ').slice(1).join(' · ');
            return `<div class="tb-row ij-r"><div class="ij-part"><i style="background:${XS.Figure.tone(i)}"></i>${esc(XS.part(i.part))}</div><div><b>${esc(XS.kind(i.kind))}</b><span class="s">${esc(rest || t('pt_no_detail', null, 'No bleeding'))}</span></div><div class="ij-acts">${chips || tag(t('need_ok', null, 'OK'), 'green')}</div></div>`;
        }).join('');
    }

    function timelineRows() {
        const list = XS.list(patient.timeline).slice(-14).reverse();
        if (!list.length) return empty('log', t('pt_no_timeline', null, 'Nothing logged yet'), '');
        return list.map((e) => `<div class="tb-row tl-r"><span class="m">${esc(XS.time(e.t))}</span><div><span class="d" style="color:var(--x-text)">${esc(e.text)}</span><em>${esc(e.by || '')}</em></div></div>`).join('');
    }

    function drawPatient() {
        const p = patient;
        const s = p.state || {};
        const v = s.vitals || {};
        const injuries = XS.list(s.injuries);
        const rec = p.record || null;
        const visit = p.visit || null;
        const status = s.status;
        const sub = [t('ph_patient', null, 'Patient care'), visit && visit.room, visit ? t(`visit_${visit.status}`, null, visit.status) : null, !p.near ? t('pt_far', { m: p.dist }, `${p.dist} m away`) : null].filter(Boolean).map((x) => esc(x)).join(' · ');
        const who = [p.female ? t('pt_female', null, 'F') : t('pt_male', null, 'M'), ageOf(rec && rec.dob)].filter(Boolean).join(' · ');
        const tags = [
            tag(who),
            rec && rec.blood ? tag(rec.blood) : '',
            rec && rec.allergies ? tag(t('pt_allergy_tag', { what: rec.allergies }, `Allergy · ${rec.allergies}`), 'red') : '',
            !p.identified ? tag(t('pt_no_id', null, 'No ID yet'), 'blue') : '',
            v.acuity && v.acuity < 5 ? tag(t(`triage_${v.acuity}`, null, ''), TONE[v.acuity]) : '',
        ].join('');
        const near = XS.list(data.nearby);
        const picker = `<select class="tb-input" id="pt-near" style="width:230px"><option value="">${esc(t('pt_switch', null, 'Switch patient…'))}</option>${near.map((n) => `<option value="${Number(n.src)}" ${n.src === patientId ? 'selected' : ''}>${esc(n.name)} · ${esc(metres(n.dist))}</option>`).join('')}</select>`;
        const bleeding = injuries.filter((i) => i.bleed > 0).length;
        const tools = [
            btn('treat', t('act_treat', null, 'Treat'), 'b-go', { icon: 'cross' }),
            btn('stretcher', t('act_stretcher', null, 'Stretcher')),
            btn('bed', t('act_bed', null, 'To bed')),
            btn('surgery', t('act_surgery', null, 'Surgery'), 'b-purple', { disabled: !data.can.surgery || !injuries.some((i) => i.surgery) }),
            '<span class="tb-sep"></span>',
            !p.identified ? btn('checkid', t('act_checkid', null, 'Check ID'), 'b-blue') : '',
            status === 'arrest' ? btn('cpr', t('act_cpr', null, 'CPR'), 'b-red') : '',
            on('prescribe') ? btn('prescribe', t('act_prescribe', null, 'Prescribe'), '', { disabled: !data.can.prescribe || !p.identified }) : '',
            btn('bill', t('act_bill', null, 'Bill')),
            visit && status === 'alive' ? btn('discharge', t('act_discharge', null, 'Discharge'), '', { disabled: injuries.some((i) => XS.needs(i).length > 0) }) : '',
            `<span class="tb-push"></span>${on('reports') ? btn('report', t('act_report', null, 'Write report'), '', { icon: 'reports' }) : ''}`,
        ].join('');
        main().innerHTML = header(sub, `<span>${esc(p.name)}</span>${tags}`, picker)
            + `<div class="tb-tools">${tools}</div>
            <div class="tb-body">
                <div class="tb-stats" id="pt-stats">${patientStats()}</div>
                <div class="pt-grid">
                    ${card('patient', t('pt_monitor', null, 'Monitor'), tag(t('pt_live', null, 'Live'), 'green'), `<div class="tb-cb" style="padding:10px"><div class="pt-mon">
                        <div class="pt-waves"><span class="pt-lbl" style="top:10px;color:#3dff7a">II</span><span id="pt-alarm"></span><canvas id="pt-ecg" height="112" style="top:22px;height:112px"></canvas><span class="pt-lbl" style="top:142px;color:#36d8ff">PLETH</span><canvas id="pt-pleth" height="70" style="top:154px;height:70px"></canvas></div>
                        <div class="pt-nums">
                            <div class="pt-num" data-v="hr" style="color:#3dff7a"><small>HR</small><b>--</b><em></em></div>
                            <div class="pt-num" data-v="bp" style="color:#ff5a5a"><small>NIBP</small><b class="sm">--/--</b><em></em></div>
                            <div class="pt-num" data-v="spo2" style="color:#36d8ff"><small>SpO2</small><b>--</b><em>%</em></div>
                            <div class="pt-num" data-v="resp" style="color:#ffe14a"><small>RESP</small><b>--</b><em>/min</em></div>
                        </div></div></div>`)}
                    ${card('body', t('pt_body', null, 'Body'), tag(t('pt_front', null, 'Front')), `<div class="pt-fig" id="pt-fig">${XS.Figure.body(injuries)}</div><div class="pt-legend"><span><i style="background:#ff4d5e"></i>${esc(t('pt_lg_bleeding', null, 'Bleeding'))}</span><span><i style="background:#ffb020"></i>${esc(t('pt_lg_broken', null, 'Broken'))}</span><span><i style="background:#a88bff"></i>${esc(t('pt_lg_surgery', null, 'Surgery'))}</span></div>`)}
                    ${card('wound', t('pt_injuries', null, 'Injuries'), `<span id="pt-inj-tags">${bleeding ? tag(t('pt_bleeding_n', { n: bleeding }, `${bleeding} bleeding`), 'red') : ''}${tag(t('pt_total_n', { n: injuries.length }, `${injuries.length} total`))}</span>`, `<div class="tb-scroll" id="pt-inj">${injuryRows()}</div>`)}
                    ${card('log', t('pt_timeline', null, 'Timeline'), tag(t('pt_today', null, 'Today')), `<div class="tb-scroll" id="pt-tl">${timelineRows()}</div>`)}
                </div>
            </div>`;
        const el = main();
        const vitals = () => (patient && patient.state && patient.state.vitals) || {};
        const rhythm = () => {
            const vv = vitals();
            if (vv.status === 'arrest') return vv.rhythm === 'vf' ? 'vf' : 'asystole';
            if (vv.status === 'dead') return 'asystole';
            return 'sinus';
        };
        const hr = () => { const vv = vitals(); return (vv.status === 'arrest' || vv.status === 'dead') ? 0 : (vv.hr || 0); };
        XS.Wave.attach(el.querySelector('#pt-ecg'), { kind: 'ecg', color: '#3dff7a', hr, rhythm, width: 2 });
        XS.Wave.attach(el.querySelector('#pt-pleth'), { kind: 'pleth', color: '#36d8ff', hr, rhythm, amp: 0.7, width: 2 });
        el.querySelector('#pt-near').addEventListener('change', async (e) => {
            if (!e.target.value) return;
            patient = null;
            await loadPatient(Number(e.target.value));
            if (page === 'patient') pagePatient();
        });
        bindInjuries();
        bind(el, {
            treat: () => treatMenu(),
            stretcher: () => action('stretcher'),
            bed: () => action('bed'),
            surgery: () => action('surgery'),
            checkid: () => action('checkid'),
            cpr: () => action('cpr'),
            prescribe: () => { view.rxFor = { cid: p.cid, name: p.realName || p.name }; go('prescribe'); },
            bill: () => action('bill'),
            discharge: async () => {
                const r = await call('discharge', patientId);
                if (r.ok) {
                    XS.toast(t('discharged', null, 'Discharged and fully healed.'), 'ok');
                    patient = null;
                    patientId = null;
                    pagePatient();
                }
            },
            report: () => { view.reportFrom = patient; go('reports'); },
        });
        updateVitals();
    }

    function bindInjuries() {
        main().querySelectorAll('[data-treat]').forEach((b) => b.addEventListener('click', () => treat(b.dataset.treat, Number(b.dataset.inj))));
    }

    function updateVitals() {
        const el = main();
        if (!el || !patient) return;
        const v = (patient.state && patient.state.vitals) || {};
        const dead = v.status === 'arrest' || v.status === 'dead';
        const alarms = XS.list(v.alarms);
        const cell = (key) => el.querySelector(`.pt-num[data-v="${key}"]`);
        const set = (key, value, sub, alarm) => {
            const c = cell(key);
            if (!c) return;
            c.querySelector('b').textContent = value;
            if (sub !== null) c.querySelector('em').textContent = sub;
            c.classList.toggle('al', !!alarm);
        };
        const sys = Number(v.sys) || 0;
        const dia = Number(v.dia) || 0;
        set('hr', dead ? '0' : String(v.hr || '--'), t(`rhythm_${v.rhythm || 'sinus'}`, null, ''), alarms.some((a) => a === 'hr_high' || a === 'hr_low' || a === 'arrest'));
        set('bp', dead ? '--/--' : `${v.sys || '--'}/${v.dia || '--'}`, !dead && sys ? t('pt_map', { n: Math.round((sys + 2 * dia) / 3) }, `MAP ${Math.round((sys + 2 * dia) / 3)}`) : '', alarms.includes('bp'));
        set('spo2', dead ? '--' : String(v.spo2 || '--'), null, alarms.includes('spo2'));
        set('resp', dead ? '0' : String(v.resp || '--'), null, alarms.includes('resp'));
        const alarm = el.querySelector('#pt-alarm');
        if (alarm) alarm.innerHTML = alarms.length ? `<span class="pt-alarm ${dead ? 'tb-blink' : ''}">${esc(t(`alarm_${alarms[0]}`, null, alarms[0]))}</span>` : '';
    }

    function updatePatient() {
        const el = main();
        if (!el || !patient) return;
        const injuries = XS.list((patient.state || {}).injuries);
        const bleeding = injuries.filter((i) => i.bleed > 0).length;
        const stats = el.querySelector('#pt-stats');
        if (stats) stats.innerHTML = patientStats();
        const fig = el.querySelector('#pt-fig');
        if (fig) fig.innerHTML = XS.Figure.body(injuries);
        const inj = el.querySelector('#pt-inj');
        if (inj) inj.innerHTML = injuryRows();
        const tags = el.querySelector('#pt-inj-tags');
        if (tags) tags.innerHTML = `${bleeding ? tag(t('pt_bleeding_n', { n: bleeding }, `${bleeding} bleeding`), 'red') : ''}${tag(t('pt_total_n', { n: injuries.length }, `${injuries.length} total`))}`;
        const tl = el.querySelector('#pt-tl');
        if (tl) tl.innerHTML = timelineRows();
        bindInjuries();
        updateVitals();
    }

    function treatMenu() {
        const keys = TREAT_KEYS.filter((k) => (data.supplies || {})[k]);
        const overlay = document.createElement('div');
        overlay.className = 'tb-over';
        overlay.innerHTML = `<div class="tb-modal">
            <div class="tb-ch">${icon('cross')}<span>${esc(t('treat_menu_title', null, 'Treat'))}</span><span class="tb-ch-r">${tag(patient ? patient.name : '')}</span></div>
            <div class="tb-scroll">${keys.map((k) => `<div class="tb-row r-click" data-k="${k}"><div><b>${esc(t(`supply_${k}`, null, k))}</b><span class="s">${esc(t(`supply_hint_${k}`, null, ''))}</span></div></div>`).join('')}</div>
            <div class="tb-modal-foot">${btn('shut', t('close', null, 'Close'), 'b-ghost')}</div>
        </div>`;
        main().appendChild(overlay);
        overlay.addEventListener('click', (e) => { if (e.target === overlay) overlay.remove(); });
        bind(overlay, { shut: () => overlay.remove() });
        overlay.querySelectorAll('[data-k]').forEach((row) => row.addEventListener('click', () => { overlay.remove(); treat(row.dataset.k, null); }));
    }

    function unitName(u) {
        const known = XS.list(data.units).find((x) => x.src === u.src);
        const last = String(u.name || '').split(/\s+/).filter(Boolean).pop() || '';
        return known && known.callsign ? `${known.callsign} ${last}` : (u.name || '');
    }

    function callsFiltered() {
        const meSrc = (data.me || {}).src;
        const all = openCalls();
        if (view.callFilter === 'mine') return all.filter((c) => XS.list(c.units).some((u) => u.src === meSrc));
        return all;
    }

    async function pageCalls() {
        drawCalls();
        const [res, shift] = await Promise.all([call('calls'), call('shift')]);
        if (page !== 'calls' || !open) return;
        if (res.ok) data.calls = XS.list(res.data);
        if (shift.ok) {
            data.units = XS.list(shift.data.units);
            data.places = XS.list(shift.data.places);
        }
        nav();
        drawCalls();
    }

    function drawCalls() {
        const el = main();
        if (!el) return;
        const meSrc = (data.me || {}).src;
        const all = openCalls();
        const list = callsFiltered();
        if (!list.some((c) => c.id === view.callSel)) view.callSel = list.length ? list[0].id : null;
        const sel = list.find((c) => c.id === view.callSel) || null;
        const mine = all.filter((c) => XS.list(c.units).some((u) => u.src === meSrc)).length;
        const p1 = all.filter((c) => Number(c.priority) === 1);
        const oldestP1 = p1.reduce((m, c) => Math.min(m, Number(c.createdAt) || m), Infinity);
        const units = XS.list(data.units);
        const onDuty = units.filter((u) => u.onDuty);
        const free = onDuty.filter((u) => !u.call).length;
        const beds = bedTotals();
        const unassigned = all.filter((c) => !XS.list(c.units).length).length;
        const seg = `<div class="cl-seg"><span data-filter="open" class="${view.callFilter === 'open' ? 'on' : ''}">${esc(t('cl_open', null, 'Open'))} <em>${all.length}</em></span><span data-filter="mine" class="${view.callFilter === 'mine' ? 'on' : ''}">${esc(t('cl_mine', null, 'Mine'))} <em>${mine}</em></span></div>`;
        const stats = [
            stat(t('cl_st_open', null, 'Open calls'), String(all.length), '', unassigned ? t('cl_st_unassigned', { n: unassigned }, `${unassigned} with nobody on them`) : t('cl_st_covered', null, 'All covered')),
            p1.length ? `<div class="tb-st"><div class="l">${esc(t('cl_st_p1', null, 'Priority 1'))}</div><div class="v r">${p1.length}</div><div class="t" data-since="${oldestP1}">${esc(t('cl_st_waiting', null, 'Waiting'))} <span>${esc(since(oldestP1))}</span></div></div>`
                : stat(t('cl_st_p1', null, 'Priority 1'), '0', '', t('cl_st_p1_none', null, 'None open')),
            stat(t('cl_st_medics', null, 'Medics on duty'), String(onDuty.length), '', t('cl_st_free', { n: free }, `${free} free right now`)),
            stat(t('cl_st_beds', null, 'Beds free'), beds.beds ? `${beds.free}/${beds.beds}` : '—', beds.beds && !beds.free ? 'r' : '', XS.list(data.places).length === 1 ? XS.list(data.places)[0].name : t('cl_st_hospitals', { n: XS.list(data.places).length }, `${XS.list(data.places).length} hospitals`)),
            stat(t('cl_st_waiting_room', null, 'Waiting room'), String(beds.waiting), beds.waiting ? 'y' : '', beds.waiting ? t('cl_st_checked_in', null, 'Checked in') : t('cl_st_nobody', null, 'Nobody waiting')),
        ].join('');
        const items = list.map((c) => {
            const cu = XS.list(c.units);
            const unitTags = cu.length ? cu.map((u) => tag(unitName(u), 'blue')).join('') : tag(Number(c.priority) === 1 ? t('cl_no_units', null, 'No units') : t('cl_unassigned', null, 'Unassigned'), Number(c.priority) === 1 ? 'red' : '');
            const loc = [c.street, metres(c.dist), c.description].filter(Boolean).join(' · ');
            const age = Date.now() / 1000 - Number(c.createdAt);
            const tone = Number(c.priority) === 1 ? 'crit' : (age > 300 ? 'warn' : '');
            return `<div class="cl-item ${c.id === view.callSel ? 'on' : ''}" data-id="${Number(c.id)}">
                <div class="cl-top"><span class="cl-no">#${Number(c.id)}</span><span class="cl-pri p${Number(c.priority)}">P${Number(c.priority)}</span><span class="cl-origin">${esc(c.code || '')}</span><span class="cl-age ${tone}" data-since="${Number(c.createdAt)}" data-p="${Number(c.priority)}">${icon('clock')}<span>${esc(since(c.createdAt))}</span></span></div>
                <div class="cl-type">${esc(c.title)}</div>
                <div class="cl-loc">${icon('pin')}<span>${esc(loc)}</span></div>
                <div class="cl-units">${unitTags}</div>
            </div>`;
        }).join('');
        let detail = card('calls', t('cl_detail', null, 'Call'), '', empty('calls', t('cl_none_title', null, 'No call picked'), t('cl_none_pick', null, 'Pick a call on the left.')));
        if (sel) {
            const cu = XS.list(sel.units);
            const isMine = cu.some((u) => u.src === meSrc);
            const rows = [
                [t('cl_k_code', null, 'Code'), sel.code || '-', ''],
                [t('cl_k_location', null, 'Location'), sel.street || '-', ''],
                [t('cl_k_distance', null, 'Distance'), metres(sel.dist) || '-', ''],
                [t('cl_k_condition', null, 'Condition'), sel.description || '-', Number(sel.priority) === 1 ? 'r' : ''],
                [t('cl_k_caller', null, 'Caller'), sel.caller || '-', ''],
                [t('cl_k_units', null, 'Units'), cu.length ? cu.map((u) => unitName(u)).join(', ') : t('cl_none_yet', null, 'None yet'), ''],
                [t('cl_k_time', null, 'Called in'), XS.time(sel.createdAt), ''],
            ].map(([k, v, tone]) => `<div class="tb-info"><span class="k">${esc(k)}</span><span class="v ${tone}">${esc(v)}</span></div>`).join('');
            detail = `<div class="tb-card"><div class="tb-ch"><span class="cl-no">#${Number(sel.id)}</span><span>${esc(sel.title)}</span><span class="tb-ch-r"><span class="cl-pri p${Number(sel.priority)}">P${Number(sel.priority)}</span></span></div>
                <div class="tb-cb" style="padding:4px 14px">${rows}</div>
                <div class="cl-acts">${isMine ? btn('leave', t('calls_leave', null, 'Leave'), 'b-wide') : btn('take', t('calls_take', null, 'Respond'), 'b-go b-wide')}${btn('gps', t('calls_gps', null, 'GPS'), '', { icon: 'gps' })}${btn('shut', t('calls_close', null, 'Close'), 'b-red')}</div></div>`;
        }
        const unitRows = units.map((u) => {
            const colour = !u.onDuty ? '#5c6674' : (u.call ? 'var(--x-blue)' : 'var(--x-green)');
            const state = !u.onDuty ? tag(t('ro_off', null, 'Off duty')) : (u.call ? tag(t('cl_on_call', { id: u.call }, `On #${u.call}`), 'blue') : tag(t('cl_free', null, 'Free'), 'green'));
            return `<div class="tb-row un-r"><span class="un-dot" style="background:${colour}"></span><span class="cs">${esc(u.callsign || '—')}</span><b style="${u.onDuty ? '' : 'color:var(--x-dim);font-weight:500'}">${esc(u.name)}</b>${state}</div>`;
        }).join('');
        el.innerHTML = header(esc(t('ph_dispatch', null, 'Dispatch · Live')), esc(t('tab_calls', null, 'Calls')), `${seg}${btn('refresh', t('refresh', null, 'Refresh'), 'b-ghost', { icon: 'refresh' })}`)
            + `<div class="tb-body" style="padding-top:16px">
                <div class="tb-stats">${stats}</div>
                <div class="cl-grid">
                    ${card('calls', t('cl_queue', null, 'Call queue'), tag(t('cl_newest', null, 'Priority first')), list.length ? `<div class="tb-scroll">${items}</div>` : empty('calls', t('cl_quiet', null, 'No open calls'), view.callFilter === 'mine' ? t('cl_quiet_mine', null, 'You are not on any call.') : t('calls_none', null, 'Quiet shift.')))}
                    <div class="cl-side">${detail}${card('roster', t('cl_units', null, 'Units'), tag(t('cl_on_duty_n', { n: onDuty.length }, `${onDuty.length} on duty`), 'green'), units.length ? `<div class="tb-scroll">${unitRows}</div>` : empty('roster', t('ro_nobody', null, 'Nobody online'), ''), 'c-fill')}</div>
                </div>
            </div>`;
        el.querySelectorAll('[data-filter]').forEach((s) => s.addEventListener('click', () => { view.callFilter = s.dataset.filter; drawCalls(); }));
        el.querySelectorAll('.cl-item[data-id]').forEach((row) => row.addEventListener('click', () => { view.callSel = Number(row.dataset.id); drawCalls(); }));
        bind(el, {
            refresh: () => pageCalls(),
            take: async () => {
                const r = await XS.rpc('tablet:callTake', { id: sel.id });
                if (r.ok) XS.toast(t('calls_taken', null, 'On your way. GPS set.'), 'ok'); else XS.toast(r.error, 'error');
                pageCalls();
            },
            leave: async () => { await call('callLeave', sel.id); pageCalls(); },
            shut: async () => { await call('callClose', sel.id); pageCalls(); },
            gps: () => { if (sel && sel.coords) XS.rpc('tablet:waypoint', sel.coords).then(() => XS.toast(t('calls_gps_set', null, 'GPS set.'), 'ok')); },
        });
    }

    async function pageRecords() {
        const el = main();
        el.innerHTML = header(esc(t('ph_records', null, 'Records')), esc(t('tab_records', null, 'Patient records')),
            `<input class="tb-input" id="rc-q" style="width:260px" maxlength="40" placeholder="${esc(t('rc_search', null, 'Search name or citizen ID'))}" value="${esc(view.rcQuery || '')}">${btn('search', t('search', null, 'Search'), 'b-go', { icon: 'search' })}`)
            + `<div class="tb-body"><div class="rc-grid">
                ${card('records', t('rc_results', null, 'Results'), '', `<div class="tb-scroll" id="rc-list">${empty('search', t('rc_start', null, 'Search for someone'), t('rc_start_hint', null, 'Type a name or citizen ID.'))}</div>`)}
                <div class="tb-card" id="rc-view">${empty('records', t('rc_pick', null, 'No record open'), t('rc_pick_hint', null, 'Open someone from the results.'))}</div>
            </div></div>`;
        const run = async () => {
            view.rcQuery = el.querySelector('#rc-q').value.trim();
            const res = await call('recordsSearch', view.rcQuery);
            if (page !== 'records') return;
            const list = res.ok ? XS.list(res.data) : [];
            const box = el.querySelector('#rc-list');
            box.innerHTML = list.length ? list.map((r) => `<div class="tb-row rc-r r-click ${r.cid === view.rcOpen ? 'on' : ''}" data-cid="${esc(r.cid)}"><div><b>${esc(r.name)}</b><span class="s">${esc(r.cid)}${r.dob ? ` · ${esc(r.dob)}` : ''}</span></div>${icon('records')}</div>`).join('')
                : empty('search', t('rc_none', null, 'No matches'), t('rc_none_hint', null, 'Try part of the name.'));
            box.querySelectorAll('[data-cid]').forEach((row) => row.addEventListener('click', () => {
                box.querySelectorAll('.tb-row').forEach((r) => r.classList.toggle('on', r === row));
                openRecord(row.dataset.cid);
            }));
        };
        bind(el, { search: run });
        el.querySelector('#rc-q').addEventListener('keydown', (e) => { if (e.key === 'Enter') run(); });
        if (view.rcQuery) run();
        if (view.rcOpen) openRecord(view.rcOpen);
    }

    async function openRecord(cid) {
        view.rcOpen = cid;
        const res = await call('recordsOpen', cid);
        if (!res.ok || page !== 'records') return;
        const r = res.data;
        const can = !!data.can.editRecords;
        const box = main().querySelector('#rc-view');
        if (!box) return;
        const rx = XS.list(r.prescriptions).map((x) => `<div class="tb-row rc-hs"><span class="m">${esc(XS.date(x.createdAt))}</span>${tag(t(`rx_${x.status}`, null, x.status), x.status === 'active' ? 'green' : '')}<span class="d">${esc(x.label)} ${esc(x.dose)} · ${esc(x.prescriber)}</span><span class="m">×${esc(x.qty)} +${esc(x.refills)}</span></div>`).join('');
        const history = XS.list(r.history).map((h) => `<div class="tb-row rc-hs"><span class="m">${esc(XS.date(h.created_at))}</span>${tag(t(`hist_${h.kind}`, null, h.kind))}<span class="d">${esc(h.summary)}</span><span class="m">${esc(h.medic_name || '')}</span></div>`).join('');
        const reports = XS.list(r.reports).map((x) => `<div class="tb-row rc-hs r-click" data-rep="${Number(x.id)}"><span class="m">${esc(stamp(x.incidentAt || toUnix(x.created_at)))}</span>${tag(t(`rp_out_${x.outcome || 'scene'}`, null, x.outcome || ''), OUTCOME_TONE[x.outcome])}<span class="d">${esc(x.title)}</span><span class="m">${esc(x.author_name)}</span></div>`).join('');
        box.innerHTML = `<div class="tb-ch">${icon('records')}<span>${esc(r.name)}</span><span class="tb-ch-r">${tag(r.cid)}${r.dob ? tag(t('rc_born', { dob: r.dob }, `Born ${r.dob}`)) : ''}</span></div>
            <div class="tb-scroll"><div class="tb-cb">
                <div class="rc-fields">
                    <div><label class="tb-label">${esc(t('rc_blood', null, 'Blood'))}</label><input class="tb-input" id="rc-blood" maxlength="3" value="${esc(r.blood)}" ${can ? '' : 'disabled'}></div>
                    <div><label class="tb-label">${esc(t('rc_dob', null, 'Born'))}</label><input class="tb-input" value="${esc(r.dob || '—')}" disabled></div>
                    <div><label class="tb-label">${esc(t('rc_allergies', null, 'Allergies'))}</label><textarea class="tb-input" id="rc-all" rows="3" ${can ? '' : 'disabled'}>${esc(r.allergies)}</textarea></div>
                    <div><label class="tb-label">${esc(t('rc_conditions', null, 'Conditions'))}</label><textarea class="tb-input" id="rc-con" rows="3" ${can ? '' : 'disabled'}>${esc(r.conditions)}</textarea></div>
                    <div class="f-wide"><label class="tb-label">${esc(t('rc_notes', null, 'Notes'))}</label><textarea class="tb-input" id="rc-notes" rows="3" ${can ? '' : 'disabled'}>${esc(r.notes)}</textarea></div>
                </div>
                ${can || (data.can.prescribe && on('prescribe')) ? `<div style="display:flex;gap:8px;margin-top:12px">${can ? btn('save', t('save', null, 'Save'), 'b-go') : ''}${data.can.prescribe && on('prescribe') ? btn('rx', t('act_prescribe', null, 'Prescribe'), '', { icon: 'prescribe' }) : ''}</div>` : ''}
            </div>
            ${on('prescribe') ? `<div class="tb-ch" style="border-top:1px solid var(--x-soft)">${icon('prescribe')}<span>${esc(t('rc_rx', null, 'Prescriptions'))}</span></div>
            ${rx || `<div class="tb-row"><span class="m">${esc(t('rc_none_yet', null, 'None yet'))}</span></div>`}` : ''}
            <div class="tb-ch" style="border-top:1px solid var(--x-soft)">${icon('log')}<span>${esc(t('rc_history', null, 'History'))}</span></div>
            ${history || `<div class="tb-row"><span class="m">${esc(t('rc_none_yet', null, 'None yet'))}</span></div>`}
            ${on('reports') ? `<div class="tb-ch" style="border-top:1px solid var(--x-soft)">${icon('reports')}<span>${esc(t('tab_reports', null, 'Care reports'))}</span></div>
            ${reports || `<div class="tb-row"><span class="m">${esc(t('rc_none_yet', null, 'None yet'))}</span></div>`}` : ''}
            </div>`;
        box.querySelectorAll('[data-rep]').forEach((row) => row.addEventListener('click', () => { view.reportOpen = Number(row.dataset.rep); go('reports'); }));
        bind(box, {
            save: async () => {
                const res2 = await call('recordsSave', cid, { blood: box.querySelector('#rc-blood').value, allergies: box.querySelector('#rc-all').value, conditions: box.querySelector('#rc-con').value, notes: box.querySelector('#rc-notes').value });
                if (res2.ok) XS.toast(t('saved', null, 'Saved.'), 'ok');
            },
            rx: () => { view.rxFor = { cid: r.cid, name: r.name }; go('prescribe'); },
        });
    }

    async function pagePrescribe() {
        const meds = XS.list(data.medicines);
        const who = view.rxFor;
        const el = main();
        const ready = !!(who && who.cid && data.can.prescribe);
        el.innerHTML = header(esc(t('ph_records', null, 'Records')), esc(t('tab_prescribe', null, 'Prescriptions')), who ? tag(who.name, 'green') : tag(t('rx_nobody', null, 'No patient picked')))
            + `<div class="tb-body"><div class="rc-grid" style="grid-template-columns:420px minmax(0,1fr)">
                ${card('prescribe', t('rx_new', null, 'New prescription'), '', `<div class="tb-cb">
                    <div class="tb-info" style="margin-bottom:10px"><span class="k">${esc(t('ph_patient_k', null, 'Patient'))}</span><span class="v">${esc(who ? who.name : t('rx_pick_patient', null, 'Open a record or a patient first'))}</span></div>
                    <div class="tb-form">
                        <div class="f-wide"><label class="tb-label">${esc(t('rx_medicine', null, 'Medicine'))}</label><select class="tb-input" id="rx-med">${meds.map((m) => `<option value="${esc(m.item)}">${esc(m.label)} · ${esc(m.dose)}</option>`).join('')}</select></div>
                        <div class="f-wide"><label class="tb-label">${esc(t('rx_dose', null, 'Dose'))}</label><input class="tb-input" id="rx-dose" maxlength="40" placeholder="${esc(meds[0] ? meds[0].dose : '')}"></div>
                        <div><label class="tb-label">${esc(t('rx_qty', null, 'Quantity'))}</label><input class="tb-input" id="rx-qty" type="number" min="1" max="30" value="10"></div>
                        <div><label class="tb-label">${esc(t('rx_refills', null, 'Refills'))}</label><input class="tb-input" id="rx-ref" type="number" min="0" max="5" value="0"></div>
                        <div class="f-wide"><label class="tb-label">${esc(t('rx_notes', null, 'Notes for the pharmacist'))}</label><input class="tb-input" id="rx-notes" maxlength="120"></div>
                    </div>
                    <div style="margin-top:14px">${btn('write', t('rx_write', null, 'Write prescription'), 'b-go b-wide', { disabled: !ready })}</div>
                </div>`)}
                ${card('log', t('rx_on_file', null, 'On file'), '', `<div class="tb-scroll" id="rx-list">${empty('prescribe', t('rx_list_empty', null, 'Nothing to show'), who ? '' : t('rx_pick_patient', null, 'Open a record or a patient first'))}</div>`)}
            </div></div>`;
        bind(el, {
            write: async () => {
                if (!ready) return;
                const res = await call('rxCreate', who.cid, {
                    item: el.querySelector('#rx-med').value, dose: el.querySelector('#rx-dose').value, qty: Number(el.querySelector('#rx-qty').value),
                    refills: Number(el.querySelector('#rx-ref').value), notes: el.querySelector('#rx-notes').value,
                });
                if (res.ok) {
                    XS.toast(t('rx_written', null, 'Prescription sent to the pharmacy.'), 'ok');
                    pagePrescribe();
                }
            },
        });
        if (!who || !who.cid) return;
        const res = await call('recordsOpen', who.cid);
        if (page !== 'prescribe' || !res.ok) return;
        const list = XS.list(res.data.prescriptions);
        const box = el.querySelector('#rx-list');
        if (!box) return;
        box.innerHTML = list.length ? list.map((x) => `<div class="tb-row rx-r"><div><b>${esc(x.label)} ${esc(x.dose)}</b><span class="s">×${esc(x.qty)} +${esc(x.refills)} · ${esc(x.prescriber)} · ${esc(XS.date(x.createdAt))}</span></div>${tag(t(`rx_${x.status}`, null, x.status), x.status === 'active' ? 'green' : '')}${x.status === 'active' && data.can.prescribe ? `<button class="tb-btn b-red b-sm" data-void="${Number(x.id)}">${esc(t('rx_void', null, 'Void'))}</button>` : '<span></span>'}</div>`).join('')
            : empty('prescribe', t('rc_none_yet', null, 'None yet'), '');
        box.querySelectorAll('[data-void]').forEach((b) => b.addEventListener('click', async () => { await call('rxVoid', Number(b.dataset.void)); pagePrescribe(); }));
    }

    async function pageRoster() {
        const el = main();
        el.innerHTML = header(esc(t('ph_staff', null, 'Staff')), esc(t('tab_roster', null, 'Roster')), '') + `<div class="tb-body">${empty('roster', t('loading', null, 'Loading…'), '')}</div>`;
        const res = await call('roster');
        if (page !== 'roster' || !res.ok) return;
        const r = res.data;
        const grades = XS.list(r.grades);
        const gradeOpts = (sel) => grades.map((g) => `<option value="${Number(g.level)}" ${Number(sel) === Number(g.level) ? 'selected' : ''}>${esc(g.label)}</option>`).join('');
        const online = XS.list(r.online);
        const onDuty = online.filter((m) => m.onDuty).length;
        const me = data.me || {};
        const stats = [
            stat(t('ro_st_on', null, 'On duty'), String(onDuty), onDuty ? 'g' : '', t('ro_st_on_hint', null, 'Taking calls')),
            stat(t('ro_st_online', null, 'Online'), String(online.length), '', t('ro_st_off', { n: online.length - onDuty }, `${online.length - onDuty} off duty`)),
            r.canManage ? stat(t('ro_st_staff', null, 'On the books'), String(XS.list(r.staff).length), '', t('ro_st_staff_hint', null, 'Everyone hired')) : '',
            r.canManage ? stat(t('ro_st_account', null, 'Account'), `$${Number(r.balance || 0).toLocaleString()}`, '', t('ro_st_account_hint', null, 'Society balance')) : '',
        ].join('');
        const onlineRows = online.map((m) => `<div class="tb-row ro-r"><span class="un-dot" style="background:${m.onDuty ? 'var(--x-green)' : '#5c6674'}"></span><b>${esc(m.name)}</b><span class="m">${esc(m.callsign || '—')}</span><span class="d">${esc(m.gradeLabel || m.grade)}</span>${tag(m.onDuty ? t('ro_on', null, 'On duty') : t('ro_off', null, 'Off duty'), m.onDuty ? 'green' : '')}</div>`).join('');
        const staffRows = XS.list(r.staff).map((s) => `<div class="tb-row ro-staff"><span class="un-dot" style="background:${s.online ? 'var(--x-green)' : '#5c6674'}"></span><b>${esc(s.name)}</b><span class="m">${esc(s.cid)}</span><select class="tb-input" data-grade="${esc(s.cid)}" style="height:28px">${gradeOpts(s.grade)}</select><button class="tb-btn b-red b-sm" data-fire="${esc(s.cid)}">${esc(t('ro_fire', null, 'Let go'))}</button></div>`).join('');
        const hire = r.canManage ? `<span class="ro-hire"><input class="tb-input" id="ro-hire-id" type="number" min="1" style="width:110px;height:26px" placeholder="${esc(t('ro_server_id', null, 'Server ID'))}"><select class="tb-input" id="ro-hire-grade" style="width:150px;height:26px;background-position:calc(100% - 15px) 11px,calc(100% - 10px) 11px">${gradeOpts(0)}</select>${btn('hire', t('ro_hire', null, 'Hire'), 'b-go b-sm')}</span>` : '';
        el.innerHTML = header(esc(t('ph_staff', null, 'Staff')), esc(t('tab_roster', null, 'Roster')),
            `<input class="tb-input" id="ro-cs" maxlength="16" style="width:140px" placeholder="${esc(t('ro_callsign', null, 'Callsign'))}" value="${esc(me.callsign || '')}">${btn('callsign', t('ro_set_callsign', null, 'Set callsign'))}`)
            + `<div class="tb-body">
                <div class="tb-stats">${stats}</div>
                ${card('roster', t('ro_online', null, 'Staff online'), tag(t('ro_online_n', { n: online.length }, `${online.length} online`)), online.length ? `<div class="tb-scroll">${onlineRows}</div>` : empty('roster', t('ro_nobody', null, 'Nobody online'), ''), r.canManage ? '' : 'c-fill')}
                ${r.canManage ? card('records', t('ro_staff', null, 'Staff list'), hire, `<div class="tb-scroll">${staffRows || empty('roster', t('ro_no_staff', null, 'Nobody hired yet'), '')}</div>`, 'c-fill') : ''}
            </div>`;
        bind(el, {
            callsign: async () => {
                const res2 = await call('callsign', el.querySelector('#ro-cs').value);
                if (res2.ok) {
                    data.me.callsign = res2.data;
                    XS.toast(t('saved', null, 'Saved.'), 'ok');
                }
            },
            hire: async () => {
                const res2 = await call('hire', Number(el.querySelector('#ro-hire-id').value), Number(el.querySelector('#ro-hire-grade').value));
                if (res2.ok) { XS.toast(t('ro_hired', null, 'Hired.'), 'ok'); pageRoster(); }
            },
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

    const CATEGORIES = ['trauma', 'medical', 'traffic', 'assault', 'overdose', 'fire', 'other'];
    const OUTCOMES = ['scene', 'transported', 'admitted', 'refused', 'deceased'];
    const OUTCOME_TONE = { scene: 'green', transported: 'blue', admitted: 'purple', refused: 'yellow', deceased: 'red' };

    function stamp(ts) {
        if (!ts) return '—';
        const d = new Date(Number(ts) * 1000);
        if (Number.isNaN(d.getTime())) return '—';
        return `${d.toLocaleDateString(undefined, { day: 'numeric', month: 'short', year: 'numeric' })} ${String(d.getHours()).padStart(2, '0')}:${String(d.getMinutes()).padStart(2, '0')}`;
    }

    function dateParts(ts) {
        const d = new Date(Number(ts) * 1000);
        return {
            date: `${d.getFullYear()}-${String(d.getMonth() + 1).padStart(2, '0')}-${String(d.getDate()).padStart(2, '0')}`,
            time: `${String(d.getHours()).padStart(2, '0')}:${String(d.getMinutes()).padStart(2, '0')}`,
        };
    }

    function canEdit(r) {
        return !!(data.can.editReports || (r.author_cid && r.author_cid === (data.me || {}).cid));
    }

    async function pageReports() {
        const el = main();
        const from = view.reportFrom;
        view.reportFrom = null;
        el.innerHTML = header(esc(t('ph_records', null, 'Records')), esc(t('tab_reports', null, 'Care reports')),
            `<input class="tb-input" id="rp-q" style="width:220px" maxlength="40" placeholder="${esc(t('rp_search', null, 'Search reports'))}" value="${esc(view.rpQuery || '')}">${btn('search', t('search', null, 'Search'), '', { icon: 'search' })}${btn('new', t('rp_new', null, 'New report'), 'b-go', { icon: 'plus' })}`)
            + `<div class="tb-body"><div class="rp-grid">
                ${card('reports', t('rp_list', null, 'Reports'), '', `<div class="tb-scroll" id="rp-list"></div>`)}
                <div class="tb-card" id="rp-view">${empty('reports', t('rp_pick', null, 'No report open'), t('rp_pick_hint', null, 'Open one on the left or write a new one.'))}</div>
            </div></div>`;
        const list = async () => {
            view.rpQuery = el.querySelector('#rp-q').value.trim();
            const res = await call('reportsList', view.rpQuery);
            if (page !== 'reports') return;
            const rows = res.ok ? XS.list(res.data) : [];
            const box = el.querySelector('#rp-list');
            box.innerHTML = rows.length ? rows.map((r) => `<div class="tb-row rp-r r-click ${Number(r.id) === Number(view.reportOpen) ? 'on' : ''}" data-id="${Number(r.id)}">
                    <div><b>${esc(r.title)}</b><span class="s">#${Number(r.id)} · ${esc(stamp(r.incidentAt || toUnix(r.created_at)))}</span><span class="s">${esc(r.patient_name || t('rp_no_patient', null, 'No patient'))} · ${esc(r.author_name)}</span></div>
                    <div class="rp-tags">${r.category ? tag(t(`rp_cat_${r.category}`, null, r.category)) : ''}${r.outcome ? tag(t(`rp_out_${r.outcome}`, null, r.outcome), OUTCOME_TONE[r.outcome]) : ''}</div>
                </div>`).join('')
                : empty('reports', t('rp_none', null, 'No reports'), '');
            box.querySelectorAll('[data-id]').forEach((row) => row.addEventListener('click', () => {
                box.querySelectorAll('.tb-row').forEach((x) => x.classList.toggle('on', x === row));
                showReport(Number(row.dataset.id));
            }));
        };
        view.rpList = list;
        bind(el, { search: list, new: () => editor(null, from || null) });
        el.querySelector('#rp-q').addEventListener('keydown', (e) => { if (e.key === 'Enter') list(); });
        await list();
        if (from) editor(null, from);
        else if (view.reportOpen) showReport(view.reportOpen);
    }

    function fromPatient(p) {
        const s = (p && p.state) || {};
        const v = s.vitals || {};
        const visit = p && p.visit;
        const first = XS.list(p && p.timeline)[0];
        const name = p ? (p.realName || p.name) : '';
        const injuries = XS.list(s.injuries);
        const me = data.me || {};
        return {
            title: name ? t('rp_tpl_title', { name }, `Patient care report — ${name}`) : '',
            incidentAt: Number((first && first.t) || (visit && visit.since) || Math.floor(Date.now() / 1000)),
            category: injuries.length ? 'trauma' : 'medical',
            outcome: visit && visit.hospital ? 'admitted' : 'scene',
            destination: (visit && visit.hospital) || '',
            location: '', complaint: '', callId: null,
            patient: p && p.cid ? { cid: p.cid, name } : (name ? { cid: '', name } : null),
            crew: [{ cid: me.cid || '', name: me.name || '', callsign: me.callsign || '' }],
            vitals: {
                hr: v.hr ? String(v.hr) : '', bp: v.sys ? `${v.sys}/${v.dia}` : '', spo2: v.spo2 ? String(v.spo2) : '', resp: v.resp ? String(v.resp) : '',
                temp: v.temp ? Number(v.temp).toFixed(1) : '', pain: v.pain !== undefined && v.pain !== null ? String(v.pain) : '', avpu: v.avpu || '',
            },
            injuries: injuries.map((i) => XS.part(i.part) + ': ' + XS.describe(i)).concat(XS.list(p && p.cleared)),
            treatments: XS.list(p && p.timeline).map((e) => XS.time(e.t) + ' ' + e.text),
            body: '',
        };
    }

    function fromRow(r) {
        const d = r.data || {};
        const v = d.vitals || {};
        return {
            id: r.id, title: r.title || '', incidentAt: Number(d.incidentAt) || toUnix(r.created_at) || Math.floor(Date.now() / 1000),
            category: d.category || 'other', outcome: d.outcome || 'scene', destination: d.destination || '', location: d.location || '',
            complaint: d.complaint || '', callId: d.callId || null,
            patient: r.citizenid || r.patient_name ? { cid: r.citizenid || '', name: r.patient_name || '' } : null,
            crew: XS.list(d.crew),
            vitals: { hr: v.hr || '', bp: v.bp || '', spo2: v.spo2 || '', resp: v.resp || '', temp: v.temp || '', pain: v.pain || '', avpu: v.avpu || '' },
            injuries: XS.list(d.injuries).filter((x) => typeof x === 'string'),
            treatments: XS.list(d.treatments).filter((x) => typeof x === 'string'),
            body: r.body || '',
        };
    }

    function editor(row, patientFrom) {
        const box = main().querySelector('#rp-view');
        if (!box) return;
        const draft = row ? fromRow(row) : fromPatient(patientFrom);
        const when = dateParts(draft.incidentAt);
        const calls = openCalls();
        const opts = (list, prefix, sel) => list.map((k) => `<option value="${k}" ${k === sel ? 'selected' : ''}>${esc(t(`${prefix}${k}`, null, k))}</option>`).join('');
        box.innerHTML = `<div class="tb-ch">${icon('reports')}<span>${esc(row ? t('rp_editing', { id: row.id }, `Edit report #${row.id}`) : t('rp_writing', null, 'New report'))}</span><span class="tb-ch-r">${btn('cancel', t('rp_cancel', null, 'Cancel'), 'b-ghost b-sm')}${btn('save', t('save', null, 'Save'), 'b-go b-sm')}</span></div>
            <div class="tb-scroll"><div class="rp-form">
                <div class="rp-sec"><h4>${esc(t('rp_sec_report', null, 'Report'))}</h4><div class="tb-form">
                    <div class="f-wide"><label class="tb-label">${esc(t('rp_title', null, 'Title'))}</label><input class="tb-input" id="rp-title" maxlength="120" value="${esc(draft.title)}"></div>
                    <div><label class="tb-label">${esc(t('rp_date', null, 'Date'))}</label><input class="tb-input" id="rp-date" maxlength="10" placeholder="YYYY-MM-DD" value="${esc(when.date)}"></div>
                    <div><label class="tb-label">${esc(t('rp_time', null, 'Time'))}</label><div class="rp-inline"><input class="tb-input" id="rp-time" maxlength="5" placeholder="HH:MM" value="${esc(when.time)}">${btn('now', t('rp_now', null, 'Now'), 'b-sm')}</div></div>
                    <div><label class="tb-label">${esc(t('rp_category', null, 'Category'))}</label><select class="tb-input" id="rp-cat">${opts(CATEGORIES, 'rp_cat_', draft.category)}</select></div>
                    <div><label class="tb-label">${esc(t('rp_outcome', null, 'Outcome'))}</label><select class="tb-input" id="rp-out">${opts(OUTCOMES, 'rp_out_', draft.outcome)}</select></div>
                    <div><label class="tb-label">${esc(t('rp_location', null, 'Location'))}</label><div class="rp-inline"><input class="tb-input" id="rp-loc" maxlength="80" value="${esc(draft.location)}">${btn('here', t('rp_here', null, 'Here'), 'b-sm', { icon: 'pin' })}</div></div>
                    <div><label class="tb-label">${esc(t('rp_destination', null, 'Taken to'))}</label><input class="tb-input" id="rp-dest" maxlength="64" value="${esc(draft.destination)}"></div>
                    <div class="f-wide"><label class="tb-label">${esc(t('rp_call', null, 'Linked call'))}</label><select class="tb-input" id="rp-callid"><option value="">${esc(t('rp_call_none', null, 'No call'))}</option>${draft.callId && !calls.some((c) => Number(c.id) === Number(draft.callId)) ? `<option value="${Number(draft.callId)}" selected>#${Number(draft.callId)}</option>` : ''}${calls.map((c) => `<option value="${Number(c.id)}" ${Number(c.id) === Number(draft.callId) ? 'selected' : ''}>#${Number(c.id)} · ${esc(c.title)} · ${esc(c.street || '')}</option>`).join('')}</select></div>
                    <div class="f-wide"><label class="tb-label">${esc(t('rp_complaint', null, 'Chief complaint'))}</label><input class="tb-input" id="rp-complaint" maxlength="160" value="${esc(draft.complaint)}"></div>
                </div></div>
                <div class="rp-sec"><h4>${esc(t('ph_patient_k', null, 'Patient'))}</h4><div id="rp-patient"></div></div>
                <div class="rp-sec"><h4>${esc(t('rp_crew', null, 'Crew'))}</h4><div id="rp-crew"></div></div>
                <div class="rp-sec"><h4>${esc(t('rp_tpl_vitals', null, 'Vitals'))}</h4><div class="rp-vgrid">
                    ${[['hr', 'HR'], ['bp', 'BP'], ['spo2', 'SpO2'], ['resp', 'RESP'], ['temp', 'TEMP'], ['pain', t('st_pain', null, 'Pain')]].map(([k, l]) => `<div><label class="tb-label">${esc(l)}</label><input class="tb-input" data-vital="${k}" maxlength="${k === 'bp' ? 9 : 5}" value="${esc(draft.vitals[k] || '')}"></div>`).join('')}
                    <div><label class="tb-label">AVPU</label><select class="tb-input" data-vital="avpu"><option value=""></option>${['A', 'V', 'P', 'U'].map((x) => `<option value="${x}" ${draft.vitals.avpu === x ? 'selected' : ''}>${x}</option>`).join('')}</select></div>
                </div></div>
                <div class="rp-sec"><h4>${esc(t('rp_tpl_injuries', null, 'Injuries'))}</h4><textarea class="tb-input" id="rp-inj" rows="4" placeholder="${esc(t('rp_lines_hint', null, 'One per line'))}">${esc(draft.injuries.join('\n'))}</textarea></div>
                <div class="rp-sec"><h4>${esc(t('rp_treatment', null, 'Treatment given'))}</h4><textarea class="tb-input" id="rp-treat" rows="4" placeholder="${esc(t('rp_lines_hint', null, 'One per line'))}">${esc(draft.treatments.join('\n'))}</textarea></div>
                <div class="rp-sec"><h4>${esc(t('rp_narrative', null, 'Narrative'))}</h4><textarea class="tb-input" id="rp-body" rows="7" placeholder="${esc(t('rp_narrative_hint', null, 'What happened, what you found and what you did.'))}">${esc(draft.body)}</textarea></div>
            </div></div>`;

        const drawPatient = () => {
            const slot = box.querySelector('#rp-patient');
            if (!slot) return;
            const p = draft.patient;
            const current = patient && (patient.realName || patient.name) && !(p && p.cid && p.cid === patient.cid) ? patient : null;
            const useCurrent = current ? btn('curpat', t('rp_current', { name: current.realName || current.name }, 'This patient'), 'b-sm', { icon: 'patient' }) : '';
            slot.innerHTML = `${p ? `<div class="rp-chips"><span class="rp-chip on">${icon('body')}<b>${esc(p.name || '—')}</b>${p.cid ? `<em>${esc(p.cid)}</em>` : `<em>${esc(t('rp_no_cid', null, 'No ID'))}</em>`}<i data-unpatient>×</i></span></div>` : ''}
                <div class="rp-inline" style="margin-top:${p ? 10 : 0}px"><input class="tb-input" id="rp-psearch" maxlength="40" placeholder="${esc(p ? t('rp_change_patient', null, 'Change patient: search a name or ID') : t('rp_find_patient', null, 'Search a name or citizen ID'))}">${useCurrent}</div>
                <div class="rp-results" id="rp-presults"></div>`;
            const un = slot.querySelector('[data-unpatient]');
            if (un) un.addEventListener('click', () => { draft.patient = null; drawPatient(); });
            bind(slot, {
                curpat: () => {
                    draft.patient = { cid: current.cid || '', name: current.realName || current.name };
                    drawPatient();
                },
            });
            let timer = null;
            const input = slot.querySelector('#rp-psearch');
            input.addEventListener('input', () => {
                clearTimeout(timer);
                timer = setTimeout(async () => {
                    const q = input.value.trim();
                    const results = slot.querySelector('#rp-presults');
                    if (q.length < 2) { results.innerHTML = ''; return; }
                    const res = await call('recordsSearch', q);
                    if (!res.ok || !results.isConnected) return;
                    const found = XS.list(res.data).slice(0, 6);
                    results.innerHTML = found.length ? found.map((r) => `<div class="tb-row rc-r r-click" data-cid="${esc(r.cid)}" data-name="${esc(r.name)}"><div><b>${esc(r.name)}</b><span class="s">${esc(r.cid)}${r.dob ? ` · ${esc(r.dob)}` : ''}</span></div>${icon('plus')}</div>`).join('')
                        : `<div class="tb-row"><span class="m">${esc(t('rc_none', null, 'No matches'))}</span></div>`;
                    results.querySelectorAll('[data-cid]').forEach((row) => row.addEventListener('click', () => {
                        draft.patient = { cid: row.dataset.cid, name: row.dataset.name };
                        drawPatient();
                    }));
                }, 300);
            });
        };

        const drawCrew = () => {
            const slot = box.querySelector('#rp-crew');
            if (!slot) return;
            const taken = new Set(draft.crew.map((c) => c.cid || c.name));
            const online = XS.list(data.units).filter((u) => !taken.has(u.cid || u.name));
            slot.innerHTML = `<div class="rp-chips">${draft.crew.map((c, i) => `<span class="rp-chip">${c.callsign ? `<em>${esc(c.callsign)}</em>` : ''}<b>${esc(c.name)}</b><i data-uncrew="${i}">×</i></span>`).join('') || `<span class="m">${esc(t('rp_no_crew', null, 'Nobody attached yet'))}</span>`}</div>
                <div class="rp-inline" style="margin-top:10px"><select class="tb-input" id="rp-addcrew"><option value="">${esc(t('rp_add_crew', null, 'Add a medic on shift…'))}</option>${online.map((u, i) => `<option value="${i}">${esc([u.callsign, u.name].filter(Boolean).join(' · '))}</option>`).join('')}</select><input class="tb-input" id="rp-crewname" maxlength="60" placeholder="${esc(t('rp_crew_name', null, 'Or type a name'))}">${btn('addname', t('rp_add', null, 'Add'), 'b-sm', { icon: 'plus' })}</div>`;
            slot.querySelectorAll('[data-uncrew]').forEach((x) => x.addEventListener('click', () => { draft.crew.splice(Number(x.dataset.uncrew), 1); drawCrew(); }));
            slot.querySelector('#rp-addcrew').addEventListener('change', (e) => {
                const u = online[Number(e.target.value)];
                if (!u || draft.crew.length >= 8) return;
                draft.crew.push({ cid: u.cid || '', name: u.name, callsign: u.callsign || '' });
                drawCrew();
            });
            bind(slot, {
                addname: () => {
                    const name = slot.querySelector('#rp-crewname').value.trim();
                    if (!name || draft.crew.length >= 8) return;
                    draft.crew.push({ cid: '', name, callsign: '' });
                    drawCrew();
                },
            });
        };

        drawPatient();
        drawCrew();
        box.querySelector('#rp-callid').addEventListener('change', (e) => {
            const c = calls.find((x) => String(x.id) === e.target.value);
            const loc = box.querySelector('#rp-loc');
            if (c && !loc.value.trim()) loc.value = c.street || '';
        });
        bind(box.querySelector('.tb-ch'), {
            cancel: () => { if (row) showReport(row.id); else box.innerHTML = empty('reports', t('rp_pick', null, 'No report open'), t('rp_pick_hint', null, 'Open one on the left or write a new one.')); },
            save: async () => {
                const date = box.querySelector('#rp-date').value.trim();
                const time = box.querySelector('#rp-time').value.trim();
                const at = /^\d{4}-\d{2}-\d{2}$/.test(date) && /^\d{1,2}:\d{2}$/.test(time) ? new Date(`${date}T${time.padStart(5, '0')}:00`).getTime() : NaN;
                if (Number.isNaN(at)) { XS.toast(t('rp_bad_date', null, 'Check the date and time.'), 'error'); return; }
                const vitals = {};
                box.querySelectorAll('[data-vital]').forEach((input) => { vitals[input.dataset.vital] = input.value.trim(); });
                const split = (id) => box.querySelector(id).value.split('\n').map((x) => x.trim()).filter(Boolean);
                const p = draft.patient || {};
                const res = await call('reportsSave', {
                    id: row ? row.id : null, title: box.querySelector('#rp-title').value, incidentAt: Math.floor(at / 1000),
                    category: box.querySelector('#rp-cat').value, outcome: box.querySelector('#rp-out').value,
                    location: box.querySelector('#rp-loc').value, destination: box.querySelector('#rp-dest').value,
                    callId: box.querySelector('#rp-callid').value || null, complaint: box.querySelector('#rp-complaint').value,
                    cid: p.cid || '', patient: p.name || '', crew: draft.crew, vitals,
                    injuries: split('#rp-inj'), treatments: split('#rp-treat'), body: box.querySelector('#rp-body').value,
                });
                if (!res.ok) return;
                XS.toast(t('saved', null, 'Saved.'), 'ok');
                view.reportOpen = Number(res.data);
                if (view.rpList) await view.rpList();
                showReport(view.reportOpen);
            },
        });
        bind(box.querySelector('.rp-form'), {
            now: () => {
                const parts = dateParts(Math.floor(Date.now() / 1000));
                box.querySelector('#rp-date').value = parts.date;
                box.querySelector('#rp-time').value = parts.time;
            },
            here: async () => {
                const res = await XS.rpc('tablet:street', {});
                if (res.ok && res.data) box.querySelector('#rp-loc').value = res.data;
            },
        });
    }

    async function showReport(id) {
        view.reportOpen = id;
        const res = await call('reportsGet', id);
        if (!res.ok || page !== 'reports') return;
        const r = res.data;
        const d = r.data || {};
        const v = d.vitals || {};
        const box = main().querySelector('#rp-view');
        if (!box) return;
        const crew = XS.list(d.crew);
        const injuries = XS.list(d.injuries).filter((x) => typeof x === 'string');
        const treatments = XS.list(d.treatments).filter((x) => typeof x === 'string');
        const vitals = [['HR', v.hr], ['BP', v.bp], ['SpO2', v.spo2], ['RESP', v.resp], ['TEMP', v.temp], [t('st_pain', null, 'Pain'), v.pain], ['AVPU', v.avpu]].filter((x) => x[1]);
        const list = (items) => items.length ? items.map((x) => `<div class="rp-li">${esc(x)}</div>`).join('') : `<div class="rp-li m">${esc(t('rc_none_yet', null, 'None yet'))}</div>`;
        const info = (k, val) => `<div class="tb-info"><span class="k">${esc(k)}</span><span class="v">${esc(val || '—')}</span></div>`;
        box.innerHTML = `<div class="tb-ch">${icon('reports')}<span>${esc(t('rp_number', { id: r.id }, `Report #${r.id}`))}</span><span class="tb-ch-r">${canEdit(r) ? btn('edit', t('rp_edit', null, 'Edit'), 'b-sm') : ''}${data.can.deleteReports ? btn('del', t('delete', null, 'Delete'), 'b-red b-sm') : ''}</span></div>
            <div class="tb-scroll"><div class="rp-doc">
                <div class="rp-title">${esc(r.title)}</div>
                <div class="tb-stats rp-stats">
                    ${stat(t('rp_incident', null, 'Incident'), stamp(d.incidentAt || toUnix(r.created_at)), '', d.callId ? t('rp_call_n', { id: d.callId }, `Call #${d.callId}`) : '')}
                    ${stat(t('rp_category', null, 'Category'), t(`rp_cat_${d.category || 'other'}`, null, d.category || 'other'), '', '')}
                    ${stat(t('rp_outcome', null, 'Outcome'), t(`rp_out_${d.outcome || 'scene'}`, null, d.outcome || 'scene'), '', d.destination || '')}
                </div>
                <div class="rp-sec"><h4>${esc(t('ph_patient_k', null, 'Patient'))}</h4><div class="rp-chips">${r.patient_name || r.citizenid ? `<span class="rp-chip on">${icon('body')}<b>${esc(r.patient_name || '—')}</b>${r.citizenid ? `<em>${esc(r.citizenid)}</em>` : ''}</span>${r.citizenid && on('records') ? btn('record', t('rp_open_record', null, 'Open record'), 'b-sm b-ghost', { icon: 'records' }) : ''}` : `<span class="m">${esc(t('rp_no_patient', null, 'No patient'))}</span>`}</div></div>
                <div class="rp-sec"><h4>${esc(t('rp_crew', null, 'Crew'))}</h4><div class="rp-chips">${crew.map((c) => `<span class="rp-chip">${c.callsign ? `<em>${esc(c.callsign)}</em>` : ''}<b>${esc(c.name)}</b></span>`).join('') || `<span class="m">${esc(r.author_name)}</span>`}</div></div>
                <div class="rp-sec"><h4>${esc(t('rp_sec_incident', null, 'Scene'))}</h4>${info(t('rp_location', null, 'Location'), d.location)}${info(t('rp_complaint', null, 'Chief complaint'), d.complaint)}</div>
                ${vitals.length ? `<div class="rp-sec"><h4>${esc(t('rp_tpl_vitals', null, 'Vitals'))}</h4><div class="rp-vrow">${vitals.map(([k, val]) => `<div><small>${esc(k)}</small><b>${esc(val)}</b></div>`).join('')}</div></div>` : ''}
                <div class="rp-sec"><h4>${esc(t('rp_tpl_injuries', null, 'Injuries'))}</h4>${list(injuries)}</div>
                <div class="rp-sec"><h4>${esc(t('rp_treatment', null, 'Treatment given'))}</h4>${list(treatments)}</div>
                <div class="rp-sec"><h4>${esc(t('rp_narrative', null, 'Narrative'))}</h4><div class="rp-text">${esc(r.body || '—')}</div></div>
                <div class="rp-foot">${esc(t('rp_written', { name: r.author_name, when: stamp(toUnix(r.created_at)) }, `Written by ${r.author_name}`))}${d.editedBy ? ` · ${esc(t('rp_edited', { name: d.editedBy, when: stamp(d.editedAt) }, `Edited by ${d.editedBy}`))}` : ''}</div>
            </div></div>`;
        bind(box, {
            edit: () => editor(r, null),
            del: async () => {
                const r2 = await call('reportsDelete', id);
                if (r2.ok) { view.reportOpen = null; pageReports(); }
            },
            record: () => { view.rcOpen = r.citizenid; view.rcQuery = r.citizenid; go('records'); },
        });
    }

    function bedTitle(b) {
        return b.room ? b.room + ' · ' + b.label : b.label;
    }

    async function pageHospital() {
        const places = XS.list(data.places);
        const el = main();
        if (!places.length) {
            el.innerHTML = header(esc(t('ph_shift', null, 'Shift')), esc(t('tab_hospital', null, 'Hospital')), '') + `<div class="tb-body">${empty('hospital', t('hs_none_title', null, 'No hospitals yet'), t('hs_none', null, 'An admin can add one with the builder.'))}</div>`;
            return;
        }
        if (!places.some((p) => p.id === view.hospital)) view.hospital = places[0].id;
        const place = places.find((p) => p.id === view.hospital);
        const picker = places.length > 1 ? `<select class="tb-input" id="hs-pick" style="width:240px">${places.map((p) => `<option value="${Number(p.id)}" ${p.id === view.hospital ? 'selected' : ''}>${esc(p.name)}</option>`).join('')}</select>` : '';
        el.innerHTML = header(esc(t('ph_shift', null, 'Shift')), esc(place.name), `${picker}${btn('refresh', t('refresh', null, 'Refresh'), 'b-ghost', { icon: 'refresh' })}`) + `<div class="tb-body" id="hs-body">${empty('hospital', t('loading', null, 'Loading…'), '')}</div>`;
        const pick = el.querySelector('#hs-pick');
        if (pick) pick.addEventListener('change', (e) => { view.hospital = Number(e.target.value); pageHospital(); });
        bind(el, { refresh: () => pageHospital() });
        const res = await call('hospital', view.hospital);
        if (page !== 'hospital' || !res.ok) return;
        const h = res.data;
        const beds = XS.list(h.beds);
        const board = XS.list(h.board);
        const free = beds.filter((b) => !b.occupant).length;
        const waiting = board.filter((r) => r.status === 'waiting').length;
        const stats = [
            stat(t('hs_st_beds', null, 'Beds'), String(beds.length), '', t('hs_st_beds_hint', null, 'In this hospital')),
            stat(t('hs_st_free', null, 'Free'), String(free), beds.length && !free ? 'r' : 'g', free ? t('hs_st_free_hint', null, 'Ready for a patient') : t('hs_st_full', null, 'Every bed is taken')),
            stat(t('hs_st_board', null, 'On the board'), String(board.length), '', t('hs_st_board_hint', null, 'Patients in care')),
            stat(t('hs_st_waiting', null, 'Waiting'), String(waiting), waiting ? 'y' : '', waiting ? t('hs_st_waiting_hint', null, 'Need a medic') : t('cl_st_nobody', null, 'Nobody waiting')),
        ].join('');
        const tiles = beds.map((b) => `<div class="hs-bed ${b.occupant ? '' : 'free'}" style="--bar:${b.occupant ? (SHADE[b.acuity] || 'var(--x-blue)') : 'var(--x-line2)'}"><span class="m">${esc(bedTitle(b))}</span><b>${esc(b.occupant ? (b.name || t('hs_occupied', null, 'Occupied')) : t('hs_free', null, 'Free'))}</b>${b.occupant && b.status ? `<span class="d">${esc(t(`visit_${b.status}`, null, b.status))}</span>` : ''}</div>`).join('');
        const rows = board.map((r) => `<div class="tb-row hs-r r-click" data-src="${Number(r.src)}"><span class="pk-dot" style="background:${SHADE[r.acuity] || SHADE[5]}"></span><span class="m">${esc(r.room || '—')}</span><b>${esc(r.name)}</b>${tag(t(`visit_${r.status}`, null, r.status), r.status === 'waiting' ? 'yellow' : (r.status === 'surgery' ? 'purple' : ''))}<span class="m" data-since="${Number(r.since)}"><span>${esc(since(r.since))}</span></span></div>`).join('');
        el.querySelector('#hs-body').innerHTML = `<div class="tb-stats">${stats}</div>
            ${card('hospital', t('hs_beds', null, 'Beds'), tag(t('hs_free_n', { n: free }, `${free} free`), free ? 'green' : 'red'), beds.length ? `<div class="hs-beds">${tiles}</div>` : empty('hospital', t('hs_no_beds', null, 'No beds placed'), t('hs_no_beds_hint', null, 'Add beds with the builder.')))}
            ${card('log', t('hs_board', null, 'On the board'), '', board.length ? `<div class="tb-scroll">${rows}</div>` : empty('log', t('hs_board_empty', null, 'Nobody on the board'), ''), 'c-fill')}`;
        el.querySelectorAll('#hs-body [data-src]').forEach((row) => row.addEventListener('click', async () => {
            patient = null;
            await loadPatient(Number(row.dataset.src));
            go('patient');
        }));
    }

    XS.apps.tablet = {
        isOpen: () => open,
        escape: () => {
            const over = root.querySelector('.tb-over');
            if (over) { over.remove(); return; }
            XS.close('tablet');
        },
        on(action, payload) {
            if (action === 'open') {
                data = payload;
                data.can = data.can || {};
                open = true;
                page = payload.page && PAGES.includes(payload.page) && on(payload.page) ? payload.page : 'patient';
                patient = null;
                patientId = payload.patient || null;
                XS.show('xsm-tablet', true);
                shell();
                renderPage();
            } else if (action === 'close') {
                open = false;
                clearInterval(pageTimer);
                clearInterval(clockTimer);
                pageTimer = null;
                XS.show('xsm-tablet', false);
                root.innerHTML = '';
            } else if (action === 'calls') {
                if (!open || !data) return;
                const c = payload.call;
                const list = XS.list(data.calls).filter((x) => x.id !== c.id);
                if (c.status !== 'closed') list.unshift(c);
                data.calls = list;
                nav();
                if (page === 'calls') drawCalls();
            } else if (action === 'refreshPatient') {
                if (open && page === 'patient' && patientId) loadPatient(patientId).then(() => { if (patient && page === 'patient') drawPatient(); });
            }
        },
    };
})();
