(() => {
    if (typeof GetParentResourceName === 'function') return;
    if (location.hostname.toLowerCase() === RESOURCE.toLowerCase()) return;

    const now = Math.floor(Date.now() / 1000);
    const injuries = [
        { id: 1, part: 'lleg', kind: 'gunshot', sev: 3, bleed: 3, rawBleed: 3, fracture: false, bulletIn: false, treated: {}, surgery: false },
        { id: 2, part: 'rarm', kind: 'blunt', sev: 2, bleed: 0, rawBleed: 0, fracture: true, treated: {}, surgery: false },
        { id: 3, part: 'torso', kind: 'gunshot', sev: 2, bleed: 1, rawBleed: 1, bulletIn: true, treated: {}, surgery: true },
    ];
    const vitals = { hr: 118, sys: 96, dia: 58, spo2: 93, resp: 22, temp: 36.4, rhythm: 'tachy', avpu: 'A', pain: 7, blood: 72, status: 'alive', alarms: ['spo2'], acuity: 2 };
    const state = { status: 'alive', blood: 72, injuries, vitals, relief: 0 };

    const patient = {
        src: 7, name: 'Isabel Ferreira', realName: 'Isabel Ferreira', cid: 'XSM10293', identified: true, female: true, near: true, dist: 1.6,
        state, visit: { room: 'Trauma 1', status: 'seen', hospital: 'Pillbox Medical', since: now - 780, medic: 'Vincent Valentine' },
        timeline: [
            { t: now - 780, text: 'Found down on Vespucci Blvd, bleeding', by: 'Vincent Valentine' },
            { t: now - 660, text: 'Pressure bandage on the left leg, still bleeding', by: 'Vincent Valentine' },
            { t: now - 600, text: 'Morphine given', by: 'Vincent Valentine' },
        ],
        record: { blood: 'O-', allergies: 'Penicillin', conditions: 'Asthma', dob: '1997-03-14', prescriptions: [] },
    };

    const calls = [
        { id: 2043, kind: 'down', code: '10-52', title: 'Person down', description: 'Not breathing', street: 'Legion Square', coords: { x: 195, y: -933, z: 30 }, caller: 'Passer-by', priority: 1, status: 'open', units: [], createdAt: now - 22 },
        { id: 2042, kind: 'request', code: '10-52', title: 'Medical assistance', description: 'Car crash · 2 hurt', street: 'Route 68, Harmony', coords: { x: 590, y: 2700, z: 41 }, caller: 'Terrence Obi', priority: 2, status: 'assigned', units: [{ src: 1, name: 'Vincent Valentine' }], createdAt: now - 130 },
    ];

    const places = [{
        id: 1, kind: 'hospital', name: 'Pillbox Medical', blip: true, society: '',
        points: {
            checkin: [{ id: 'a1', x: 307.7, y: -595.4, z: 43.3, w: 70, ped: 's_f_y_scrubs_01', npc: true }],
            bed: [
                { id: 'b1', x: 317.7, y: -585.2, z: 43.2, w: 160, label: 'Bed 1', room: 'Trauma 1', prop: false, respawn: true, monitor: { x: 318.5, y: -584.0, z: 44.6, w: 160, width: 0.55 } },
                { id: 'b2', x: 322.6, y: -587.1, z: 43.2, w: 160, label: 'Bed 2', room: 'Room 2', prop: 'v_med_bed1', respawn: true },
            ],
            surgery: [{ id: 's1', x: 314.2, y: -568.4, z: 43.2, w: 340, room: 'OR 1', label: 'Table' }],
            storage: [], cabinet: [], duty: [{ id: 'd1', x: 311.1, y: -599.2, z: 43.3, w: 0 }],
            garage: [{ id: 'g1', x: 294.6, y: -600.3, z: 43.3, w: 70, grade: 0, vehicles: ['ambulance'], spawn: { x: 290.0, y: -610.0, z: 43.4, w: 340 } }],
            helipad: [], equipment: [], elevator: [], boss: [],
            board: [{ id: 'w1', x: 306.0, y: -592.0, z: 44.8, w: 160, title: '', rooms: [], width: 2.2 }],
            sign: [], pharmacist: [],
        },
    }];

    const responses = {
        'tablet:patient': () => ({ ok: true, data: patient }),
        'tablet:nearby': () => ({ ok: true, data: [{ src: 7, name: 'Isabel Ferreira', dist: 1.6, status: 'alive', acuity: 2 }] }),
        'tablet:calls': () => ({ ok: true, data: calls }),
        'tablet:recordsSearch': () => ({ ok: true, data: [{ cid: 'XSM10293', name: 'Isabel Ferreira', dob: '1997-03-14' }, { cid: 'XSM11877', name: 'Terrence Obi', dob: '1990-08-02' }] }),
        'tablet:recordsOpen': () => ({ ok: true, data: { cid: 'XSM10293', name: 'Isabel Ferreira', dob: '1997-03-14', blood: 'O-', allergies: 'Penicillin', conditions: 'Asthma', notes: 'Carries an inhaler.', prescriptions: [{ id: 4, label: 'Oxycodone', dose: '10 mg', qty: 10, refills: 1, status: 'active', prescriber: 'Ruth Calloway', createdAt: now - 86400 * 2 }], history: [{ created_at: now - 3600, kind: 'treatment', summary: 'Tourniquet on the left leg', medic_name: 'Vincent Valentine' }, { created_at: now - 86400 * 3, kind: 'visit', summary: 'Visit at Pillbox Medical', medic_name: 'Ruth Calloway' }], reports: [] } }),
        'tablet:roster': () => ({ ok: true, data: { canManage: true, balance: 48250, grades: [{ level: 0, label: 'Recruit' }, { level: 1, label: 'Paramedic' }, { level: 2, label: 'Doctor' }, { level: 3, label: 'Surgeon' }, { level: 4, label: 'Chief' }], online: [{ src: 1, cid: 'A1', name: 'Vincent Valentine', grade: 3, gradeLabel: 'Surgeon', onDuty: true, callsign: 'M-3' }, { src: 4, cid: 'A2', name: 'Ruth Calloway', grade: 2, gradeLabel: 'Doctor', onDuty: true, callsign: 'M-1' }, { src: 9, cid: 'A3', name: 'Dana Kessler', grade: 1, gradeLabel: 'Paramedic', onDuty: false, callsign: '' }], staff: [{ cid: 'A1', name: 'Vincent Valentine', grade: 3, online: true }, { cid: 'A2', name: 'Ruth Calloway', grade: 2, online: true }, { cid: 'A3', name: 'Dana Kessler', grade: 1, online: true }, { cid: 'A4', name: 'Marcus Hale', grade: 0, online: false }] } }),
        'tablet:reportsList': () => ({ ok: true, data: [{ id: 12, title: 'Patient care report — Isabel Ferreira', patient_name: 'Isabel Ferreira', author_name: 'Vincent Valentine', created_at: now - 1200 }] }),
        'tablet:reportsGet': () => ({ ok: true, data: { id: 12, title: 'Patient care report — Isabel Ferreira', patient_name: 'Isabel Ferreira', author_name: 'Vincent Valentine', created_at: now - 1200, body: 'Injuries:\nLeft leg: Gunshot · bleeding badly\n\nTourniquet applied 14:11, morphine 14:12, transported to Pillbox.' } }),
        'tablet:hospital': () => ({ ok: true, data: { id: 1, name: 'Pillbox Medical', beds: [{ id: 'b1', label: 'Bed 1', room: 'Trauma 1', occupant: 7, name: 'Isabel Ferreira', status: 'seen', acuity: 2 }, { id: 'b2', label: 'Bed 2', room: 'Room 2' }, { id: 'b3', label: 'Bed 3', room: 'Room 3', occupant: 11, name: 'Jane Doe', status: 'waiting', acuity: 3 }, { id: 'b4', label: 'Bed 4', room: 'Room 4' }], board: [{ src: 7, name: 'Isabel Ferreira', room: 'Trauma 1', status: 'seen', medic: 'Vincent Valentine', since: now - 780, acuity: 2 }, { src: 11, name: 'Jane Doe', room: 'Room 3', status: 'waiting', medic: '', since: now - 240, acuity: 3 }] } }),
        'surgery:end': () => ({ ok: true, data: 'Surgery finished: 1 fixed, 0 complications.' }),
        'builder:place': () => ({ ok: true, data: { x: 310.2, y: -590.4, z: 43.2, w: 90, width: 2.2 } }),
        'builder:here': () => ({ ok: true, data: { x: 311.0, y: -591.0, z: 43.2, w: 45 } }),
        'builder:save': (p) => ({ ok: true, data: Object.assign({}, p, { id: p.id || 2 }) }),
    };

    const realFetch = window.fetch.bind(window);
    window.fetch = async (url, opts) => {
        const target = String(url).toLowerCase();
        if (!target.includes(`${RESOURCE.toLowerCase()}/`)) return realFetch(url, opts);
        const body = opts && opts.body ? JSON.parse(opts.body) : {};
        const endpoint = target.split('/').pop();
        let out = true;
        if (endpoint === 'rpc') {
            const fn = responses[body.name];
            out = fn ? fn(body.payload || {}) : { ok: true, data: true };
        }
        return new Response(JSON.stringify(out), { headers: { 'Content-Type': 'application/json' } });
    };

    const send = (app, action, data) => window.postMessage({ app, action, data }, '*');

    window.XSMock = {
        scene(name) {
            document.body.style.background = 'radial-gradient(ellipse at 30% 20%, #3a4a52, #11181c 70%)';
            send('core', 'boot', { locale: window.XSMockLocale || {}, config: { hud: true, supplies: { bandage: { self: true }, tourniquet: { self: true }, gauze: { self: false }, splint: { self: false }, burncream: { self: true }, painkillers: { self: true }, ifaks: { self: true } } } });
            if (name === 'down') send('down', 'open', { status: 'down', seconds: { bleedOut: 192, respawn: 108 }, vitals: Object.assign({}, vitals, { hr: 41 }), injuries, ems: 2, blood: 58 });
            if (name === 'arrest') send('down', 'open', { status: 'arrest', rhythm: 'vf', seconds: { arrest: 171, respawn: 0 }, vitals: { hr: 0 }, injuries, ems: 2 });
            if (name === 'knockout') send('down', 'open', { status: 'knockout', seconds: { wake: 31 }, vitals: { hr: 64 }, injuries: [], ems: 0 });
            if (name === 'hud') {
                send('self', 'state', state);
                send('bed', 'open', { seconds: 18, treat: true, label: 'Trauma 1' });
                send('pager', 'call', { call: calls[0], dist: 210 });
            }
            if (name === 'self') send('self', 'open', { state, have: { bandage: 2, tourniquet: 1, painkillers: 3, burncream: 0, ifaks: 0 } });
            if (name === 'menu') send('menu', 'open', { title: 'Supply cabinet', subtitle: 'Pillbox Medical', items: [{ id: 'bandage', label: 'Bandage', right: 'Free', qty: true }, { id: 'tourniquet', label: 'Tourniquet', right: 'Free', qty: true }, { id: 'morphine', label: 'Morphine', right: 'Free', qty: true }, { id: 'saline', label: 'IV saline', right: 'Free', qty: true }] });
            if (name === 'checkin') send('menu', 'open', { title: 'Patient check-in', subtitle: 'Pillbox Medical', note: 'No doctors on duty right now. The nurse will treat you for $250.', items: [{ id: 'checkin', label: 'Check in' }] });
            if (name === 'pharmacy') send('pharmacy', 'open', { store: 'Pillbox Pharmacy', patient: 'Isabel Ferreira', dob: '1997-03-14', blood: 'O-', allergies: 'Penicillin', money: { cash: 820, bank: 15400 }, prescriptions: [{ id: 4, label: 'Oxycodone', dose: '10 mg', qty: 10, refills: 1, prescriber: 'Ruth Calloway', price: 140 }, { id: 5, label: 'Amoxicillin', dose: '500 mg', qty: 14, refills: 0, prescriber: 'Vincent Valentine', price: 90 }], counter: [{ item: 'painkillers', label: 'Painkillers', price: 45 }, { item: 'bandage', label: 'Bandage', price: 30 }, { item: 'burncream', label: 'Burn dressing', price: 60 }] });
            if (name === 'surgery') send('surgery', 'open', { key: '1:s1', patient: 'Isabel Ferreira', seconds: 45, vitals, injuries: [{ id: 3, part: 'torso', kind: 'gunshot', bulletIn: true }, { id: 2, part: 'rarm', kind: 'blunt', fracture: true }] });
            if (name.startsWith('tablet')) {
                const page = name.split('-')[1] || 'patient';
                send('tablet', 'open', { page, patient: page === 'patient' ? 7 : null, me: { src: 1, name: 'Vincent Valentine', callsign: 'M-3', grade: 3, gradeLabel: 'Surgeon', isBoss: false, job: 'ambulance', jobLabel: 'EMS' }, can: { prescribe: true, surgery: true, editRecords: true, deleteReports: true, manage: true }, patients: [], calls, places: [{ id: 1, name: 'Pillbox Medical' }], nearby: [{ src: 7, name: 'Isabel Ferreira', dist: 1.6, status: 'alive', acuity: 2 }, { src: 11, name: 'Jane Doe', dist: 6.2, status: 'down', acuity: 1 }], medicines: [{ item: 'oxycodone', label: 'Oxycodone', dose: '10 mg' }, { item: 'amoxicillin', label: 'Amoxicillin', dose: '500 mg' }, { item: 'diazepam', label: 'Diazepam', dose: '5 mg' }], supplies: { bandage: { label: 'Bandage' }, tourniquet: { label: 'Tourniquet' }, gauze: { label: 'Pressure dressing' }, splint: { label: 'Splint' }, morphine: { label: 'Morphine' }, saline: { label: 'IV saline' }, adrenaline: { label: 'Adrenaline' }, defibrillator: { label: 'Defibrillator' } } });
            }
            if (name === 'builder') send('builder', 'open', { places, vehicles: [{ model: 'ambulance', label: 'Brute Ambulance' }, { model: 'polmav', label: 'Police Maverick' }, { model: 'lguard', label: 'Lifeguard' }], peds: { checkin: 's_f_y_scrubs_01', pharmacist: 's_m_m_doctor_01' }, bedProp: 'v_med_bed1' });
        },
    };

    window.addEventListener('load', () => {
        const name = (location.hash || '#tablet').slice(1);
        setTimeout(() => {
            window.XSMock.scene(name);
            if (name === 'builder') setTimeout(() => { const first = document.querySelector('[data-id]'); if (first) first.click(); }, 200);
        }, 100);
    });
})();
