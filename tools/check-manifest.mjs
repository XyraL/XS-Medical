import { readFileSync, readdirSync, statSync, existsSync } from 'node:fs';
import path from 'node:path';
import { fileURLToPath } from 'node:url';

const ROOT = path.resolve(path.dirname(fileURLToPath(import.meta.url)), '..');
const manifest = readFileSync(path.join(ROOT, 'fxmanifest.lua'), 'utf8');

function block(name) {
    const m = manifest.match(new RegExp(`${name}\\s*\\{([\\s\\S]*?)\\}`));
    return m ? [...m[1].matchAll(/['"]([^'"]+)['"]/g)].map((x) => x[1]) : [];
}

function walk(dir, out = []) {
    const full = path.join(ROOT, dir);
    if (!existsSync(full)) return out;
    for (const name of readdirSync(full)) {
        const rel = `${dir}/${name}`;
        if (statSync(path.join(ROOT, rel)).isDirectory()) walk(rel, out);
        else out.push(rel);
    }
    return out;
}

const glob = (pattern) => new RegExp(`^${pattern.replace(/[.+^${}()|[\]\\]/g, '\\$&').replace(/\*\*/g, '::').replace(/\*/g, '[^/]*').replace(/::/g, '.*')}$`);

const scripts = [...block('shared_scripts'), ...block('client_scripts'), ...block('server_scripts')].filter((f) => !f.startsWith('@'));
const files = block('files');
const problems = [];

for (const f of scripts) if (!existsSync(path.join(ROOT, f))) problems.push(`${f} is in the manifest but not on disk`);

const lua = ['bridge', 'client', 'server', 'shared', 'locales'].flatMap((d) => walk(d)).filter((f) => f.endsWith('.lua'));
lua.push('config.lua');
for (const f of lua) if (!scripts.includes(f)) problems.push(`${f} is on disk but never loaded by the manifest`);

const ui = (manifest.match(/ui_page\s+['"]([^'"]+)['"]/) || [])[1];
if (!ui || !existsSync(path.join(ROOT, ui))) problems.push('ui_page is missing');
const html = ui ? readFileSync(path.join(ROOT, ui), 'utf8') : '';
const refs = [...html.matchAll(/(?:src|href)="([^"]+)"/g)].map((m) => m[1]).filter((r) => !/^(https?:)?\/\//.test(r));
const covered = (rel) => files.some((p) => glob(p).test(rel));
for (const r of refs) {
    const rel = path.posix.join(path.posix.dirname(ui), r);
    if (!existsSync(path.join(ROOT, rel))) problems.push(`${ui} loads ${r}, which does not exist`);
    else if (!covered(rel)) problems.push(`${rel} is loaded by the page but not listed in files`);
}
for (const f of walk('html')) if (!covered(f) && !f.endsWith('.md')) problems.push(`${f} is in html/ but not in files, so players never get it`);

if (problems.length) {
    console.error(`check-manifest — ${problems.length} problem(s)`);
    for (const p of problems) console.error(`  ${p}`);
    process.exit(1);
}
console.log(`check-manifest ok — ${scripts.length} scripts loaded, ${refs.length} page files covered`);
