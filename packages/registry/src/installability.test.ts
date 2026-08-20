import assert from 'node:assert/strict';
import { execFileSync } from 'node:child_process';
import { mkdtempSync, readdirSync, readFileSync, rmSync, writeFileSync } from 'node:fs';
import { tmpdir } from 'node:os';
import { dirname, join } from 'node:path';
import { fileURLToPath } from 'node:url';
import test from 'node:test';

import {
  INSTALLABILITY_DIR,
  installabilityFor,
  installabilityRecords,
  installStateFor,
  loadInstallabilityRecords,
  MalformedInstallabilityError,
  shortCommit,
  summariseInstallability,
} from './installability.js';
import type { InstallabilityRecord } from './installability.js';
import { entries } from './entries.js';

const REPO_ROOT = join(dirname(fileURLToPath(import.meta.url)), '..', '..', '..');
const WRITER = join(REPO_ROOT, 'scripts', 'lib', 'write-installability.py');

const sandbox = ({ run }: { run: (dir: string) => void }): void => {
  const dir = mkdtempSync(join(tmpdir(), 'plugdex-inst-test-'));

  try {
    run(dir);
  } finally {
    rmSync(dir, { recursive: true, force: true });
  }
};

test('every listed pack has a record, and every record has a listing', () => {
  const listed = entries.map((entry) => entry.packId).sort();
  const recorded = Object.keys(installabilityRecords).sort();

  assert.ok(listed.length > 0, 'no listings — the assertion would be vacuous');
  assert.deepEqual(recorded, listed);
});

test('a blocked record carries a signature the gate can re-check, and the failure it is about', () => {
  const blocked = Object.values(installabilityRecords).filter(
    (record) => record.outcome === 'blocked',
  );

  for (const record of blocked) {
    assert.ok(record.signature.kind.length > 0, `${record.pack}: signature has no kind`);
    assert.ok(record.signature.keys.length > 0, `${record.pack}: signature names no keys`);
    assert.ok(record.verbatim.length > 0, `${record.pack}: blocked with no quoted failure`);
  }
});

test('no record leaks the recorder’s own scratch directory into a committed file', () => {
  // The redaction that removes it is best-effort by design — a failure that never names
  // the scratch path is ordinary. What is not optional is the result, and one earlier
  // version of that redaction silently did nothing on a machine whose TMPDIR ended in a
  // slash. This is the check that would have caught it here rather than in review.
  for (const record of Object.values(installabilityRecords)) {
    if (record.outcome !== 'blocked') continue;

    assert.ok(
      !record.verbatim.includes('plugdex-record.'),
      `${record.pack}: the record quotes an absolute local scratch path`,
    );
  }
});

test('every committed record re-serialises byte-identically under the writer’s canonical form', () => {
  // What this pins is CANONICAL FORM: key order, indentation, the redactions, the shape of
  // each variant. It does NOT authenticate content, and an earlier version of this comment
  // claimed it did — the report review demonstrated the claim false by flipping caveman's
  // outcome from blocked to installs and watching the suite stay green.
  //
  // The reason is structural rather than an oversight to patch: the check re-serialises the
  // record's own fields, so any edit that is itself canonical round-trips. No offline test
  // can tell a hand edit from an honest re-record, because both produce the same bytes and
  // there is no secret here to sign with. Content is checked where content lives — INST-01
  // re-measures against the world, and `outcome` and `signature` are exactly what it
  // re-measures. What that leaves unguarded is written down in the report rather than
  // implied away.
  for (const file of readdirSync(INSTALLABILITY_DIR).filter((name) => name.endsWith('.json'))) {
    const path = join(INSTALLABILITY_DIR, file);
    const onDisk = readFileSync(path, 'utf8');
    const record = JSON.parse(onDisk) as Record<string, unknown>;

    const env: NodeJS.ProcessEnv = {
      ...process.env,
      PACK: String(record['pack']),
      REPO: String(record['repo']),
      CLI_VERSION: String(record['cliVersion']),
      ATTEMPTED_AT: String(record['attemptedAt']),
      UPSTREAM_HEAD: String(record['upstreamHead']),
      TRANSPORT: String(record['transport']),
    };

    let variant = 'installs';

    if (record['outcome'] === 'blocked') {
      variant = 'blocked';

      const signature = record['signature'] as { kind: string; keys: string[] };

      sandbox({
        run: (dir) => {
          const verbatimFile = join(dir, 'verbatim.txt');
          writeFileSync(verbatimFile, String(record['verbatim']));

          const rewritten = execFileSync('python3', [WRITER, variant], {
            env: {
              ...env,
              KIND: signature.kind,
              KEYS: signature.keys.join(','),
              VERBATIM_FILE: verbatimFile,
            },
            encoding: 'utf8',
          });

          assert.equal(rewritten, onDisk, `${file} does not match what the writer would emit`);
        },
      });

      continue;
    }

    if (record['installedVersion'] !== undefined) {
      env['VERSION'] = String(record['installedVersion']);
    }

    const rewritten = execFileSync('python3', [WRITER, variant], { env, encoding: 'utf8' });

    assert.equal(rewritten, onDisk, `${file} does not match what the writer would emit`);
  }
});

test('a record whose filename disagrees with its pack is refused, not trusted', () => {
  // DATA-02, applied one level up: the filename is not the fact. A record that says one
  // thing while its name says another is exactly the shape that let a run be excluded by
  // a filename prefix in the analysis, and it is refused here for the same reason.
  sandbox({
    run: (dir) => {
      writeFileSync(
        join(dir, 'imposter.json'),
        JSON.stringify({
          pack: 'caveman',
          repo: 'owner/repo',
          cliVersion: 'x',
          attemptedAt: 'x',
          upstreamHead: 'x',
          transport: 'https',
          outcome: 'installs',
        }),
      );

      assert.throws(() => loadInstallabilityRecords({ dir }), MalformedInstallabilityError);
    },
  });
});

test('a blocked record with no keys is refused — there would be nothing to re-check', () => {
  sandbox({
    run: (dir) => {
      writeFileSync(
        join(dir, 'p.json'),
        JSON.stringify({
          pack: 'p',
          repo: 'owner/p',
          cliVersion: 'x',
          attemptedAt: 'x',
          upstreamHead: 'x',
          transport: 'https',
          outcome: 'blocked',
          signature: { kind: 'manifest-validation', keys: [] },
          verbatim: 'something',
        }),
      );

      assert.throws(() => loadInstallabilityRecords({ dir }), MalformedInstallabilityError);
    },
  });
});

test('an unknown outcome is refused rather than skipped', () => {
  sandbox({
    run: (dir) => {
      writeFileSync(
        join(dir, 'p.json'),
        JSON.stringify({
          pack: 'p',
          repo: 'owner/p',
          cliVersion: 'x',
          attemptedAt: 'x',
          upstreamHead: 'x',
          transport: 'https',
          outcome: 'probably-fine',
        }),
      );

      assert.throws(() => loadInstallabilityRecords({ dir }), MalformedInstallabilityError);
    },
  });
});

test('installabilityFor answers for a listed pack and stays undefined for one nobody measured', () => {
  const [first] = Object.keys(installabilityRecords);

  assert.ok(first, 'no records loaded');
  assert.equal(installabilityFor({ packId: first })?.pack, first);
  assert.equal(installabilityFor({ packId: 'no-such-pack' }), undefined);
});

test('an unmeasured pack is an absence, never the flattering default', () => {
  // The one default that must not ship. `installabilityFor` returns `undefined` for a pack
  // nothing has measured, and `undefined` read as a boolean is `false` — which on a page
  // about whether things install renders the answer that suits us. Report review round 1
  // proved the site's scenario could not catch a regression here, so the branch is pinned
  // at the source as well as in the built page.
  const state = installStateFor({ packId: 'nothing-measured-this', records: {} });

  assert.equal(state.state, 'unmeasured');
  assert.ok(!('record' in state), 'an unmeasured state carries no record to read a verdict from');
});

test('a recorded pack gets its recorded outcome, and its head shortened once', () => {
  const records = {
    ok: {
      pack: 'ok',
      repo: 'example/ok',
      cliVersion: 'x',
      attemptedAt: '2026-08-18T00:00:00Z',
      upstreamHead: 'abcdef1234567890abcdef1234567890abcdef12',
      transport: 'https',
      outcome: 'installs',
    },
    bad: {
      pack: 'bad',
      repo: 'example/bad',
      cliVersion: 'x',
      attemptedAt: '2026-08-19T00:00:00Z',
      upstreamHead: '1234567abcdef1234567890abcdef1234567890a',
      transport: 'https',
      outcome: 'blocked',
      signature: { kind: 'manifest-validation', keys: ['agents'] },
      verbatim: 'boom',
    },
  } as unknown as Record<string, InstallabilityRecord>;

  assert.equal(installStateFor({ packId: 'ok', records }).state, 'installs');
  assert.equal(installStateFor({ packId: 'bad', records }).state, 'blocked');
  assert.equal(shortCommit({ commit: 'abcdef1234567890' }), 'abcdef1');
});

test('the summary reports the OLDEST attempt, which one calendar date cannot distinguish', () => {
  // The live corpus writes every record inside one two-minute window, so a date-level
  // comparison passes even when the newest is reported. These two share a date on purpose.
  const sameDay = {
    early: {
      pack: 'early',
      repo: 'e/e',
      cliVersion: 'x',
      attemptedAt: '2026-08-18T22:55:14Z',
      upstreamHead: 'a'.repeat(40),
      transport: 'https',
      outcome: 'installs',
    },
    late: {
      pack: 'late',
      repo: 'l/l',
      cliVersion: 'x',
      attemptedAt: '2026-08-18T22:57:08Z',
      upstreamHead: 'b'.repeat(40),
      transport: 'https',
      outcome: 'blocked',
      signature: { kind: 'k', keys: ['x'] },
      verbatim: 'boom',
    },
  } as unknown as Record<string, InstallabilityRecord>;

  const summary = summariseInstallability({ records: sameDay });

  assert.equal(summary.installs, 1);
  assert.equal(summary.blocked, 1);
  assert.equal(summary.oldestAttemptedAt, '2026-08-18T22:55:14Z');
  assert.notEqual(summary.oldestAttemptedAt, '2026-08-18T22:57:08Z');
  assert.equal(summary.attemptedOn, '2026-08-18');
});

test('a summary over no record is refused rather than invented', () => {
  assert.throws(() => summariseInstallability({ records: {} }), RangeError);
});
