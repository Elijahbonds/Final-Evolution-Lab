#!/usr/bin/env node
// nexus_agent.mjs — the END-TO-END pipeline, exposed as verbs an AI agent
// can call and, crucially, PARSE.
//
//     node tools/nexus_agent.mjs plan
//     node tools/nexus_agent.mjs verify
//     node tools/nexus_agent.mjs build
//     node tools/nexus_agent.mjs smoke   --url https://finalevolution.abacusai.app
//     node tools/nexus_agent.mjs deploy
//     node tools/nexus_agent.mjs run                 # verify → build → deploy → smoke
//     node tools/nexus_agent.mjs run --json          # NDJSON, one event per line
//
// WHY A SEPARATE ENTRY POINT INSTEAD OF "THE AGENT RUNS green_check.sh"
// An agent driving a shell script has to scrape human-formatted output, and
// coloured PASS/FAIL text is exactly the kind of thing that looks parseable
// right up until a message wraps. Every verb here emits a structured record:
//
//     {"event":"step","name":"verify","status":"ok","ms":812,"detail":"..."}
//
// with a machine-readable status from a closed set — ok | failed | skipped.
// The human-readable rendering is derived FROM that, not the other way
// around, so the agent and the operator can never be told different things.
//
// ── THE HONESTY RULE, ENCODED ────────────────────────────────────────────
// `skipped` is a first-class result and is never coerced to `ok`. A step
// that cannot run here (no macOS for Swift, no deploy credentials, no live
// URL) reports WHY. `run` exits non-zero on any `failed`, and exits 0 with a
// loud summary when steps were skipped — because "green because we didn't
// look" is the failure mode this whole toolchain exists to prevent.

import { spawn } from 'node:child_process';
import { existsSync } from 'node:fs';
import { fileURLToPath } from 'node:url';
import { dirname, join } from 'node:path';

const ROOT = join(dirname(fileURLToPath(import.meta.url)), '..');
const args = process.argv.slice(2);
const VERB = args[0] ?? 'plan';
const JSON_MODE = args.includes('--json');
const argOf = (flag, fallback) => {
  const i = args.indexOf(flag);
  return i >= 0 && args[i + 1] ? args[i + 1] : fallback;
};

const URL_ = argOf('--url', process.env.NEXUS_URL || 'https://finalevolution.abacusai.app');

// ── output ────────────────────────────────────────────────────────────────
const events = [];
function emit(rec) {
  events.push(rec);
  if (JSON_MODE) { process.stdout.write(JSON.stringify(rec) + '\n'); return; }
  if (rec.event === 'step') {
    const tag = { ok: '\x1b[32mOK   \x1b[0m', failed: '\x1b[31mFAIL \x1b[0m', skipped: '\x1b[33mSKIP \x1b[0m' }[rec.status];
    process.stdout.write(`  ${tag} ${rec.name}${rec.ms != null ? `  \x1b[2m${rec.ms}ms\x1b[0m` : ''}\n`);
    if (rec.detail) process.stdout.write(`        \x1b[2m${rec.detail}\x1b[0m\n`);
  } else if (rec.event === 'phase') {
    process.stdout.write(`\n\x1b[2m── ${rec.name} ──────────────────────────\x1b[0m\n`);
  } else if (rec.event === 'summary') {
    process.stdout.write(`\n  \x1b[32m${rec.ok} ok\x1b[0m   \x1b[31m${rec.failed} failed\x1b[0m   \x1b[33m${rec.skipped} skipped\x1b[0m\n`);
    process.stdout.write(`  ${rec.verdict}\n`);
  }
}

function sh(cmd, cmdArgs, opts = {}) {
  return new Promise((resolve) => {
    const p = spawn(cmd, cmdArgs, { cwd: ROOT, shell: false, ...opts });
    let out = '', err = '';
    p.stdout?.on('data', (d) => { out += d; });
    p.stderr?.on('data', (d) => { err += d; });
    p.on('error', (e) => resolve({ code: 127, out, err: String(e) }));
    p.on('close', (code) => resolve({ code, out, err }));
  });
}

const tail = (s, n = 200) => String(s || '').trim().split('\n').slice(-2).join(' ').slice(-n);

async function step(name, fn) {
  const t0 = Date.now();
  let r;
  try { r = await fn(); }
  catch (e) { r = { status: 'failed', detail: String(e).slice(0, 200) }; }
  emit({ event: 'step', name, status: r.status, ms: Date.now() - t0, detail: r.detail });
  return r;
}

// ── the steps ─────────────────────────────────────────────────────────────

/** Static gates: batch structure, syntax, assets, backend. Fast, hermetic. */
async function verify() {
  emit({ event: 'phase', name: 'VERIFY' });
  const out = [];

  out.push(await step('batch structure + syntax', async () => {
    if (!existsSync(join(ROOT, 'tools/verify_batch.mjs'))) return { status: 'skipped', detail: 'tools/verify_batch.mjs missing' };
    const r = await sh('node', ['tools/verify_batch.mjs', '--all']);
    return r.code === 0 ? { status: 'ok' } : { status: 'failed', detail: tail(r.out + r.err) };
  }));

  out.push(await step('asset budgets + skeleton', async () => {
    if (!existsSync(join(ROOT, 'assets/ready'))) return { status: 'skipped', detail: 'no assets/ready directory' };
    const r = await sh('python3', ['tools/validate_assets.py', 'assets/ready']);
    return r.code === 0 ? { status: 'ok' } : { status: 'failed', detail: tail(r.out + r.err) };
  }));

  out.push(await step('backend imports + unit tests', async () => {
    if (!existsSync(join(ROOT, 'backend'))) return { status: 'skipped', detail: 'no backend/' };
    const has = await sh('python3', ['-c', 'import fastapi']);
    if (has.code !== 0) return { status: 'skipped', detail: 'FastAPI not installed — pip install -r backend/requirements.txt' };
    const r = await sh('python3', ['-m', 'pytest', '-q'], { cwd: join(ROOT, 'backend'), env: { ...process.env, MOCK_DB: '1' } });
    const m = (r.out.match(/(\d+) passed/) || [])[1];
    return r.code === 0
      ? { status: 'ok', detail: m ? `${m} passed` : undefined }
      : { status: 'failed', detail: tail(r.out + r.err) };
  }));

  return out;
}

/** The app build. Abacus builds the Babylon app from dropped files, so this
 *  repo has no bundler for it — that is a real constraint, reported as a
 *  skip rather than pretended away. Set NEXUS_BUILD_CMD where a build does
 *  exist (the Next.js app, CI) and it runs for real. */
async function build() {
  emit({ event: 'phase', name: 'BUILD' });
  return [await step('app build', async () => {
    const cmd = process.env.NEXUS_BUILD_CMD;
    if (!cmd) {
      return { status: 'skipped', detail: 'no NEXUS_BUILD_CMD set. This repo does not build the Babylon app '
        + '(Abacus does, from dropped files). Set NEXUS_BUILD_CMD="npm run build" where a build exists.' };
    }
    const r = await sh('bash', ['-lc', cmd]);
    return r.code === 0 ? { status: 'ok', detail: cmd } : { status: 'failed', detail: tail(r.out + r.err, 400) };
  })];
}

/** Deploy. There is deliberately NO invented Abacus API call here: this repo
 *  has no deploy credentials and no documented endpoint, and a deploy step
 *  that fakes success is worse than no deploy step. Supply the real command
 *  via NEXUS_DEPLOY_CMD and this becomes a genuine deploy. */
async function deploy() {
  emit({ event: 'phase', name: 'DEPLOY' });
  return [await step('deploy', async () => {
    const cmd = process.env.NEXUS_DEPLOY_CMD;
    if (!cmd) {
      return { status: 'skipped', detail: 'no NEXUS_DEPLOY_CMD set — nothing was deployed. '
        + 'This step will not report success it cannot verify. Set NEXUS_DEPLOY_CMD to the real deploy command.' };
    }
    if (args.includes('--dry-run')) return { status: 'skipped', detail: `--dry-run: would run "${cmd}"` };
    const r = await sh('bash', ['-lc', cmd]);
    return r.code === 0 ? { status: 'ok', detail: cmd } : { status: 'failed', detail: tail(r.out + r.err, 400) };
  })];
}

/** Post-deploy truth: drive the LIVE app with a real browser. */
async function smoke() {
  emit({ event: 'phase', name: 'SMOKE' });
  const out = [];

  out.push(await step(`live modes render + play (${URL_})`, async () => {
    if (!existsSync(join(ROOT, 'tools/smoke.mjs'))) return { status: 'skipped', detail: 'tools/smoke.mjs missing' };
    if (!existsSync(join(ROOT, 'smoke-state.json'))) {
      return { status: 'skipped', detail: 'no smoke-state.json — the app is behind a sign-in wall. '
        + 'Run: node tools/smoke.mjs --login' };
    }
    const r = await sh('node', ['tools/smoke.mjs', '--url', URL_]);
    return r.code === 0 ? { status: 'ok', detail: tail(r.out, 120) } : { status: 'failed', detail: tail(r.out + r.err, 400) };
  }));

  out.push(await step('agent bridge reachable', async () => {
    if (!existsSync(join(ROOT, 'tools/agent_pilot.mjs'))) return { status: 'skipped', detail: 'tools/agent_pilot.mjs missing' };
    if (!existsSync(join(ROOT, 'smoke-state.json'))) return { status: 'skipped', detail: 'needs a session' };
    const r = await sh('node', ['tools/agent_pilot.mjs', '--url', URL_, '--check']);
    return r.code === 0
      ? { status: 'ok', detail: tail(r.out, 120) }
      : { status: 'skipped', detail: 'bridge not answering — AgentBridge not deployed yet, or ?agent=1 rejected' };
  }));

  return out;
}

function plan() {
  emit({ event: 'phase', name: 'PLAN' });
  const rows = [
    ['verify', 'batch syntax, asset budgets, backend imports + unit tests', 'always'],
    ['build',  'app build', process.env.NEXUS_BUILD_CMD ? `NEXUS_BUILD_CMD="${process.env.NEXUS_BUILD_CMD}"` : 'SKIPPED — no NEXUS_BUILD_CMD'],
    ['deploy', 'ship it', process.env.NEXUS_DEPLOY_CMD ? `NEXUS_DEPLOY_CMD="${process.env.NEXUS_DEPLOY_CMD}"` : 'SKIPPED — no NEXUS_DEPLOY_CMD'],
    ['smoke',  `drive ${URL_} with a real browser`, existsSync(join(ROOT, 'smoke-state.json')) ? 'session present' : 'SKIPPED — no session'],
  ];
  // The summary MUST be derived from the same statuses that were emitted.
  // Building it from a separate array is how a report ends up saying FULLY
  // GREEN underneath a list of skips — the precise failure this tool exists
  // to make impossible.
  const out = [];
  for (const [name, what, how] of rows) {
    const status = how.startsWith('SKIPPED') ? 'skipped' : 'ok';
    emit({ event: 'step', name, status, detail: `${what} · ${how}` });
    out.push({ status });
  }
  return out;
}

// ── driver ────────────────────────────────────────────────────────────────
const VERBS = { plan, verify, build, deploy, smoke };

let results = [];
if (VERB === 'run') {
  results = results.concat(await verify());
  const failedEarly = results.some((r) => r.status === 'failed');
  if (failedEarly) {
    emit({ event: 'phase', name: 'BUILD/DEPLOY SKIPPED' });
    emit({ event: 'step', name: 'build + deploy', status: 'skipped', detail: 'verify failed — refusing to ship a red tree' });
  } else {
    results = results.concat(await build());
    results = results.concat(await deploy());
    results = results.concat(await smoke());
  }
} else if (VERBS[VERB]) {
  results = await VERBS[VERB]();
} else {
  process.stderr.write(`unknown verb "${VERB}". One of: ${Object.keys(VERBS).join(', ')}, run\n`);
  process.exit(2);
}

const ok = results.filter((r) => r.status === 'ok').length;
const failed = results.filter((r) => r.status === 'failed').length;
const skipped = results.filter((r) => r.status === 'skipped').length;
const verdict = failed > 0
  ? '\x1b[31mNOT GREEN\x1b[0m'
  : skipped > 0
    ? `\x1b[32mGREEN\x1b[0m on everything runnable — \x1b[33m${skipped} skipped, and a skip is not a pass\x1b[0m`
    : '\x1b[32mFULLY GREEN\x1b[0m';
emit({ event: 'summary', ok, failed, skipped, verdict: JSON_MODE ? verdict.replace(/\x1b\[\d+m/g, '') : verdict });

process.exit(failed > 0 ? 1 : 0);
