/**
 * The generator's command-line entry point.
 *
 * Writing lives here rather than in `generate.ts` so that importing the package never
 * has a side effect. The scenario imports the index to read the entries; if that import
 * also rewrote the committed manifest, the determinism assertion would be comparing the
 * file against itself and every read would be a write.
 *
 * `--out <path>` writes elsewhere, which is how the determinism check gets a second copy
 * without ever touching the tracked manifest.
 */
import { MARKETPLACE_PATH, writeMarketplace } from './generate.js';

const flag = process.argv.indexOf('--out');
const requested = flag === -1 ? MARKETPLACE_PATH : process.argv[flag + 1];

if (!requested) {
  process.stderr.write('--out needs a path\n');
  process.exit(2);
}

const to = requested;
const serialized = writeMarketplace({ to });

process.stdout.write(`wrote ${to} (${serialized.length} bytes)\n`);
