#!/usr/bin/env node
// skin_audit.mjs — check whether the deployed characters can animate at all.
//
//     node --experimental-strip-types tools/skin_audit.mjs
//     node --experimental-strip-types tools/skin_audit.mjs --modes dunk,karate
//
// This pulls the real vertex buffers out of the running game and runs them
// through `SkinWeightAudit.auditSkin` — the SAME function the app should run at
// load. It deliberately does not reimplement the thresholds: two copies of a
// rule is how the PRQ weight tables drifted 57% apart between Swift and Python.
//
// What it found on 2026-07-28: 77% of the character mesh welded to the `Head`
// bone. See M98.

import { chromium, devices } from '/opt/node22/lib/node_modules/playwright/index.mjs';
import { writeFile, mkdir } from 'node:fs/promises';
import { existsSync } from 'node:fs';

// Resolved from the repo root, not from this file's directory — a relative
// specifier here resolves against tools/ and silently misses.
const AUDIT_SRC = new URL('../docs/abacus-batches/m98-pass2-skin-weights/files/anim/SkinWeightAudit.ts',
  import.meta.url).href;
let auditSkin; let verticesFromBuffers;
try {
  ({ auditSkin, verticesFromBuffers } = await import(AUDIT_SRC));
} catch (e) {
  console.error('[SKIN] could not load the audit module. Run with:');
  console.error('       node --experimental-strip-types tools/skin_audit.mjs');
  console.error(`       (${String(e).split('\n')[0]})`);
  process.exit(2);
}

const args = process.argv.slice(2);
const argOf = (f, d) => { const i = args.indexOf(f); return i >= 0 && args[i + 1] ? args[i + 1] : d; };
const BASE = argOf('--url', 'https://finalevolution.abacusai.app');
const STATE = argOf('--state', 'smoke-state.json');
const MODES = argOf('--modes', 'dunk,karate,onevone,skateboard').split(',');

const HOOK = () => {
  const rb = Function.prototype.bind;
  window.__FEL_ENGINES_CAPTURED = [];
  Function.prototype.bind = function (t, ...r) {
    try {
      if (t && typeof t === 'object' && Array.isArray(t.scenes)
        && typeof t.getRenderingCanvas === 'function' && !window.__FEL_ENGINES_CAPTURED.includes(t)) {
        window.__FEL_ENGINES_CAPTURED.push(t);
      }
    } catch { /* observation must never break the page */ }
    return rb.call(this, t, ...r);
  };
};

/** Pull the raw buffers out. All judgement happens in the module, not here. */
const EXTRACT = () => {
  const s = (window.__FEL_ENGINES_CAPTURED ?? []).flatMap((e) => e.scenes ?? [])
    .find((x) => x.skeletons?.length);
  if (!s) return { error: 'no scene with a skeleton' };
  const out = [];
  for (const sk of s.skeletons.slice(0, 2)) {
    const mesh = s.meshes.find((m) => m.skeleton === sk);
    if (!mesh) continue;
    const positions = mesh.getVerticesData('position');
    const indices = mesh.getVerticesData('matricesIndices');
    const weights = mesh.getVerticesData('matricesWeights');
    if (!positions || !indices || !weights) {
      out.push({ mesh: mesh.name, error: 'mesh has no skinning data' });
      continue;
    }
    out.push({
      mesh: mesh.name,
      skeleton: sk.name,
      boneNames: sk.bones.map((b) => b.name),
      positions: Array.from(positions),
      indices: Array.from(indices),
      weights: Array.from(weights),
    });
  }
  return { rigs: out };
};

const browser = await chromium.launch({
  executablePath: '/opt/pw-browsers/chromium-1194/chrome-linux/chrome',
  proxy: { server: process.env.HTTPS_PROXY },
  args: ['--no-sandbox', '--disable-dev-shm-usage', '--ssl-version-max=tls1.2', '--enable-unsafe-swiftshader'],
});
const ctx = await browser.newContext(args.includes('--phone')
  ? { ...devices['iPhone 13'], storageState: existsSync(STATE) ? STATE : undefined }
  : { storageState: existsSync(STATE) ? STATE : undefined, viewport: { width: 1280, height: 800 } });

console.log(`[SKIN] ${BASE}\n`);
const report = [];
for (const mode of MODES) {
  const page = await ctx.newPage();
  await page.addInitScript(HOOK);
  let data = { error: 'navigation failed' };
  try {
    await page.goto(`${BASE}/play/${mode}`, { waitUntil: 'domcontentloaded', timeout: 45000 });
    await page.waitForSelector('canvas', { timeout: 30000 });
    await page.waitForTimeout(5000);
    const gate = page.getByText(/^\s*(TAP TO START|START)\s*$/i).first();
    if (await gate.count()) await gate.click().catch(() => {});
    await page.waitForTimeout(6000);
    data = await page.evaluate(EXTRACT);
  } catch (e) { data = { error: String(e).slice(0, 70) }; }
  await page.close();

  if (data.error) { console.log(`${mode.padEnd(12)} ${data.error}`); report.push({ mode, error: data.error }); continue; }
  for (const rig of data.rigs) {
    if (rig.error) { console.log(`${mode.padEnd(12)} ${rig.mesh}: ${rig.error}`); continue; }
    const verts = verticesFromBuffers(rig.positions, rig.indices, rig.weights, rig.boneNames, 7);
    const r = auditSkin(verts);
    const tag = r.verdict === 'ok' ? 'ok     ' : r.verdict === 'broken' ? 'BROKEN ' : 'suspect';
    console.log(`${mode.padEnd(12)} ${tag} ${rig.mesh.padEnd(12)} `
      + `dominant ${r.dominantBone} ${(r.dominantShare * 100).toFixed(0)}%  `
      + `mismatch ${(r.mismatchRate * 100).toFixed(0)}%`);
    for (const why of r.reasons) console.log(`             → ${why}`);
    console.log(`             regions: ${Object.entries(r.regionOwners).map(([k, v]) => `${k}=${v}`).join(' ')}`);
    report.push({ mode, mesh: rig.mesh, ...r });
  }
}
await browser.close();

const broken = report.filter((r) => r.verdict === 'broken');
console.log(`\n[SKIN] ${broken.length}/${report.filter((r) => r.verdict).length} rigs BROKEN.`);
if (broken.length) {
  console.log('       No clip, rest pose, or conformed mocap can work around this.');
  console.log('       The skeleton is fine; the mesh is not bound to it.');
}
await mkdir('artifacts', { recursive: true }).catch(() => {});
await writeFile('artifacts/skin-audit.json', JSON.stringify({ base: BASE, at: new Date().toISOString(), report }, null, 2));
console.log('       Full report → artifacts/skin-audit.json');
