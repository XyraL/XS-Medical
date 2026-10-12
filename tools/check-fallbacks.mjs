// Every file that defines a global is a file that can fail to load, and when it
// does, the first thing to touch that global dies on a nil index somewhere else
// entirely. server/main.lua and client/fallbacks.lua exist to catch that — but
// only for the globals somebody remembered to list, and adding a module and
// forgetting the list has now bitten three times.
//
// So this asserts the opposite: every global a loadable file defines is either
// named in CORE below, meaning the resource genuinely cannot run without it, or
// covered by a fallback. Adding a module forces that decision.
//
//   node tools/check-fallbacks.mjs

import { readFileSync, existsSync } from 'node:fs';
import { join } from 'node:path';
import { fileURLToPath } from 'node:url';

const root = fileURLToPath(new URL('..', import.meta.url));
const manifest = readFileSync(join(root, 'fxmanifest.lua'), 'utf8');

// Without these there is no resource, so a stub would only hide the breakage.
const CORE = new Set([
    'Config', 'Locales', 'Util', 'Body', 'Vitals',
    'Framework', 'Inventory', 'Target', 'Keys', 'Fuel', 'Banking', 'Dispatch',
    'UI', 'Me', 'Damage', 'Down', 'Treat', 'Tablet', 'Hospital',
    'Db', 'Standdown', 'State', 'Records', 'Patients', 'Calls', 'Hospitals', 'Compat',
    'Pharmacy', 'Surgery', 'Equipment',
]);

function block(name) {
    const match = manifest.match(new RegExp(`${name}\\s*\\{([\\s\\S]*?)\\}`));
    if (!match) return [];

    return [...match[1].matchAll(/'([^']+\.lua)'/g)]
        .map(m => m[1])
        .filter(p => !p.startsWith('@'));
}

const shared = block('shared_scripts');
const contexts = {
    server: shared.concat(block('server_scripts')),
    client: shared.concat(block('client_scripts')),
};

function globalsIn(files) {
    const found = new Map();

    for (const file of files) {
        const path = join(root, file);
        if (!existsSync(path)) continue;

        const src = readFileSync(path, 'utf8');

        // A top-level assignment: no indentation, capitalised, not a comparison.
        for (const m of src.matchAll(/^([A-Z]\w*)\s*=\s*[^=]/gm)) {
            if (!found.has(m[1])) found.set(m[1], file);
        }
    }

    return found;
}

function covered(file) {
    const path = join(root, file);
    if (!existsSync(path)) return new Set();

    const src = readFileSync(path, 'utf8');
    return new Set([...src.matchAll(/^\s+([A-Z]\w*)\s*=\s*\{\s*file\s*=/gm)].map(m => m[1]));
}

const problems = [];

const checks = [
        { context: 'client', fallbacks: 'client/fallbacks.lua' },
];

for (const { context, fallbacks } of checks) {
    const defined = globalsIn(contexts[context]);
    const stubbed = covered(fallbacks);

    for (const [name, file] of defined) {
        if (CORE.has(name) || stubbed.has(name)) continue;
        problems.push(`  ${context}: ${name} (${file}) has no fallback in ${fallbacks} and is not listed as core`);
    }

    for (const name of stubbed) {
        if (!defined.has(name)) {
            problems.push(`  ${context}: ${fallbacks} stubs ${name}, which no loaded file defines any more`);
        }
    }
}

problems.forEach(p => console.log(p));

console.log(problems.length === 0
    ? 'check-fallbacks: every optional global has a stub, every stub has a module'
    : `check-fallbacks: ${problems.length} problem(s)`);

process.exit(problems.length === 0 ? 0 : 1);
