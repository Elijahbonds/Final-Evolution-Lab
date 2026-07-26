#!/usr/bin/env node
// route_audit.mjs — reconcile the mode registry against the LIVE app and the
// files on disk.
//
//     node tools/route_audit.mjs
//     node tools/route_audit.mjs --url https://finalevolution.abacusai.app
//     node tools/route_audit.mjs --json
//
// WHY: I reported nine modes as unrouted. Six were live — I had probed
// `/play/skateboarding` when the mode declares `modeId: 'skateboard'`. The
// same class of mismatch shipped duplicate tennis/volleyball modes and left
// `applyArtCard` hunting a mesh name no venue builds. Three separate bugs, one
// cause: four different names for one mode and nothing reconciling them.
//
// This makes "is it routed?" a command. It answers three questions that were
// previously guesswork:
//
//   LIVE      registry says routable, and the URL responds
//   UNROUTED  the module exists on disk but the URL 404s   ← real backlog
//   UNBUILT   named in a registry, no module anywhere      ← not a routing job
//   DRIFT     registry disagrees with the modeId in the source
//
// A registry entry whose module is missing from disk is an ERROR: it means the
// table is lying, which is worse than having no table.

import { readFile, readdir } from 'node:fs/promises';
import { existsSync } from 'node:fs';
import { fileURLToPath } from 'node:url';
import { dirname, join } from 'node:path';

const ROOT = join(dirname(fileURLToPath(import.meta.url)), '..');
const args = process.argv.slice(2);
const argOf = (f, d) => { const i = args.indexOf(f); return i >= 0 && args[i + 1] ? args[i + 1] : d; };
const BASE = argOf('--url', 'https://finalevolution.abacusai.app');
const JSON_MODE = args.includes('--json');
const REGISTRY = argOf('--registry',
  join(ROOT, 'docs/abacus-batches/m77-mode-registry/files/core/modeRegistry.ts'));

// ── read the registry without a TS toolchain ──────────────────────────────
// Parsing the literal beats importing it: this tool must run in CI with no
// bundler, and the table is a flat list of object literals by design.
function parseRegistry(src) {
  const rows = [];
  const re = /\{\s*route:\s*'([^']+)',\s*modeId:\s*'([^']+)',\s*label:\s*'([^']*)',\s*venueId:\s*(null|'[^']*'),\s*backendId:\s*(null|'[^']*'),\s*module:\s*(null|'[^']*'),\s*status:\s*'([^']+)'\s*\}/g;
  let m;
  while ((m = re.exec(src))) {
    const unq = (v) => (v === 'null' ? null : v.slice(1, -1));
    rows.push({ route: m[1], modeId: m[2], label: m[3], venueId: unq(m[4]), backendId: unq(m[5]), module: unq(m[6]), status: m[7] });
  }
  return rows;
}

/** Find a mode module in the batches, newest batch wins. */
async function findModuleOnDisk(modulePath) {
  if (!modulePath) return null;
  const file = modulePath.split('/').pop();
  const batches = (await readdir(join(ROOT, 'docs/abacus-batches'), { withFileTypes: true }))
    .filter((d) => d.isDirectory() && /^m\d+/.test(d.name))
    .map((d) => d.name)
    .sort((a, b) => parseInt(b.slice(1), 10) - parseInt(a.slice(1), 10));
  for (const b of batches) {
    for (const ext of ['.ts', '.tsx']) {
      for (const sub of ['modes', 'modes/art', 'modes/music', 'modes/dance', 'core', 'pages']) {
        const p = join(ROOT, 'docs/abacus-batches', b, 'files', sub, file + ext);
        if (existsSync(p)) return { path: p, batch: b };
      }
    }
  }
  return null;
}

/** The modeId actually declared in the source — the thing that decides the route. */
async function declaredModeId(path) {
  try {
    const src = await readFile(path, 'utf8');
    const m = src.match(/modeId:\s*'([^']+)'/);
    return m ? m[1] : null;
  } catch { return null; }
}

async function probe(route) {
  try {
    const res = await fetch(`${BASE}/play/${route}`, { redirect: 'follow', signal: AbortSignal.timeout(20000) });
    return res.status;
  } catch { return 0; }
}

// ── run ───────────────────────────────────────────────────────────────────
if (!existsSync(REGISTRY)) {
  console.error(`  registry not found: ${REGISTRY}`);
  process.exit(2);
}
const rows = parseRegistry(await readFile(REGISTRY, 'utf8'));
if (rows.length === 0) {
  console.error('  registry parsed to 0 entries — the table format changed and this parser did not');
  process.exit(2);
}

const results = [];
for (const r of rows) {
  const onDisk = await findModuleOnDisk(r.module);
  const declared = onDisk ? await declaredModeId(onDisk.path) : null;
  const status = r.status === 'unbuilt' ? 0 : await probe(r.route);

  const problems = [];
  if (r.route !== r.modeId) problems.push(`route "${r.route}" !== modeId "${r.modeId}"`);
  if (r.module && !onDisk) problems.push(`module "${r.module}" not found on disk — registry is lying`);
  // precisionModes serves several modes from one file, so only flag a genuine
  // single-mode disagreement.
  if (declared && declared !== r.modeId && !/precisionModes/.test(r.module ?? '')) {
    problems.push(`source declares modeId "${declared}", registry says "${r.modeId}"`);
  }
  if (r.status === 'live' && status !== 200) problems.push(`marked live but /play/${r.route} → ${status}`);
  if (r.status === 'unrouted' && status === 200) problems.push(`marked unrouted but it is live — update the registry`);

  results.push({ ...results, route: r.route, registry: r.status, http: status, batch: onDisk?.batch ?? null, problems });
}

if (JSON_MODE) {
  process.stdout.write(JSON.stringify(results, null, 2) + '\n');
} else {
  const c = { live: '\x1b[32m', unrouted: '\x1b[33m', unbuilt: '\x1b[2m', off: '\x1b[0m', red: '\x1b[31m' };
  console.log(`\n  route audit — ${BASE}\n`);
  for (const r of results) {
    const tag = r.registry === 'live' ? `${c.live}LIVE    ${c.off}`
      : r.registry === 'unrouted' ? `${c.unrouted}UNROUTED${c.off}`
      : `${c.unbuilt}UNBUILT ${c.off}`;
    console.log(`  ${tag} /play/${r.route.padEnd(14)} http=${r.http || '—'}  ${c.unbuilt}${r.batch ?? 'no module'}${c.off}`);
    for (const p of r.problems) console.log(`           ${c.red}· ${p}${c.off}`);
  }
  const live = results.filter((r) => r.registry === 'live').length;
  const unrouted = results.filter((r) => r.registry === 'unrouted').length;
  const unbuilt = results.filter((r) => r.registry === 'unbuilt').length;
  const bad = results.filter((r) => r.problems.length).length;
  console.log(`\n  ${c.live}${live} live${c.off} · ${c.unrouted}${unrouted} unrouted (routing job)${c.off} · ${c.unbuilt}${unbuilt} unbuilt (needs a mode)${c.off}`);
  console.log(bad ? `  ${c.red}${bad} entr(ies) with problems${c.off}\n` : `  no drift\n`);
}

process.exit(results.some((r) => r.problems.length) ? 1 : 0);
