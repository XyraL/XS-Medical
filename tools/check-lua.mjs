import { readFileSync, readdirSync, statSync } from 'node:fs';
import { createRequire } from 'node:module';
import path from 'node:path';
import { fileURLToPath } from 'node:url';

const ROOT = path.resolve(path.dirname(fileURLToPath(import.meta.url)), '..');
const require = createRequire(import.meta.url);

let luaparse;
try {
    luaparse = require('luaparse');
} catch {
    console.error('check-lua needs luaparse: npm install --no-save luaparse');
    process.exit(1);
}

const files = [];
(function walk(dir) {
    for (const name of readdirSync(dir)) {
        if (['node_modules', '.git', 'html', 'tools', 'items'].includes(name)) continue;
        const full = path.join(dir, name);
        if (statSync(full).isDirectory()) walk(full);
        else if (name.endsWith('.lua')) files.push(full);
    }
})(ROOT);

let bad = 0;
for (const file of files) {
    const src = readFileSync(file, 'utf8').replace(/`[^`\n]*`/g, '0');
    try {
        luaparse.parse(src, { luaVersion: '5.3', comments: false });
    } catch (e) {
        bad += 1;
        console.error(`  ${path.relative(ROOT, file)} line ${e.line || '?'}: ${e.message.replace(/^\[.*?\]\s*/, '')}`);
    }
}

if (bad) {
    console.error(`check-lua — ${bad} of ${files.length} files do not parse`);
    process.exit(1);
}
console.log(`check-lua ok — ${files.length} files parse`);
