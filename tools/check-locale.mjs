import { readFileSync, readdirSync, statSync } from 'node:fs';
import path from 'node:path';
import { fileURLToPath } from 'node:url';

const ROOT = path.resolve(path.dirname(fileURLToPath(import.meta.url)), '..');
const read = (rel) => readFileSync(path.join(ROOT, rel), 'utf8');

function walk(dir, ext, out = []) {
    for (const name of readdirSync(path.join(ROOT, dir))) {
        const rel = `${dir}/${name}`;
        if (statSync(path.join(ROOT, rel)).isDirectory()) walk(rel, ext, out);
        else if (name.endsWith(ext)) out.push(rel);
    }
    return out;
}

const keys = new Set([...read('locales/en.lua').matchAll(/^\s*([A-Za-z0-9_]+)\s*=\s*['"]/gm)].map((m) => m[1]));
const lua = ['bridge', 'client', 'server', 'shared'].flatMap((d) => walk(d, '.lua'));
const js = walk('html/js', '.js');

const missing = [];
const used = new Set();
const need = (key, where) => {
    used.add(key);
    if (!keys.has(key)) missing.push(`${key}  (${where})`);
};
const prefixes = [];

for (const file of lua) {
    const src = read(file);
    for (const m of src.matchAll(/\bText\(\s*['"]([A-Za-z0-9_]+)['"]\s*([,)])/g)) need(m[1], file);
    for (const m of src.matchAll(/\bText\(\s*['"]([A-Za-z0-9_]+)['"]\s*\.\./g)) prefixes.push([m[1], file]);
    for (const m of src.matchAll(/reason\s*=\s*['"]([a-z_]+)['"]/g)) need(`err_${m[1]}`, file);
    for (const m of src.matchAll(/return nil, ['"]([a-z_]+)['"]/g)) need(`err_${m[1]}`, file);
}

for (const file of js) {
    const src = read(file);
    for (const m of src.matchAll(/\bt\(\s*'([A-Za-z0-9_]+)'/g)) need(m[1], file);
    for (const m of src.matchAll(/\btn\(\s*'([A-Za-z0-9_]+)'/g)) {
        need(m[1], file);
        need(`${m[1]}_one`, file);
    }
    for (const m of src.matchAll(/\bt\(\s*`([A-Za-z0-9_]+)\$\{/g)) prefixes.push([m[1], file]);
    for (const m of src.matchAll(/\[\s*'[a-z]+'\s*,\s*'(ui_[A-Za-z0-9_]+)'/g)) need(m[1], file);
}

const deadPrefix = prefixes.filter(([p]) => ![...keys].some((k) => k.startsWith(p)));
for (const [p] of prefixes) for (const k of keys) if (k.startsWith(p)) used.add(k);

const unused = [...keys].filter((k) => k.startsWith('ui_') && !used.has(k));

if (missing.length || deadPrefix.length) {
    console.error(`check-locale — ${missing.length} missing key(s), ${deadPrefix.length} dead prefix(es)`);
    for (const m of [...new Set(missing)].sort()) console.error(`  missing ${m}`);
    for (const [p, f] of deadPrefix) console.error(`  no key starts with ${p}  (${f})`);
    process.exit(1);
}
console.log(`check-locale ok — ${used.size} keys used, ${keys.size} defined${unused.length ? `, ${unused.length} ui keys unused: ${unused.join(' ')}` : ''}`);
