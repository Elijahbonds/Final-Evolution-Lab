#!/usr/bin/env node
// deploy.mjs — package a verified drop, then publish through an adapter.
//
//     node tools/deploy.mjs --batch docs/abacus-batches/m64-idle-pose-camera-fix
//     node tools/deploy.mjs --batch <dir> --publish      # requires an adapter
//
// WHY THIS IS A PACKAGER AND NOT AN API CALL
// The master brief lists "the real Abacus publish call" as a stub to fill.
// Verified against the repo: the Babylon game source is not in git (no
// Babylon dependency anywhere; the live app is Next.js served by Abacus),
// and there is no public Abacus deploy API I can find. Writing a
// `publishToAbacus()` against an invented endpoint produces a script that
// fails on first run and looks like it should work — worse than no script.
//
// So this does the part that IS real and IS automatable:
//   1. runs the gates (batch verify + asset validate) — fail closed
//   2. archives the previous drop so rollback is a copy, not a rebuild
//   3. packages a timestamped, verified bundle ready to drag into Abacus
//   4. hands off to a publish adapter IF one is registered
// When an Abacus API exists, implement `adapters/abacus.mjs` exporting
// `publish(bundleDir, { tag })`. Nothing above it changes.

import { execFileSync } from 'node:child_process';
import { cp, mkdir, readdir, rm, writeFile, readFile } from 'node:fs/promises';
import { existsSync } from 'node:fs';
import path from 'node:path';

const args = process.argv.slice(2);
const has = (f) => args.includes(f);
const val = (f, d) => { const i = args.indexOf(f); return i >= 0 && args[i + 1] ? args[i + 1] : d; };

const BATCH = val('--batch', null);
const OUT = val('--out', 'builds');
const KEEP = Number(val('--keep', '5'));
const TAG = new Date().toISOString().replace(/[:.]/g, '-');

const log = (m) => console.log(`[DEPLOY] ${m}`);
const die = (m) => { console.error(`[DEPLOY] FAILED: ${m}`); process.exit(1); };

function gate(label, cmd, cmdArgs) {
  log(`gate: ${label}`);
  try {
    execFileSync(cmd, cmdArgs, { stdio: 'inherit' });
  } catch {
    die(`${label} gate failed — nothing packaged, nothing published.`);
  }
}

async function pruneOldBuilds() {
  if (!existsSync(OUT)) return;
  const entries = (await readdir(OUT, { withFileTypes: true }))
    .filter((e) => e.isDirectory())
    .map((e) => e.name)
    .sort()
    .reverse();
  for (const stale of entries.slice(KEEP)) {
    await rm(path.join(OUT, stale), { recursive: true, force: true });
    log(`pruned old build ${stale}`);
  }
}

async function loadPublisher() {
  const adapterPath = path.resolve('tools/adapters/abacus.mjs');
  if (!existsSync(adapterPath)) return null;
  const mod = await import(`file://${adapterPath}`);
  return typeof mod.publish === 'function' ? mod.publish : null;
}

async function main() {
  if (!BATCH) die('pass --batch <dir>  (the batch to package)');
  if (!existsSync(BATCH)) die(`batch not found: ${BATCH}`);

  // ── 1. gates, fail closed ────────────────────────────────────────────
  gate('batch structure + syntax', 'node', ['tools/verify_batch.mjs', BATCH]);
  if (existsSync('assets/ready')) {
    gate('asset budgets + skeleton', 'python3', ['tools/validate_assets.py', 'assets/ready']);
  } else {
    log('no assets/ready — skipping asset gate');
  }

  // ── 2. package ───────────────────────────────────────────────────────
  const bundle = path.join(OUT, TAG);
  await mkdir(bundle, { recursive: true });
  await cp(BATCH, path.join(bundle, path.basename(BATCH)), { recursive: true });
  if (existsSync('assets/ready')) {
    await cp('assets/ready', path.join(bundle, 'assets'), { recursive: true });
  }

  // manifest: what this drop contains and what it passed
  const files = [];
  const walk = async (dir, base = '') => {
    for (const e of await readdir(dir, { withFileTypes: true })) {
      const rel = path.posix.join(base, e.name);
      if (e.isDirectory()) await walk(path.join(dir, e.name), rel);
      else files.push(rel);
    }
  };
  await walk(bundle);
  const manifest = {
    tag: TAG,
    batch: path.basename(BATCH),
    files,
    gates: ['verify_batch', existsSync('assets/ready') ? 'validate_assets' : null].filter(Boolean),
    packagedAt: new Date().toISOString(),
  };
  await writeFile(path.join(bundle, 'DROP-MANIFEST.json'), JSON.stringify(manifest, null, 2));
  await pruneOldBuilds();

  log(`packaged ${files.length} file(s) → ${bundle}`);
  log(`rollback: a previous drop is any other folder under ${OUT}/`);

  // ── 3. publish, only if an adapter exists ────────────────────────────
  if (!has('--publish')) {
    log('DRY RUN — verified bundle is ready to drag into Abacus.');
    log(`         drop: ${path.resolve(bundle)}`);
    return;
  }
  const publish = await loadPublisher();
  if (!publish) {
    die('--publish requested but tools/adapters/abacus.mjs is missing.\n'
      + '         Implement `export async function publish(bundleDir, { tag })`\n'
      + '         once a real Abacus deploy API is available. Until then the\n'
      + '         verified bundle above is the deliverable — drag it in.');
  }
  await publish(bundle, { tag: TAG });
  log(`published ${TAG}`);
}

main().catch((e) => die(String(e)));
