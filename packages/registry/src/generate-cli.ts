/**
 * The generator's command-line entry point.
 *
 * Writing lives here rather than in `generate.ts` so that importing the package never
 * has a side effect. The scenario imports the index to read the entries; if that import
 * also rewrote the committed manifest, the determinism assertion would be comparing the
 * file against itself and every read would be a write.
 */
import { MARKETPLACE_PATH, writeMarketplace } from './generate.js';

const serialized = writeMarketplace();

process.stdout.write(`wrote ${MARKETPLACE_PATH} (${serialized.length} bytes)\n`);
