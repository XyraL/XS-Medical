import { spawnSync } from 'node:child_process';
import path from 'node:path';
import { fileURLToPath } from 'node:url';

const HERE = path.dirname(fileURLToPath(import.meta.url));
const ROOT = path.resolve(HERE, '..');
const CHECKS = ['check-lua.mjs', 'check-manifest.mjs', 'check-events.mjs', 'check-dupes.mjs', 'check-nui.mjs', 'check-locale.mjs', 'check-globals.mjs', 'check-escaping.mjs', 'check-html.mjs', 'check-items.mjs', 'check-netids.mjs', 'check-runtime.mjs', 'check-fallbacks.mjs'];

let failed = 0;
for (const check of CHECKS) {
    const run = spawnSync(process.execPath, [path.join(HERE, check)], { cwd: ROOT, encoding: 'utf8' });
    process.stdout.write(run.stdout || '');
    process.stderr.write(run.stderr || '');
    if (run.status !== 0) failed += 1;
}

if (failed) {
    console.log(`\n${failed} check(s) failed.`);
    process.exit(1);
}
console.log('\nall checks passed.');
