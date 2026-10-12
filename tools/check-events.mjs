import { readFileSync } from 'node:fs';
import path from 'node:path';
import { fileURLToPath } from 'node:url';

const ROOT = path.resolve(path.dirname(fileURLToPath(import.meta.url)), '..');
const manifest = readFileSync(path.join(ROOT, 'fxmanifest.lua'), 'utf8');

function block(name) {
    const m = manifest.match(new RegExp(`${name}\\s*\\{([\\s\\S]*?)\\}`));
    return m ? [...m[1].matchAll(/['"]([^'"]+)['"]/g)].map((x) => x[1]).filter((f) => !f.startsWith('@')) : [];
}

const shared = block('shared_scripts');
const sides = { client: [...shared, ...block('client_scripts')], server: [...shared, ...block('server_scripts')] };
const KINDS = [
    ['net event', /RegisterNetEvent\(\s*['"]([^'"]+)['"]\s*,/g],
    ['callback', /lib\.callback\.register\(\s*['"]([^'"]+)['"]/g],
    ['command', /RegisterCommand\(\s*['"]([^'"]+)['"]/g],
    ['export', /\bexports\(\s*['"]([^'"]+)['"]/g],
];

const problems = [];
let total = 0;
for (const [side, files] of Object.entries(sides)) {
    for (const [kind, re] of KINDS) {
        const seen = new Map();
        for (const file of files) {
            const src = readFileSync(path.join(ROOT, file), 'utf8');
            for (const m of src.matchAll(re)) {
                total += 1;
                if (seen.has(m[1])) problems.push(`${side} ${kind} ${m[1]} is registered in ${seen.get(m[1])} and ${file}`);
                else seen.set(m[1], file);
            }
        }
    }
}

if (problems.length) {
    console.error(`check-events — ${problems.length} duplicate(s)`);
    for (const p of problems) console.error(`  ${p}`);
    process.exit(1);
}
console.log(`check-events ok — ${total} registrations, no duplicates on either side`);
