(() => {
    const root = document.getElementById('xsm-builder');
    let open = false;
    let places = [];
    let vehicles = [];
    let defaults = {};
    let current = null;
    let dirty = false;
    let busy = false;
    const collapsed = {};
    const vehFilter = {};

    const t = XS.t;
    const esc = XS.esc;

    const KINDS = {
        hospital: ['checkin', 'bed', 'surgery', 'storage', 'cabinet', 'duty', 'garage', 'helipad', 'equipment', 'elevator', 'boss', 'board', 'sign', 'pharmacist'],
        pharmacy: ['pharmacist', 'sign'],
    };
    const WALL = { board: 'board', sign: 'sign' };

    const uid = () => `p${Date.now().toString(36)}${Math.floor(Math.random() * 1e4).toString(36)}`;
    const copy = (v) => JSON.parse(JSON.stringify(v));

    function blankPoint(kind, pos) {
        const p = Object.assign({ id: uid(), x: 0, y: 0, z: 0, w: 0 }, pos || {});
        if (kind === 'checkin') Object.assign(p, { ped: defaults.checkin || 's_f_y_scrubs_01', npc: true });
        if (kind === 'bed') {
            const n = (current.points.bed || []).length + 1;
            Object.assign(p, { label: `Bed ${n}`, room: '', prop: pos && pos.snapped ? false : (defaults.bedProp || 'v_med_bed1'), respawn: true });
        }
        if (kind === 'surgery') Object.assign(p, { room: 'OR 1', label: 'Table' });
        if (kind === 'storage') Object.assign(p, { label: 'Storage', slots: 50, weight: 200000, grade: 0 });
        if (kind === 'garage' || kind === 'helipad') Object.assign(p, { grade: 0, vehicles: [], spawn: null });
        if (kind === 'equipment') Object.assign(p, { kind: 'stretcher' });
        if (kind === 'elevator') Object.assign(p, { group: 'Elevator', floor: 'Ground floor' });
        if (kind === 'board') Object.assign(p, { title: '', rooms: [], width: (pos && pos.width) || 2.2 });
        if (kind === 'sign') Object.assign(p, { room: '', width: (pos && pos.width) || 0.6 });
        if (kind === 'pharmacist') Object.assign(p, { ped: defaults.pharmacist || 's_m_m_doctor_01' });
        delete p.snapped;
        return p;
    }

    function markDirty() {
        dirty = true;
        const el = root.querySelector('#bl-dirty');
        if (el) el.textContent = t('builder_unsaved', null, 'Unsaved changes');
    }

    function select() { XS.rpc('builder:select', current); }

    function render() {
        const stage = XS.stage(root);
        stage.innerHTML = `
            <div class="bl-shell">
                <div class="bl-side">
                    <div class="bl-brand"><span>XS</span>-Medical ${esc(t('builder_title', null, 'Builder'))}<small>${esc(t('builder_sub', null, 'Hospitals and pharmacies'))}</small></div>
                    <div class="bl-new"><button class="bl-btn b-go" data-new="hospital">+ ${esc(t('builder_new_hospital', null, 'Hospital'))}</button><button class="bl-btn" data-new="pharmacy">+ ${esc(t('builder_new_pharmacy', null, 'Pharmacy'))}</button></div>
                    <div class="bl-places xsm-scroll">${places.map((p) => `<div class="bl-place ${current && current.id === p.id ? 'p-on' : ''}" data-id="${p.id}"><b>${esc(p.name)}</b><span>${esc(t(`builder_kind_${p.kind}`, null, p.kind))} · ${count(p)} ${esc(t('builder_points', null, 'points'))}</span></div>`).join('') || `<div class="bl-note" style="padding:10px">${esc(t('builder_no_places', null, 'Nothing built yet. Start with a hospital.'))}</div>`}</div>
                    <div style="padding:12px 14px;border-top:1px solid #232a2f"><button class="bl-btn" id="bl-close" style="width:100%">${esc(t('close', null, 'Close'))}</button></div>
                </div>
                <div class="bl-main">${current ? editor() : `<div class="bl-empty">${esc(t('builder_pick', null, 'Pick a place on the left or make a new one'))}</div>`}</div>
            </div>`;
        bind(stage);
    }

    function count(p) {
        return Object.values(p.points || {}).reduce((n, list) => n + XS.list(list).length, 0);
    }

    function field(label, inner) {
        return `<div class="bl-field"><label>${esc(label)}</label>${inner}</div>`;
    }

    function input(kind, i, key, value, type, extra) {
        return `<input class="bl-in" data-k="${kind}" data-i="${i}" data-f="${key}" type="${type || 'text'}" value="${esc(value == null ? '' : value)}" ${extra || ''}>`;
    }

    function check(kind, i, key, value, label) {
        return `<label class="bl-check"><input type="checkbox" data-k="${kind}" data-i="${i}" data-f="${key}" ${value ? 'checked' : ''}>${esc(label)}</label>`;
    }

    function vehicleList(kind, i, p) {
        const f = (vehFilter[`${kind}${i}`] || '').toLowerCase();
        const picked = new Set(XS.list(p.vehicles));
        const shown = vehicles.filter((v) => picked.has(v.model) || !f || v.model.toLowerCase().includes(f) || v.label.toLowerCase().includes(f)).slice(0, 150);
        return `<input class="bl-in" data-vf="${kind}${i}" placeholder="${esc(t('builder_vehicle_search', null, 'Search your vehicles list'))}" value="${esc(vehFilter[`${kind}${i}`] || '')}">
            <div class="bl-veh xsm-scroll">${shown.map((v) => `<label><input type="checkbox" data-veh="${esc(v.model)}" data-k="${kind}" data-i="${i}" ${picked.has(v.model) ? 'checked' : ''}>${esc(v.label)} <span style="color:#55616a">${esc(v.model)}</span></label>`).join('') || `<span class="bl-note">${esc(t('builder_vehicle_none', null, 'No match'))}</span>`}</div>`;
    }

    function cardFields(kind, p, i) {
        if (kind === 'checkin') return `<div class="bl-grid">${field(t('builder_ped', null, 'Nurse model'), input(kind, i, 'ped', p.ped))}${field(' ', check(kind, i, 'npc', p.npc !== false, t('builder_npc', null, 'Nurse NPC')))}</div>`;
        if (kind === 'bed') return `<div class="bl-grid">${field(t('builder_label', null, 'Label'), input(kind, i, 'label', p.label))}${field(t('builder_room', null, 'Room'), input(kind, i, 'room', p.room))}
            ${field(t('builder_prop', null, 'Bed prop (empty for a map bed)'), input(kind, i, 'prop', p.prop || ''))}${field(' ', check(kind, i, 'respawn', p.respawn !== false, t('builder_respawn', null, 'Respawn here')))}</div>
            <div class="bl-acts">${p.monitor ? `<button class="bl-btn b-small" data-mon="${i}">${esc(t('builder_monitor_move', null, 'Move monitor'))}</button><button class="bl-btn b-small b-danger" data-monrm="${i}">${esc(t('builder_monitor_remove', null, 'Remove monitor'))}</button>` : `<button class="bl-btn b-small" data-mon="${i}">+ ${esc(t('builder_monitor_add', null, 'Bedside monitor'))}</button>`}</div>`;
        if (kind === 'surgery') return `<div class="bl-grid">${field(t('builder_room', null, 'Room'), input(kind, i, 'room', p.room))}${field(t('builder_label', null, 'Label'), input(kind, i, 'label', p.label))}</div>`;
        if (kind === 'storage') return `<div class="bl-grid">${field(t('builder_label', null, 'Label'), input(kind, i, 'label', p.label))}${field(t('builder_grade', null, 'Lowest grade'), input(kind, i, 'grade', p.grade, 'number', 'min="0"'))}${field(t('builder_slots', null, 'Slots'), input(kind, i, 'slots', p.slots, 'number', 'min="5"'))}${field(t('builder_weight', null, 'Max weight'), input(kind, i, 'weight', p.weight, 'number', 'min="1000"'))}</div>`;
        if (kind === 'garage' || kind === 'helipad') return `<div class="bl-grid">${field(t('builder_grade', null, 'Lowest grade'), input(kind, i, 'grade', p.grade, 'number', 'min="0"'))}${field(t('builder_spawn', null, 'Spawn spot'), `<button class="bl-btn b-small" data-spawn="${kind}:${i}">${esc(p.spawn ? t('builder_spawn_move', null, 'Move spawn') : t('builder_spawn_set', null, 'Set spawn'))}</button>`)}</div>
            ${field(t('builder_vehicles', null, 'Vehicles (empty uses the config defaults)'), vehicleList(kind, i, p))}`;
        if (kind === 'equipment') return field(t('builder_equipment', null, 'Gives out'), `<select class="bl-in" data-k="${kind}" data-i="${i}" data-f="kind"><option value="stretcher" ${p.kind !== 'wheelchair' ? 'selected' : ''}>${esc(t('builder_stretcher', null, 'Stretcher'))}</option><option value="wheelchair" ${p.kind === 'wheelchair' ? 'selected' : ''}>${esc(t('builder_wheelchair', null, 'Wheelchair'))}</option></select>`);
        if (kind === 'elevator') return `<div class="bl-grid">${field(t('builder_group', null, 'Elevator name'), input(kind, i, 'group', p.group))}${field(t('builder_floor', null, 'Floor'), input(kind, i, 'floor', p.floor))}</div>`;
        if (kind === 'board') return `<div class="bl-grid">${field(t('builder_title_field', null, 'Title (empty uses the place name)'), input(kind, i, 'title', p.title))}${field(t('builder_width', null, 'Width (m)'), input(kind, i, 'width', p.width, 'number', 'step="0.1" min="0.2"'))}</div>
            ${field(t('builder_rooms', null, 'Rooms to list, comma separated (empty lists all)'), input(kind, i, 'rooms', XS.list(p.rooms).join(', ')))}`;
        if (kind === 'sign') return `<div class="bl-grid">${field(t('builder_room', null, 'Room'), input(kind, i, 'room', p.room))}${field(t('builder_width', null, 'Width (m)'), input(kind, i, 'width', p.width, 'number', 'step="0.05" min="0.2"'))}</div>`;
        if (kind === 'pharmacist') return field(t('builder_ped_pharmacist', null, 'Pharmacist model'), input(kind, i, 'ped', p.ped));
        return '';
    }

    function cardTitle(kind, p, i) {
        if (kind === 'bed') return (p.label || 'Bed') + (p.room ? ' · ' + p.room : '');
        if (kind === 'elevator') return p.group + ' · ' + p.floor;
        if (kind === 'sign') return p.room || t('point_sign', null, 'Door sign');
        if (kind === 'surgery') return p.room + ' · ' + p.label;
        const key = 'point_' + kind;
        return t(key, null, kind) + ' ' + (i + 1);
    }

    function editor() {
        const kinds = KINDS[current.kind] || KINDS.hospital;
        return `
            <div class="bl-head">
                ${field(t('builder_name', null, 'Name'), `<input class="bl-in" id="bl-name" style="width:260px" value="${esc(current.name)}">`)}
                ${field(t('builder_society', null, 'Pays into (empty uses config)'), `<input class="bl-in" id="bl-society" style="width:170px" value="${esc(current.society || '')}">`)}
                <label class="bl-check" style="margin-bottom:8px"><input type="checkbox" id="bl-blip" ${current.blip !== false ? 'checked' : ''}>${esc(t('builder_blip', null, 'Map blip'))}</label>
                <span class="bl-sp"></span><span class="bl-dirty" id="bl-dirty">${dirty ? esc(t('builder_unsaved', null, 'Unsaved changes')) : ''}</span>
                <button class="bl-btn b-go" id="bl-save">${esc(t('save', null, 'Save'))}</button>
                ${current.id ? `<button class="bl-btn b-danger" id="bl-delete">${esc(t('delete', null, 'Delete'))}</button>` : ''}
            </div>
            <div class="bl-body xsm-scroll">${kinds.map((kind) => {
                const list = XS.list(current.points[kind]);
                const wall = !!WALL[kind];
                return `<div class="bl-sec"><div class="bl-sec-h" data-sec="${kind}"><b>${esc(t(`point_${kind}`, null, kind))}</b><span>${esc(t(`point_${kind}_hint`, null, ''))}</span><em>${list.length}</em></div>
                    ${collapsed[kind] ? '' : `<div class="bl-points">${list.map((p, i) => `
                        <div class="bl-card"><div class="bl-card-h"><b>${esc(cardTitle(kind, p, i))}</b><small>${Number(p.x).toFixed(1)}, ${Number(p.y).toFixed(1)}</small></div>
                            ${cardFields(kind, p, i)}
                            <div class="bl-acts"><button class="bl-btn b-small" data-move="${kind}:${i}">${esc(t('builder_move', null, 'Move'))}</button>${wall ? '' : `<button class="bl-btn b-small" data-here="${kind}:${i}">${esc(t('builder_here', null, 'My spot'))}</button>`}<button class="bl-btn b-small" data-goto="${kind}:${i}">${esc(t('builder_goto', null, 'Go to'))}</button><button class="bl-btn b-small b-danger" data-del="${kind}:${i}">${esc(t('delete', null, 'Delete'))}</button></div>
                        </div>`).join('')}
                        <div class="bl-card" style="justify-content:center;align-items:flex-start"><div class="bl-acts">
                            <button class="bl-btn" data-add="${kind}">+ ${esc(wall ? t('builder_add_wall', null, 'Place on a wall') : t('builder_add', null, 'Place with camera'))}</button>
                            ${wall ? '' : `<button class="bl-btn" data-addhere="${kind}">+ ${esc(t('builder_add_here', null, 'At my spot'))}</button>`}
                        </div></div>
                    </div>`}</div>`;
            }).join('')}</div>`;
    }

    async function place(kind, existing, mode, extra) {
        if (busy) return null;
        busy = true;
        const wall = mode === 'wall';
        const res = await XS.rpc('builder:place', Object.assign({
            mode: wall ? 'wall' : 'point', label: t(`point_${kind}`, null, kind), origin: existing || null,
            width: existing && existing.width, screen: kind,
        }, extra || {}));
        busy = false;
        return res.ok ? res.data : null;
    }

    function bind(stage) {
        stage.querySelector('#bl-close').addEventListener('click', () => XS.close('builder'));
        stage.querySelectorAll('[data-new]').forEach((b) => b.addEventListener('click', () => {
            const kind = b.dataset.new;
            current = { id: null, kind, name: kind === 'pharmacy' ? t('builder_default_pharmacy', null, 'Pharmacy') : t('builder_default_hospital', null, 'Hospital'), blip: true, society: '', points: {} };
            (KINDS[kind] || []).forEach((k) => { current.points[k] = []; });
            dirty = true;
            select();
            render();
        }));
        stage.querySelectorAll('[data-id]').forEach((row) => row.addEventListener('click', () => {
            const found = places.find((p) => String(p.id) === row.dataset.id);
            if (!found) return;
            current = copy(found);
            (KINDS[current.kind] || KINDS.hospital).forEach((k) => { current.points[k] = XS.list(current.points[k]); });
            dirty = false;
            select();
            render();
        }));
        if (!current) return;
        const name = stage.querySelector('#bl-name');
        name.addEventListener('input', () => { current.name = name.value; markDirty(); });
        stage.querySelector('#bl-society').addEventListener('input', (e) => { current.society = e.target.value; markDirty(); });
        stage.querySelector('#bl-blip').addEventListener('change', (e) => { current.blip = e.target.checked; markDirty(); });
        stage.querySelector('#bl-save').addEventListener('click', save);
        const del = stage.querySelector('#bl-delete');
        if (del) del.addEventListener('click', async () => {
            if (!del.dataset.sure) { del.dataset.sure = '1'; del.textContent = t('builder_sure', null, 'Click again to delete'); return; }
            const res = await XS.rpc('builder:delete', { id: current.id });
            if (res.ok) {
                places = places.filter((p) => p.id !== current.id);
                current = null;
                dirty = false;
                render();
            }
        });
        stage.querySelectorAll('[data-sec]').forEach((h) => h.addEventListener('click', () => { collapsed[h.dataset.sec] = !collapsed[h.dataset.sec]; render(); }));
        stage.querySelectorAll('[data-f]').forEach((el) => {
            const update = () => {
                const p = current.points[el.dataset.k][Number(el.dataset.i)];
                if (!p) return;
                const f = el.dataset.f;
                if (el.type === 'checkbox') p[f] = el.checked;
                else if (el.type === 'number') p[f] = Number(el.value);
                else if (f === 'rooms') p[f] = el.value.split(',').map((s) => s.trim()).filter(Boolean);
                else if (f === 'prop') p[f] = el.value.trim() === '' ? false : el.value.trim();
                else p[f] = el.value;
                markDirty();
            };
            el.addEventListener(el.tagName === 'SELECT' || el.type === 'checkbox' ? 'change' : 'input', update);
        });
        stage.querySelectorAll('[data-veh]').forEach((el) => el.addEventListener('change', () => {
            const p = current.points[el.dataset.k][Number(el.dataset.i)];
            const list = new Set(XS.list(p.vehicles));
            if (el.checked) list.add(el.dataset.veh); else list.delete(el.dataset.veh);
            p.vehicles = Array.from(list);
            markDirty();
        }));
        stage.querySelectorAll('[data-vf]').forEach((el) => el.addEventListener('input', () => {
            vehFilter[el.dataset.vf] = el.value;
            const pos = el.selectionStart;
            render();
            const again = root.querySelector(`[data-vf="${el.dataset.vf}"]`);
            if (again) { again.focus(); again.setSelectionRange(pos, pos); }
        }));
        stage.querySelectorAll('[data-add]').forEach((b) => b.addEventListener('click', async () => {
            const kind = b.dataset.add;
            const pos = await place(kind, null, WALL[kind] ? 'wall' : 'point');
            if (!pos) return;
            current.points[kind].push(blankPoint(kind, pos));
            markDirty();
            select();
            render();
        }));
        stage.querySelectorAll('[data-addhere]').forEach((b) => b.addEventListener('click', async () => {
            const kind = b.dataset.addhere;
            const res = await XS.rpc('builder:here', {});
            if (!res.ok) return;
            current.points[kind].push(blankPoint(kind, res.data));
            markDirty();
            select();
            render();
        }));
        stage.querySelectorAll('[data-move]').forEach((b) => b.addEventListener('click', async () => {
            const [kind, i] = b.dataset.move.split(':');
            const p = current.points[kind][Number(i)];
            const pos = await place(kind, p, WALL[kind] ? 'wall' : 'point');
            if (!pos) return;
            Object.assign(p, { x: pos.x, y: pos.y, z: pos.z, w: pos.w });
            if (WALL[kind] && pos.width) p.width = Math.round(pos.width * 100) / 100;
            if (kind === 'bed' && pos.snapped) p.prop = false;
            markDirty();
            select();
            render();
        }));
        stage.querySelectorAll('[data-here]').forEach((b) => b.addEventListener('click', async () => {
            const [kind, i] = b.dataset.here.split(':');
            const res = await XS.rpc('builder:here', {});
            if (!res.ok) return;
            Object.assign(current.points[kind][Number(i)], { x: res.data.x, y: res.data.y, z: res.data.z, w: res.data.w });
            markDirty();
            select();
            render();
        }));
        stage.querySelectorAll('[data-goto]').forEach((b) => b.addEventListener('click', () => {
            const [kind, i] = b.dataset.goto.split(':');
            XS.rpc('builder:goto', current.points[kind][Number(i)]);
        }));
        stage.querySelectorAll('[data-del]').forEach((b) => b.addEventListener('click', () => {
            const [kind, i] = b.dataset.del.split(':');
            current.points[kind].splice(Number(i), 1);
            markDirty();
            select();
            render();
        }));
        stage.querySelectorAll('[data-spawn]').forEach((b) => b.addEventListener('click', async () => {
            const [kind, i] = b.dataset.spawn.split(':');
            const p = current.points[kind][Number(i)];
            const model = XS.list(p.vehicles)[0] || (kind === 'helipad' ? 'polmav' : 'ambulance');
            const pos = await place(kind, p.spawn || p, 'point', { previewModel: model, previewVehicle: true, label: t('builder_spawn', null, 'Spawn spot') });
            if (!pos) return;
            p.spawn = { x: pos.x, y: pos.y, z: pos.z, w: pos.w };
            markDirty();
            render();
        }));
        stage.querySelectorAll('[data-mon]').forEach((b) => b.addEventListener('click', async () => {
            const i = Number(b.dataset.mon);
            const bed = current.points.bed[i];
            const pos = await place('monitor', bed.monitor || null, 'wall', { screen: 'monitor', label: t('builder_monitor', null, 'Bedside monitor'), width: (bed.monitor && bed.monitor.width) || 0.55 });
            if (!pos) return;
            bed.monitor = { x: pos.x, y: pos.y, z: pos.z, w: pos.w, width: Math.round((pos.width || 0.55) * 100) / 100 };
            markDirty();
            render();
        }));
        stage.querySelectorAll('[data-monrm]').forEach((b) => b.addEventListener('click', () => {
            delete current.points.bed[Number(b.dataset.monrm)].monitor;
            markDirty();
            render();
        }));
    }

    async function save() {
        if (busy || !current) return;
        busy = true;
        const res = await XS.rpc('builder:save', current);
        busy = false;
        if (!res.ok) { XS.toast(res.error, 'error'); return; }
        const saved = res.data;
        const idx = places.findIndex((p) => p.id === saved.id);
        if (idx >= 0) places[idx] = saved; else places.push(saved);
        current = copy(saved);
        (KINDS[current.kind] || KINDS.hospital).forEach((k) => { current.points[k] = XS.list(current.points[k]); });
        dirty = false;
        XS.toast(t('saved', null, 'Saved.'), 'ok');
        render();
    }

    XS.apps.builder = {
        isOpen: () => open,
        escape: () => XS.close('builder'),
        on(action, data) {
            if (action === 'open') {
                places = XS.list(data.places);
                vehicles = XS.list(data.vehicles);
                defaults = Object.assign({}, data.peds || {}, { bedProp: data.bedProp });
                open = true;
                XS.show('xsm-builder', true);
                render();
            } else if (action === 'hide') {
                XS.show('xsm-builder', false);
            } else if (action === 'show') {
                XS.show('xsm-builder', true);
            } else if (action === 'close') {
                open = false;
                XS.show('xsm-builder', false);
            }
        },
    };
})();
