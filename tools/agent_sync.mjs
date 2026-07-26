#!/usr/bin/env node
// agent_sync.mjs — the closest thing to inter-agent messaging that exists.
//
//     node tools/agent_sync.mjs claude-mini      # what do I need to know?
//     node tools/agent_sync.mjs --all            # everything, everyone
//     node tools/agent_sync.mjs --check          # CI: is the protocol intact?
//
// WHY THIS EXISTS
// FEL is built by three agents that CANNOT talk to each other: Claude Code in
// a cloud container (no local disk, no deploy), Claude Code on a Mac Mini (the
// only one with Blender, Xcode and a GPU), and Abacus AI (the only one that
// can ship). There is no shared memory and no message bus. The only medium all
// three can touch is the git repository.
//
// So the protocol is: each agent APPENDS to its own journal file and addresses
// requests to others with `NEEDS: <agent> — …`. One file per agent means two
// agents can never conflict. This tool reads those files and answers the only
// question that matters at the start of a session: what happened while I was
// gone, and what is anyone waiting on me for?
//
// See docs/AGENT-ACCESS-AND-PROTOCOL.md.

import { readdir, readFile } from 'node:fs/promises';
import path from 'node:path';

const JOURNAL_DIR = 'docs/agents/journal';
const FIELDS = ['DID', 'TOUCHED', 'FOUND', 'NEEDS', 'NEXT', 'CLAIM'];

/**
 * Parse one journal file into entries.
 *
 * Deliberately forgiving: a journal is written by hand under time pressure and
 * a tool that rejects a slightly-off entry is a tool that gets bypassed. It
 * reports what it could not parse instead of failing.
 */
export function parseJournal(text, agent) {
  const entries = [];
  const problems = [];
  // Entry heads look like:  ## 2026-07-26T21:10Z · claude-cloud
  const re = /^##\s+(\S+)\s*·\s*(\S+)\s*$/gm;
  const heads = [...text.matchAll(re)];

  heads.forEach((h, i) => {
    const start = h.index + h[0].length;
    const end = i + 1 < heads.length ? heads[i + 1].index : text.length;
    const body = text.slice(start, end);
    const [, stamp, who] = h;

    if (who !== agent) {
      problems.push(`${agent}: entry stamped "${who}" in ${agent}'s journal — `
        + 'each agent writes only its own file');
    }

    const fields = {};
    for (const line of body.split('\n')) {
      const m = line.match(/^([A-Z]+):\s*(.+)$/);
      if (!m) continue;
      if (!FIELDS.includes(m[1])) { problems.push(`${agent} ${stamp}: unknown field "${m[1]}"`); continue; }
      (fields[m[1]] ??= []).push(m[2].trim());
    }
    if (!fields.DID && !fields.CLAIM) {
      problems.push(`${agent} ${stamp}: no DID or CLAIM — an entry must say what happened`);
    }
    entries.push({ stamp, agent: who, fields });
  });

  return { entries, problems };
}

/**
 * A NEEDS line addresses another agent: `NEEDS: claude-mini — do the thing`.
 * Unaddressed needs are reported to everyone, on the grounds that a request
 * nobody owns is worse than one delivered twice.
 */
export function parseNeed(line) {
  const m = line.match(/^([a-z0-9-]+)\s*[—–-]\s*(.+)$/i);
  return m ? { to: m[1].toLowerCase(), what: m[2] } : { to: '*', what: line };
}

/** Newest last, so a journal reads top-to-bottom in time order. */
function chronological(a, b) { return a.stamp < b.stamp ? -1 : a.stamp > b.stamp ? 1 : 0; }

async function loadAll() {
  let files;
  try {
    files = (await readdir(JOURNAL_DIR)).filter((f) => f.endsWith('.md'));
  } catch {
    console.error(`[SYNC] no ${JOURNAL_DIR}/ — run from the repo root.`);
    process.exit(2);
  }

  const all = [];
  const problems = [];
  const agents = [];
  for (const f of files) {
    const agent = path.basename(f, '.md');
    agents.push(agent);
    const parsed = parseJournal(await readFile(path.join(JOURNAL_DIR, f), 'utf8'), agent);
    all.push(...parsed.entries);
    problems.push(...parsed.problems);
  }
  return { entries: all.sort(chronological), problems, agents };
}

// Importable as a module (the tests parse journals without running the CLI).
const isCli = process.argv[1] && process.argv[1].endsWith('agent_sync.mjs');
if (!isCli) { /* module use — stop before the CLI */ }
else { await main(); }

async function main() {
const argv = process.argv.slice(2);
const me = argv.find((a) => !a.startsWith('--'));
const showAll = argv.includes('--all');
const checkOnly = argv.includes('--check');

const { entries, problems, agents } = await loadAll();

if (checkOnly) {
  for (const p of problems) console.log(`[SYNC] ✗ ${p}`);
  console.log(`[SYNC] ${entries.length} entries across ${agents.length} agents, `
    + `${problems.length} problem(s)`);
  process.exit(problems.length ? 1 : 0);
}

if (!me && !showAll) {
  console.log('usage: node tools/agent_sync.mjs <your-agent-id> | --all | --check');
  console.log(`       agents: ${agents.join(', ')}`);
  process.exit(2);
}

// ── open requests addressed to you ───────────────────────────────────────
// Printed FIRST and unconditionally. This is the whole reason the tool
// exists; burying it under a changelog would defeat the point.
const mine = [];
for (const e of entries) {
  for (const n of e.fields.NEEDS ?? []) {
    const { to, what } = parseNeed(n);
    if (showAll || to === me || to === '*') mine.push({ from: e.agent, stamp: e.stamp, to, what });
  }
}

console.log(`\n━━ OPEN REQUESTS${me ? ` FOR ${me}` : ''} ━━`);
if (!mine.length) console.log('  (none)');
for (const n of mine) {
  console.log(`  · ${n.what}`);
  console.log(`    ← ${n.from}, ${n.stamp}${showAll && n.to !== me ? `  [for ${n.to}]` : ''}`);
}

// ── what everyone else has been doing ────────────────────────────────────
const others = entries.filter((e) => showAll || e.agent !== me);
console.log(`\n━━ ACTIVITY (${others.length} entr${others.length === 1 ? 'y' : 'ies'}) ━━`);
for (const e of others.slice(-8)) {
  console.log(`  ${e.stamp}  ${e.agent}`);
  for (const d of e.fields.DID ?? []) console.log(`    DID   ${d}`);
  for (const c of e.fields.CLAIM ?? []) console.log(`    CLAIM ${c}`);
  for (const f of e.fields.FOUND ?? []) console.log(`    FOUND ${f}`);
}

// ── claims, so two agents never build the same thing twice ───────────────
// This is not a hypothetical: two modes were once built twice because nothing
// reconciled who was working on what.
const claims = entries.flatMap((e) => (e.fields.CLAIM ?? []).map((c) => ({ agent: e.agent, stamp: e.stamp, what: c })));
if (claims.length) {
  console.log('\n━━ CLAIMED ━━');
  for (const c of claims.slice(-10)) console.log(`  ${c.agent}: ${c.what}  (${c.stamp})`);
}

if (problems.length) {
  console.log('\n━━ PROTOCOL PROBLEMS ━━');
  for (const p of problems) console.log(`  ✗ ${p}`);
}

console.log('\n[SYNC] append your entry to docs/agents/journal/<you>.md before you finish.\n');
}
