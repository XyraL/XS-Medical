// Every rpc the page makes has a UI.Handle on the client, and every UI.Send the
// client makes lands on an app that handles that action.
//
//   node tools/check-nui.mjs
import { readFileSync, readdirSync } from 'node:fs';
import path from 'node:path';
import { fileURLToPath } from 'node:url';

const ROOT = path.resolve(path.dirname(fileURLToPath(import.meta.url)), '..');
const read = (rel) => readFileSync(path.join(ROOT, rel), 'utf8');
const list = (dir, ext) => readdirSync(path.join(ROOT, dir)).filter((n) => n.endsWith(ext)).map((n) => `${dir}/${n}`);

const js = list('html/js', '.js').filter((f) => !f.endsWith('mock.js'));
const client = list('client', '.lua');

const called = new Map();
const apps = new Map();
for (const file of js) {
    const src = read(file);
    for (const m of src.matchAll(/XS\.rpc\(\s*['"`]([\w:]+)['"`]/g)) called.set(m[1], file);
    if (file.endsWith('tablet.js')) for (const m of src.matchAll(/\bcall\(\s*['"`](\w+)['"`]/g)) called.set(`tablet:${m[1]}`, file);
    for (const m of src.matchAll(/XS\.apps\.(\w+)\s*=/g)) apps.set(m[1], src);
}

const registered = new Map();
const sent = [];
for (const file of client) {
    const src = read(file);
    for (const m of src.matchAll(/UI\.Handle\(\s*['"]([\w:]+)['"]/g)) {
        if (registered.has(m[1])) {
            console.error(`check-nui — ${m[1]} handled twice (${registered.get(m[1])} and ${file})`);
            process.exit(1);
        }
        registered.set(m[1], file);
    }
    const relay = src.match(/local RELAY = \{([\s\S]*?)\n\}/);
    if (relay) for (const m of relay[1].matchAll(/(\w+)\s*=\s*'/g)) registered.set(`tablet:${m[1]}`, file);
    for (const m of src.matchAll(/UI\.Send\(\s*['"](\w+)['"]\s*,\s*['"](\w+)['"]/g)) sent.push({ app: m[1], action: m[2], file });
}

const problems = [];
for (const [name, file] of called) if (!registered.has(name)) problems.push(`${file} calls ${name}, which no client file handles`);
for (const { app, action, file } of sent) {
    const src = apps.get(app);
    if (!src) { problems.push(`${file} sends to app ${app}, which the page does not have`); continue; }
    if (!src.includes(`'${action}'`)) problems.push(`${file} sends ${app}/${action}, which that app never handles`);
}

if (problems.length) {
    console.error(`check-nui — ${problems.length} problem(s)`);
    for (const p of problems) console.error(`  ${p}`);
    process.exit(1);
}
const unused = [...registered.keys()].filter((n) => !called.has(n));
console.log(`check-nui ok — ${called.size} calls answered, ${sent.length} messages handled${unused.length ? `, handled but never called: ${unused.join(' ')}` : ''}`);
