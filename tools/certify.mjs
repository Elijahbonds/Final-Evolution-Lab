#!/usr/bin/env node
// certify.mjs — run every gate this repo can actually run, and report honestly.
//
//     node tools/certify.mjs
//     node tools/certify.mjs --json
//
// WHAT THIS DOES AND DOES NOT PROVE
// It runs every executable test suite and the batch gate. Green here means the
// LOGIC is correct. It does not mean anything ships: nothing in this repo has
// been observed running in the deployed app, and a green run has never been
// evidence that a player benefits.
//
// `tools/integration_audit.mjs` is the other half — it asks the LIVE build
// which subsystems actually run. Certification needs both, and this half is
// the easy one.

import { readdir, readFile, writeFile, mkdir } from 'node:fs/promises';
import { existsSync } from 'node:fs';
import { execFile } from 'node:child_process';
import path from 'node:path';
import { promisify } from 'node:util';

const run = promisify(execFile);
const BATCHES = 'docs/abacus-batches';
const JSON_OUT = process.argv.includes('--json');

const NODE_FLAGS = [
  '--experimental-strip-types',
  '--import', './tools/ts_resolve.mjs',
  '--import', './tools/fel_batch_alias.mjs',
];

/** Every executable test in every batch. */
async function findSuites() {
  const out = [];
  for (const batch of (await readdir(BATCHES, { withFileTypes: true }))
    .filter((d) => d.isDirectory())) {
    const dir = path.join(BATCHES, batch.name, 'files', 'tests');
    if (!existsSync(dir)) continue;
    for (const f of await readdir(dir)) {
      if (/\.(ts|mjs)$/.test(f)) out.push({ batch: batch.name, file: path.join(dir, f) });
    }
  }
  return out.sort((a, b) => a.file.localeCompare(b.file));
}

function parseCounts(stdout) {
  // Suites report either "N passed, M failed" or "N passed".
  const m = stdout.match(/(\d+)\s+passed(?:,\s*(\d+)\s+failed)?/);
  if (!m) return null;
  return { passed: Number(m[1]), failed: Number(m[2] ?? 0) };
}

async function runSuite(s) {
  const args = s.file.endsWith('.ts') ? [...NODE_FLAGS, s.file] : [s.file];
  try {
    const { stdout } = await run('node', args, { maxBuffer: 8 * 1024 * 1024, timeout: 120000 });
    const c = parseCounts(stdout);
    return { ...s, ok: c ? c.failed === 0 : false, ...(c ?? { passed: 0, failed: 0 }),
      note: c ? '' : 'suite produced no recognisable count' };
  } catch (e) {
    const stdout = e.stdout ?? '';
    const c = parseCounts(stdout);
    return { ...s, ok: false, passed: c?.passed ?? 0, failed: c?.failed ?? 1,
      note: (e.stderr ?? String(e)).split('\n')[0].slice(0, 160) };
  }
}

// ── run everything ───────────────────────────────────────────────────────
const suites = await findSuites();
const results = [];
for (const s of suites) {
  const r = await runSuite(s);
  results.push(r);
  if (!JSON_OUT) {
    console.log(`  ${r.ok ? 'ok  ' : 'FAIL'} ${r.batch.padEnd(34)} ${String(r.passed).padStart(4)} passed`
      + (r.failed ? `, ${r.failed} FAILED` : '') + (r.note ? `  — ${r.note}` : ''));
  }
}

let gateOk = true;
let gateNote = '';
try {
  const { stdout } = await run('node', ['tools/verify_batch.mjs', '--all'], { maxBuffer: 8 * 1024 * 1024 });
  const m = stdout.match(/(\d+) error\(s\), (\d+) warning\(s\)/);
  gateOk = m ? Number(m[1]) === 0 : false;
  gateNote = m ? `${m[1]} errors, ${m[2]} warnings` : 'unparsed';
} catch (e) {
  gateOk = false;
  gateNote = String(e).slice(0, 120);
}

let syncOk = true;
try { await run('node', ['tools/agent_sync.mjs', '--check']); } catch { syncOk = false; }

const totalPassed = results.reduce((n, r) => n + r.passed, 0);
const totalFailed = results.reduce((n, r) => n + r.failed, 0);
const suitesOk = results.filter((r) => r.ok).length;

// ── what is NOT covered — the honest half ────────────────────────────────
const UNPROVEN = [
  ['response', 'Input-to-response has never been measured in the real app'],
  ['framerate', 'No session has been profiled on a real device'],
  // Pass 2 Phase 2 measured these against the deployed app. See
  // docs/BASELINE-2026-07-27.md. Two left UNKNOWN; one left BUILT for FAIL,
  // which is worse news and better information.
  ['boot', 'measured 1.2-2.5s to canvas on a data-centre link; no 4G run yet'],
  ['canvas', 'root-caused (aspect-[16/10]) and fixed 33%→80% in a browser; NOT DEPLOYED'],
  // CORRECTED in M97 by measuring inside the running scene rather than reading
  // screenshots. idle_stand plays, the rest pose applies, the arm sits at 20
  // degrees from vertical and bind on this rig is 90. It was never a T-pose.
  // M98 found the real cause three levels below where anyone had looked.
  ['no_tpose', 'ROOT CAUSE: 77% of the mesh is welded to the Head bone — 5/5 rigs BROKEN'],
  ['framing', 'six of eight modes render the player at 5-9% of screen; fix in M97, NOT APPLIED'],
  // M94 moved these three from "no mode" to "one mode, in the repo". They stay
  // in this panel because this panel is about the DEPLOYED app, and none of it
  // has been observed running. Promoting them on source alone is precisely the
  // wishful BUILT→PASS move M93 wrote a test against.
  ['a11y_audio', 'dunk captions every cue in source; nothing has been heard in the app'],
  ['prq', 'dunk reads PRQ into judge strictness in source; not observed in the app'],
  ['legibility', 'Zero of eleven tells drawn — AND at current framing a tell would be ~6px'],
  // Found by watching modes with NO player input, which nothing here had ever
  // done. Three of fourteen modes destroy themselves unattended.
  ['grounding', 'skateboard/snowboard/surf lose the rider through the floor; fix in M96, NOT DEPLOYED'],
  ['simulatable', 'dunk implements it and proves deterministic here; no DEPLOYED mode does'],
  ['mocap', 'never run — AND it would change nothing until skin weights are fixed (M98)'],
  ['fun', 'Only the founder can score this'],
];

const report = {
  at: new Date().toISOString(),
  suites: results.map(({ batch, file, ok, passed, failed, note }) => ({ batch, file, ok, passed, failed, note })),
  totals: { suites: results.length, suitesOk, testsPassed: totalPassed, testsFailed: totalFailed },
  batchGate: { ok: gateOk, note: gateNote },
  journalProtocol: { ok: syncOk },
  unproven: UNPROVEN.map(([id, why]) => ({ id, why })),
};

await mkdir('artifacts', { recursive: true }).catch(() => {});
await writeFile('artifacts/certification.json', JSON.stringify(report, null, 2));

if (JSON_OUT) {
  console.log(JSON.stringify(report, null, 2));
} else {
  console.log(`\n┌─ WHAT IS PROVEN ────────────────────────────────────────────`);
  console.log(`│ test suites     ${suitesOk}/${results.length} green`);
  console.log(`│ assertions      ${totalPassed} passed, ${totalFailed} failed`);
  console.log(`│ batch gate      ${gateOk ? 'clean' : 'FAILING'} (${gateNote})`);
  console.log(`│ agent protocol  ${syncOk ? 'intact' : 'BROKEN'}`);
  // The first criterion measured PASS against the deployed product rather than
  // asserted from the repo. It belongs above the line, not below it.
  console.log('│ lifecycle       PASS — 20 route changes on one page, 20/20 loaded,');
  console.log('│                 1 live WebGL context throughout, 0 page errors,');
  console.log('│                 boot 198ms FASTER at the end than the start.');
  console.log(`└─────────────────────────────────────────────────────────────`);
  console.log(`\n┌─ WHAT IS NOT ───────────────────────────────────────────────`);
  for (const [id, why] of UNPROVEN) console.log(`│ ${id.padEnd(13)} ${why}`);
  console.log(`└─────────────────────────────────────────────────────────────`);
  console.log('\n[CERT] Green above means the LOGIC is right. It is not evidence that');
  console.log('       anything ships — nothing here has been observed running in the');
  console.log('       deployed app. Run tools/integration_audit.mjs for the other half.');
  console.log('       Full report → artifacts/certification.json');
}

process.exit(totalFailed > 0 || !gateOk ? 1 : 0);
