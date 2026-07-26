#!/usr/bin/env node
// node tools/agent_sync_test.mjs
//
// The parser is forgiving by design, which means its edge cases are where it
// silently loses a request instead of failing. A dropped NEEDS line is an
// agent that never learns it was blocking the fleet — so those cases get tests.

import assert from 'node:assert/strict';
import { readFile, readdir } from 'node:fs/promises';
import { parseJournal, parseNeed } from './agent_sync.mjs';

let passed = 0;
const t = (n, fn) => {
  try { fn(); passed++; }
  catch (e) { console.error(`✗ ${n}\n  ${e.message}`); process.exitCode = 1; }
};

const entry = (stamp, agent, lines) => `## ${stamp} · ${agent}\n${lines.join('\n')}\n`;

t('parses a well-formed entry', () => {
  const { entries, problems } = parseJournal(
    entry('2026-07-26T10:00Z', 'a', ['DID: thing', 'NEXT: other thing']), 'a');
  assert.equal(entries.length, 1);
  assert.deepEqual(entries[0].fields.DID, ['thing']);
  assert.equal(problems.length, 0);
});

t('keeps multiple lines of the same field', () => {
  const { entries } = parseJournal(
    entry('2026-07-26T10:00Z', 'a', ['DID: x', 'NEEDS: b — one', 'NEEDS: c — two']), 'a');
  assert.equal(entries[0].fields.NEEDS.length, 2);
});

t('separates adjacent entries', () => {
  const src = entry('2026-07-26T10:00Z', 'a', ['DID: first'])
            + entry('2026-07-26T11:00Z', 'a', ['DID: second']);
  const { entries } = parseJournal(src, 'a');
  assert.equal(entries.length, 2);
  assert.deepEqual(entries[1].fields.DID, ['second']);
});

t('a field belongs to its own entry, not the next', () => {
  const src = entry('2026-07-26T10:00Z', 'a', ['DID: first', 'NEEDS: b — mine'])
            + entry('2026-07-26T11:00Z', 'a', ['DID: second']);
  const { entries } = parseJournal(src, 'a');
  assert.equal(entries[0].fields.NEEDS.length, 1);
  assert.equal(entries[1].fields.NEEDS, undefined);
});

t('flags an entry written into the wrong agent journal', () => {
  const { problems } = parseJournal(entry('2026-07-26T10:00Z', 'b', ['DID: x']), 'a');
  assert.match(problems.join(), /writes only its own file/);
});

t('flags an entry that says nothing happened', () => {
  const { problems } = parseJournal(entry('2026-07-26T10:00Z', 'a', ['NEXT: later']), 'a');
  assert.match(problems.join(), /no DID or CLAIM/);
});

t('a CLAIM alone is a valid entry', () => {
  const { problems } = parseJournal(entry('2026-07-26T10:00Z', 'a', ['CLAIM: MotionModel']), 'a');
  assert.equal(problems.length, 0);
});

t('flags an unknown field rather than dropping it silently', () => {
  const { problems } = parseJournal(entry('2026-07-26T10:00Z', 'a', ['DID: x', 'TODO: y']), 'a');
  assert.match(problems.join(), /unknown field "TODO"/);
});

t('prose lines are ignored, not misparsed', () => {
  const { entries, problems } = parseJournal(
    entry('2026-07-26T10:00Z', 'a', ['DID: x', 'some free text here', '']), 'a');
  assert.equal(problems.length, 0);
  assert.equal(Object.keys(entries[0].fields).length, 1);
});

// ── NEEDS addressing: the one channel between agents ─────────────────────
t('addresses a need with an em dash', () => {
  assert.deepEqual(parseNeed('claude-mini — run Blender'), { to: 'claude-mini', what: 'run Blender' });
});

t('accepts a plain hyphen too', () => {
  assert.equal(parseNeed('abacus - deploy it').to, 'abacus');
});

t('lowercases the addressee', () => {
  assert.equal(parseNeed('Claude-Mini — x').to, 'claude-mini');
});

t('an unaddressed need goes to everyone rather than nowhere', () => {
  const n = parseNeed('somebody should look at the camera');
  assert.equal(n.to, '*');
  assert.match(n.what, /camera/);
});

t('a URL in the body does not become the addressee', () => {
  // `https://…` has no space-dash-space, so it must fall through to '*'
  assert.equal(parseNeed('see https://example.com/a-b-c').to, '*');
});

// ── the real journals must always parse ──────────────────────────────────
const files = (await readdir('docs/agents/journal')).filter((f) => f.endsWith('.md'));
t('every real journal in the repo parses cleanly', async () => {
  assert.ok(files.length >= 3, `expected 3+ journals, found ${files.length}`);
});
for (const f of files) {
  const agent = f.replace(/\.md$/, '');
  const { problems } = parseJournal(await readFile(`docs/agents/journal/${f}`, 'utf8'), agent);
  t(`${f} has no protocol problems`, () => {
    assert.equal(problems.length, 0, problems.join('; '));
  });
}

console.log(`\n${passed} passed${process.exitCode ? ' — WITH FAILURES' : ''}`);
