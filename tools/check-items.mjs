// ox_inventory validates every `client = { export = ... }` while it reads its
// item list, so a missing or wrongly-sided export fails at STARTUP with
// "No such export" — before anyone has used anything.
//
// The side matters and is easy to get wrong: `client.export` is called on the
// CLIENT. Registering it on the server looks right, loads fine on our side,
// and breaks ox.
import { readFileSync, readdirSync, statSync, existsSync } from 'node:fs';
import path from 'node:path';
import { fileURLToPath } from 'node:url';

const ROOT = path.resolve(path.dirname(fileURLToPath(import.meta.url)), '..');
const manifest = readFileSync(path.join(ROOT, 'fxmanifest.lua'), 'utf8');
const config = readFileSync(path.join(ROOT, 'config.lua'), 'utf8');

function block(name) {
    const found = manifest.match(new RegExp(`${name}\\s*\\{([\\s\\S]*?)\\n\\}`, 'm'));
    if (!found) return [];

    return [...found[1].matchAll(/['"]([^'"]+)['"]/g)]
        .map((m) => m[1])
        .filter((entry) => !entry.startsWith('@') && entry.endsWith('.lua'));
}

// The repair kits are registered in a loop over Config.Repair.kits, so the
// export names only exist once the config keys are expanded.
function kitNames() {
    const kits = config.match(/kits\s*=\s*\{([\s\S]*?)\n    \},/m);
    if (!kits) return [];

    return [...kits[1].matchAll(/^\s{8}([a-z0-9_]+)\s*=\s*\{/gm)].map((m) => m[1]);
}

// And the parts, registered in a loop over Parts.Installable(). That list is
// built from two config tables and the tuning catalogue, so the export names
// only exist once all three are expanded — the same shape as the kits above.
function installableNames() {
    const names = new Set();

    for (const table of ['categoryItems', 'slotItems']) {
        const found = config.match(new RegExp(table + String.raw`\s*=\s*\{([\s\S]*?)\n    \},`, 'm'));
        if (!found) continue;

        for (const m of found[1].matchAll(/=\s*'([a-z0-9_]+)'/g)) names.add(m[1]);
    }

    const tuning = readFileSync(path.join(ROOT, 'shared/tuning.lua'), 'utf8');
    for (const m of tuning.matchAll(/item\s*=\s*'([a-z0-9_]+)'/g)) names.add(m[1]);

    return [...names];
}

function exportsIn(files) {
    const found = new Set();

    for (const file of files) {
        const full = path.join(ROOT, file);
        if (!existsSync(full)) continue;

        const src = readFileSync(full, 'utf8');

        for (const m of src.matchAll(/exports\(\s*['"]([a-zA-Z0-9_]+)['"]/g)) {
            found.add(m[1]);
        }

        // exports(('use_%s'):format(item), ...) inside the kit loop.
        if (/exports\(\(\s*['"]use_%s['"]\s*\)\s*:format\(item\)/.test(src)) {
            for (const kit of kitNames()) found.add(`use_${kit}`);
        }

        // exports(('fit_%s'):format(item), ...) inside the parts loop.
        if (/exports\(\(\s*['"]fit_%s['"]\s*\)\s*:format\(item\)/.test(src)) {
            for (const part of installableNames()) found.add(`fit_${part}`);
        }
    }

    return found;
}

const clientExports = exportsIn(block('client_scripts'));
const serverExports = exportsIn(block('server_scripts'));

const itemsPath = path.join(ROOT, 'items/ox_inventory.lua');
const problems = [];

if (!existsSync(itemsPath)) {
    problems.push('items/ox_inventory.lua is missing');
} else {
    const items = readFileSync(itemsPath, 'utf8');
    const required = [];

    // Walk each item entry so a failure can name the item, not just the export.
    for (const entry of items.split(/^\['/m).slice(1)) {
        const id = entry.slice(0, entry.indexOf("'"));
        const found = entry.match(/export\s*=\s*['"]XS-Medical\.([a-zA-Z0-9_]+)['"]/);
        if (found) required.push({ id, fn: found[1] });
    }

    if (required.length === 0) {
        problems.push('no client exports declared in items/ox_inventory.lua — the usable items will do nothing');
    }

    for (const { id, fn } of required) {
        if (clientExports.has(fn)) continue;

        if (serverExports.has(fn)) {
            problems.push(`'${id}' points at XS-Medical.${fn}, which is registered on the SERVER — ox calls client.export on the CLIENT`);
        } else {
            problems.push(`'${id}' points at XS-Medical.${fn}, which nothing registers`);
        }
    }

    // A usable item with no export is the silent half of the same bug. Each
    // entry is compared against its OWN text — a regex that runs on past the
    // entry finds the next usable item's flag and blames everything above it.
    const qbEntries = new Map();

    for (const entry of readFileSync(path.join(ROOT, 'items/qb_core.lua'), 'utf8').split(/^\['/m).slice(1)) {
        qbEntries.set(entry.slice(0, entry.indexOf("'")), entry);
    }

    for (const entry of items.split(/^\['/m).slice(1)) {
        const id = entry.slice(0, entry.indexOf("'"));
        const qb = qbEntries.get(id);

        if (qb && /useable\s*=\s*true/.test(qb) && !/export\s*=/.test(entry)) {
            problems.push(`'${id}' is useable in the qb block but has no client export in the ox block`);
        }
    }
}

if (problems.length) {
    console.log('check-items FAILED');
    for (const problem of problems) console.log(`  ${problem}`);
    process.exit(1);
}

console.log(`check-items ok — every ox client export is registered client side`);
