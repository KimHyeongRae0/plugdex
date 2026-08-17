/**
 * AC-2, positive half: the supported install-source form must compile.
 *
 * Half of a pair. On its own a negative compile check proves nothing before the code
 * exists, because the fixture fails for a missing module rather than for the type it is
 * meant to violate. This half is what distinguishes "the type rejected it" from "nothing
 * was there to reject it".
 */
import type { InstallSource } from '../../src/schema';

export const supported: InstallSource = { source: 'github', repo: 'obra/superpowers' };
