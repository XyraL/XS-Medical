const RESOURCE = (typeof GetParentResourceName === 'function') ? GetParentResourceName() : 'XS-Medical';

const XS = {
    apps: {},
    T: {},
    config: {},
    open: new Set(),
};
window.XS = XS;

XS.esc = function esc(value) {
    if (value === null || value === undefined) return '';
    return String(value).replace(/&/g, '&amp;').replace(/</g, '&lt;').replace(/>/g, '&gt;').replace(/"/g, '&quot;').replace(/'/g, '&#39;');
};

XS.t = function t(key, vars, fallback) {
    let s = XS.T[key] || fallback || key;
    if (vars) Object.keys(vars).forEach((k) => { s = s.split(`%{${k}}`).join(vars[k]); });
    return s;
};

XS.fix = function fix(value) {
    if (Array.isArray(value)) return value.map(fix);
    if (value && typeof value === 'object') {
        const keys = Object.keys(value);
        if (keys.length === 0) return [];
        const out = {};
        keys.forEach((k) => { out[k] = fix(value[k]); });
        return out;
    }
    return value;
};

XS.list = function list(value) {
    if (Array.isArray(value)) return value;
    if (value && typeof value === 'object') return Object.values(value);
    return [];
};

XS.post = async function post(endpoint, payload) {
    try {
        const res = await fetch(`https://${RESOURCE}/${endpoint}`, {
            method: 'POST', headers: { 'Content-Type': 'application/json' }, body: JSON.stringify(payload || {}),
        });
        return XS.fix(await res.json());
    } catch (e) {
        return null;
    }
};

XS.rpc = async function rpc(name, payload) {
    const res = await XS.post('rpc', { name, payload: payload || {} });
    if (!res) return { ok: false, error: XS.t('err_failed', null, 'That did not go through.') };
    return res;
};

XS.close = function close(app) {
    XS.post('close', { app });
};

XS.clock = function clock(seconds) {
    const s = Math.max(0, Math.floor(Number(seconds) || 0));
    return `${String(Math.floor(s / 60)).padStart(2, '0')}:${String(s % 60).padStart(2, '0')}`;
};

XS.ago = function ago(ts) {
    if (!ts) return '';
    const s = Math.max(0, Math.floor(Date.now() / 1000 - Number(ts)));
    if (s < 60) return XS.t('ago_now', null, 'just now');
    if (s < 3600) return XS.t('ago_min', { n: Math.floor(s / 60) }, `${Math.floor(s / 60)}m ago`);
    return XS.t('ago_hour', { n: Math.floor(s / 3600) }, `${Math.floor(s / 3600)}h ago`);
};

XS.time = function time(ts) {
    if (!ts) return '';
    const d = new Date(Number(ts) > 1e12 ? Number(ts) : Number(ts) * 1000);
    return `${String(d.getHours()).padStart(2, '0')}:${String(d.getMinutes()).padStart(2, '0')}`;
};

XS.date = function date(ts) {
    if (!ts) return '';
    const d = new Date(typeof ts === 'number' ? (ts > 1e12 ? ts : ts * 1000) : ts);
    if (Number.isNaN(d.getTime())) return String(ts);
    return `${d.getFullYear()}-${String(d.getMonth() + 1).padStart(2, '0')}-${String(d.getDate()).padStart(2, '0')} ${String(d.getHours()).padStart(2, '0')}:${String(d.getMinutes()).padStart(2, '0')}`;
};

XS.accent = function accent(colour) {
    const hex = String(colour || '').trim();
    if (!/^#[0-9a-f]{6}$/i.test(hex)) return;
    const n = parseInt(hex.slice(1), 16);
    const lum = (0.299 * (n >> 16) + 0.587 * ((n >> 8) & 255) + 0.114 * (n & 255)) / 255;
    document.documentElement.style.setProperty('--x-accent', hex);
    document.documentElement.style.setProperty('--x-ink', lum > 0.5 ? '#0b0b0d' : '#ffffff');
};

XS.toast = function toast(text, kind) {
    if (!text) return;
    const box = document.getElementById('xsm-toastbox');
    const el = document.createElement('div');
    el.className = `xsm-toast ${kind === 'error' ? 't-err' : (kind === 'ok' ? 't-ok' : '')}`;
    el.textContent = text;
    box.appendChild(el);
    setTimeout(() => el.remove(), 3800);
};

XS.stage = function stage(root, cls) {
    root.innerHTML = `<div class="xsm-stage ${cls || ''}"></div>`;
    return root.firstElementChild;
};

XS.show = function show(id, on) {
    const el = document.getElementById(id);
    if (el) el.classList.toggle('xsm-hidden', !on);
};

XS.part = (part) => XS.t(`part_${part}`, null, part);
XS.kind = (kind) => XS.t(`kind_${kind}`, null, kind);

XS.describe = function describe(injury) {
    const bits = [XS.kind(injury.kind)];
    if (injury.bleed >= 3) bits.push(XS.t('inj_bleed_3', null, 'bleeding badly'));
    else if (injury.bleed === 2) bits.push(XS.t('inj_bleed_2', null, 'bleeding heavily'));
    else if (injury.bleed === 1) bits.push(XS.t('inj_bleed_1', null, 'bleeding'));
    if (injury.fracture) bits.push(injury.treated && injury.treated.splint ? XS.t('inj_splinted', null, 'splinted') : XS.t('inj_broken', null, 'broken'));
    if (injury.bulletIn) bits.push(XS.t('inj_bullet_in', null, 'bullet still in'));
    if (injury.internal) bits.push(XS.t('inj_internal', null, 'internal bleeding'));
    if (injury.infected) bits.push(XS.t('inj_infected', null, 'infected'));
    if (injury.treated && injury.treated.tourniquet) bits.push(XS.t('inj_tourniquet', null, 'tourniquet on'));
    return bits.join(' · ');
};

XS.needs = function needs(injury) {
    const out = [];
    const t = injury.treated || {};
    const limb = ['larm', 'rarm', 'lleg', 'rleg'].includes(injury.part);
    const raw = injury.rawBleed !== undefined && injury.rawBleed !== null ? injury.rawBleed : injury.bleed;
    if (raw > 0 && !(t.tourniquet && (t.bandage || t.gauze))) {
        if (injury.bleed >= 2 && limb && !t.tourniquet) out.push('tourniquet');
        if (['gunshot', 'stab', 'cut', 'crush'].includes(injury.kind) && !t.bandage) out.push('bandage');
        if (!t.gauze) out.push('gauze');
    }
    if (injury.fracture && limb && !t.splint) out.push('splint');
    if (injury.kind === 'burn' && !t.dressing) out.push('burncream');
    if (injury.surgery) out.push('surgery');
    if (injury.infected) out.push('antibiotics');
    return out;
};

function scale() {
    const s = Math.min(window.innerWidth / 1600, window.innerHeight / 900);
    document.documentElement.style.setProperty('--xsm-s', String(s));
}
window.addEventListener('resize', scale);
scale();

window.addEventListener('message', (event) => {
    const msg = event.data;
    if (!msg || typeof msg !== 'object' || !msg.app) return;
    const data = XS.fix(msg.data || {});
    if (msg.app === 'core' && msg.action === 'boot') {
        XS.T = data.locale || {};
        XS.config = data.config || {};
        XS.accent(XS.config.accent);
        Object.values(XS.apps).forEach((app) => { if (app.boot) app.boot(); });
        return;
    }
    const app = XS.apps[msg.app];
    if (app && app.on) app.on(msg.action, data);
});

window.addEventListener('keydown', (e) => {
    if (e.key !== 'Escape') return;
    const order = ['menu', 'self', 'pharmacy', 'surgery', 'tablet', 'builder'];
    for (const name of order) {
        const app = XS.apps[name];
        if (app && app.isOpen && app.isOpen() && app.escape) { app.escape(); break; }
    }
});

window.addEventListener('load', () => { XS.post('ready', {}); });
