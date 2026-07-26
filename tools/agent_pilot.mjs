#!/usr/bin/env node
// agent_pilot.mjs — drives the LIVE app through the AgentBridge, the way an
// AI agent in the browser would.
//
//     node tools/agent_pilot.mjs --check                  # is the bridge live?
//     node tools/agent_pilot.mjs --mode dunk              # play one mode
//     node tools/agent_pilot.mjs --all --json             # every mode, NDJSON
//     node tools/agent_pilot.mjs --mode karate --script '[["guard",{"ms":600}],["strike",{"which":"hook"}]]'
//
// This is two things at once, on purpose:
//   1. The REFERENCE IMPLEMENTATION of an agent driving Nexus. Anything a
//      browser-side agent wants to do, it can do the same way this does.
//   2. The TEST that the bridge is real. An API nobody exercises rots; this
//      runs in the pipeline (`nexus_agent.mjs smoke`), so a broken bridge
//      turns the build red instead of being discovered by an agent later.
//
// FALLBACK BEHAVIOUR MATTERS
// If the bridge is not deployed yet, this does NOT fail — it falls back to
// synthetic keyboard/mouse input and says so. The difference between "the
// game is broken" and "the control API isn't there yet" has to be visible,
// which is the same lesson the auth-wall and start-gate blind spots taught.

import { chromium } from '/opt/node22/lib/node_modules/playwright/index.mjs';
import { existsSync } from 'node:fs';

const args = process.argv.slice(2);
const argOf = (f, d) => { const i = args.indexOf(f); return i >= 0 && args[i + 1] ? args[i + 1] : d; };
const BASE = argOf('--url', process.env.NEXUS_URL || 'https://finalevolution.abacusai.app');
const STATE = argOf('--state', 'smoke-state.json');
const JSON_MODE = args.includes('--json');
const CHECK_ONLY = args.includes('--check');
const MODES = args.includes('--all')
  ? ['dunk', 'onevone', 'threevthree', 'karate', 'carnival']
  : [argOf('--mode', 'dunk')];

const say = (o) => process.stdout.write(JSON_MODE ? JSON.stringify(o) + '\n' : renderLine(o));
function renderLine(o) {
  if (o.event === 'mode') return `\n\x1b[1m${o.mode}\x1b[0m  ${o.url}\n`;
  if (o.event === 'result') {
    const tag = o.ok ? '\x1b[32mPASS\x1b[0m' : '\x1b[31mFAIL\x1b[0m';
    return `  ${tag} ${o.mode}  bridge=${o.bridge}  state=${o.state}  actions=${o.actions}`
      + `${o.score != null ? `  score=${o.score}` : ''}\n`
      + (o.problems?.length ? o.problems.map((p) => `       \x1b[31m· ${p}\x1b[0m\n`).join('') : '');
  }
  return `  ${o.event}: ${o.detail ?? ''}\n`;
}

// The default script: enough real play to make the game commit to something.
const DEFAULT_SCRIPT = {
  dunk:        [['sprint', { ms: 900 }], ['dunk', { ms: 400 }], ['idle', { ms: 500 }]],
  onevone:     [['move', { x: 0, y: 1, ms: 700 }], ['shoot', { charge: 0.85 }], ['idle', { ms: 600 }]],
  threevthree: [['move', { x: 0.4, y: 1, ms: 700 }], ['pass', {}], ['shoot', { charge: 0.7 }]],
  karate:      [['guard', { ms: 500 }], ['strike', { which: 'jab' }], ['strike', { which: 'hook' }], ['guard', { ms: 400 }]],
  carnival:    [['move', { x: 0, y: 1, ms: 600 }], ['shoot', { charge: 0.6 }]],
};

const browser = await chromium.launch({
  executablePath: '/opt/pw-browsers/chromium-1194/chrome-linux/chrome',
  proxy: process.env.HTTPS_PROXY ? { server: process.env.HTTPS_PROXY } : undefined,
  args: ['--no-sandbox', '--disable-dev-shm-usage', '--ssl-version-max=tls1.2', '--enable-unsafe-swiftshader'],
});
if (!existsSync(STATE)) {
  say({ event: 'warn', detail: `no session at ${STATE} — gated routes will show the sign-in wall. Run: node tools/smoke.mjs --login` });
}
const ctx = await browser.newContext({
  storageState: existsSync(STATE) ? STATE : undefined,
  viewport: { width: 1280, height: 720 },
});

const results = [];
for (const mode of MODES) {
  const url = `${BASE}/play/${mode}?agent=1`;   // ?agent=1 opts the bridge in
  say({ event: 'mode', mode, url });
  const page = await ctx.newPage();
  const problems = [];
  page.on('pageerror', (e) => problems.push(`pageerror: ${e.message.slice(0, 140)}`));
  page.on('console', (m) => {
    const t = m.text();
    if (/SKINNING STALL|MISSING CLIP|\[FEL-FRAME\]/i.test(t)) problems.push(t.slice(0, 180));
  });

  let bridge = 'absent', state = 'unknown', actions = 0, score = null;
  try {
    await page.goto(url, { waitUntil: 'domcontentloaded', timeout: 60000 });
    await page.waitForTimeout(8000);

    // Is the bridge there?
    const has = await page.evaluate(() => typeof window.__NEXUS_AGENT__ !== 'undefined').catch(() => false);
    bridge = has ? 'live' : 'absent';

    if (has) {
      const manifest = await page.evaluate(() => window.__NEXUS_AGENT__.describe());
      say({ event: 'info', detail: `bridge v${manifest.version} · ${manifest.modes.length} modes · ${manifest.actions.length} actions` });

      if (!CHECK_ONLY) {
        const started = await page.evaluate(() => window.__NEXUS_AGENT__.start());
        if (!started) problems.push("bridge start() never reached 'playing'");
        const script = DEFAULT_SCRIPT[mode] ?? [['idle', { ms: 500 }]];
        const custom = argOf('--script', null);
        const plan = custom ? JSON.parse(custom) : script;
        actions = await page.evaluate(async (p) => {
          let n = 0;
          for (const [name, opts] of p) { await window.__NEXUS_AGENT__.do(name, opts); n++; }
          return n;
        }, plan);
      }
      const snap = await page.evaluate(() => window.__NEXUS_AGENT__.state());
      state = snap.state; score = snap.score;
      for (const e of snap.errors ?? []) problems.push(`bridge error: ${e}`);
    } else {
      // Fallback: the pre-bridge way. Click the start gate by ACCESSIBLE
      // TEXT, not coordinates, then send synthetic input.
      const start = page.locator('text=/tap to start|start/i').first();
      if (await start.count().catch(() => 0)) await start.click({ force: true, timeout: 5000 }).catch(() => {});
      if (!CHECK_ONLY) {
        for (const k of ['Space', 'KeyW', 'KeyW', 'Space']) { await page.keyboard.press(k).catch(() => {}); await page.waitForTimeout(500); actions++; }
      }
      await page.waitForTimeout(3000);
      state = await page.evaluate(() => document.querySelector('#fel-ready')?.getAttribute('data-state') ?? 'unknown').catch(() => 'unknown');
    }
  } catch (e) {
    problems.push(`driver: ${String(e).slice(0, 160)}`);
  }

  // A mode that never leaves 'loaded' has not been played, whatever the
  // canvas looks like. This is the check my smoke test was missing.
  const ok = problems.length === 0 && (CHECK_ONLY ? bridge === 'live' : state === 'playing' || state === 'ended');
  if (!CHECK_ONLY && state === 'loaded') problems.push("stuck at 'loaded' — the start gate was never cleared");

  const r = { event: 'result', mode, ok, bridge, state, actions, score, problems };
  results.push(r);
  say(r);
  await page.close();
}

await browser.close();
const failed = results.filter((r) => !r.ok);
if (!JSON_MODE) {
  process.stdout.write(`\n  ${results.length - failed.length}/${results.length} passed`
    + `${failed.length ? ` — red: ${failed.map((r) => r.mode).join(', ')}` : ''}\n`);
  if (results.every((r) => r.bridge === 'absent')) {
    process.stdout.write('  \x1b[33mAgentBridge is not deployed yet — this run used the keyboard fallback.\x1b[0m\n');
  }
}
process.exit(failed.length ? 1 : 0);
