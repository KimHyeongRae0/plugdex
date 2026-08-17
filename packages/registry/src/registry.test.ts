import assert from 'node:assert/strict';
import { test } from 'node:test';

import { entries, excludedArms } from './entries.js';
import { buildMarketplace } from './generate.js';
import { declaredAuthor, fromUpstream, MissingManifestError, readManifest } from './upstream.js';

/**
 * The e2e proves the hub installs. These are the properties that are cheaper to state
 * here than to infer from an install: that generation cannot drift, and that "the author
 * said this" is a different value from "we decided this".
 */

test('the registry lists something', () => {
  // Every assertion below is vacuously true over an empty list, which is the shape this
  // project has shipped six times. It is stated once, first, so the rest can rely on it.
  assert.ok(entries.length > 0, 'entries is empty — every other test here proves nothing');
});

test('generation is deterministic', () => {
  const first = JSON.stringify(buildMarketplace(), null, 2);
  const second = JSON.stringify(buildMarketplace(), null, 2);

  assert.equal(first, second);
  assert.ok(first.length > 0);
});

test('generation is sorted, so a reordered source file cannot churn the output', () => {
  const names = buildMarketplace().plugins.map((p) => p.name);

  assert.deepEqual(
    names,
    [...names].sort((a, b) => a.localeCompare(b)),
  );
});

test('every emitted install source is the github form', () => {
  for (const plugin of buildMarketplace().plugins) {
    assert.equal(plugin.source.source, 'github', `${plugin.name} is not a github source`);
    assert.match(plugin.source.repo, /^[\w.-]+\/[\w.-]+$/, `${plugin.name} repo is not owner/repo`);
  }
});

test('every curated attribution states why it is ours rather than theirs', () => {
  for (const entry of entries) {
    for (const field of ['author', 'upstreamRepo', 'license'] as const) {
      const value = entry[field];

      if (value.from === 'curated') {
        assert.ok(value.why.length > 0, `${entry.packId}.${field} is curated with no why`);
      }
    }
  }
});

test('an upstream-tagged author matches the manifest that declares it', () => {
  let checked = 0;

  for (const entry of entries) {
    if (entry.author.from !== 'upstream') continue;

    checked++;
    assert.equal(
      declaredAuthor({ manifest: readManifest({ packId: entry.packId }) }),
      entry.author.value,
      `${entry.packId} is listed under a name its own manifest does not declare`,
    );
  }

  assert.ok(checked > 0, 'no entry claims an upstream author — the check agreed with nothing');
});

test("the pack commonly called Karpathy's is listed under the author its manifest declares", () => {
  const entry = entries.find((e) => e.packId === 'karpathy');

  assert.ok(entry, 'the misattribution case is not listed');
  assert.equal(entry.author.from, 'upstream', 'its author must be derived, not asserted by us');
  assert.notEqual(
    entry.author.value,
    'Andrej Karpathy',
    'listing it under the name it is commonly called would be misattribution',
  );
});

test('a field the author never declared cannot be tagged as their declaration', () => {
  assert.throws(() => fromUpstream({ packId: 'x', value: '' }), MissingManifestError);
});

test('an unrecorded manifest is an error, not an empty author', () => {
  assert.throws(() => readManifest({ packId: 'no-such-pack' }), MissingManifestError);
});

test('a manifest with no author yields an empty string rather than an invented name', () => {
  assert.equal(declaredAuthor({ manifest: {} }), '');
  assert.equal(declaredAuthor({ manifest: { author: { url: 'https://example.com' } } }), '');
});

test('excluded arms each carry a reason', () => {
  for (const [arm, why] of Object.entries(excludedArms)) {
    assert.ok(why.length > 0, `${arm} is excluded with no stated reason`);
  }
});
