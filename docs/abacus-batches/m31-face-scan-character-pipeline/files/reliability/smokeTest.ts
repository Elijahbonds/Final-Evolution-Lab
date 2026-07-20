// smokeTest — the "no broken builds" deploy gate. Headless-boots every mode
// route and asserts: ready ≤20s, zero MISSING CLIP, non-black frames, no
// uncaught errors. Run against the preview deploy BEFORE promoting:
//   BASE_URL=https://preview-url node smokeTest.js
// Any failure = block the deploy. This encodes the hard-won lesson permanently:
// build-passing ≠ renders-correctly, so we assert rendering itself.

import { chromium, type Page } from 'playwright';

const BASE = process.env.BASE_URL ?? 'https://finalevolution.abacusai.app';
const MODES = [
  'dunk', 'karate', 'football', 'skateboard',
  'snowboard_slalom', 'surf', 'tennis', 'golf', 'derby', 'penalty',
];
const READY_TIMEOUT_MS = 20_000;

interface Result { mode: string; ok: boolean; problems: string[] }

async function testMode(page: Page, mode: string): Promise<Result> {
  const problems: string[] = [];
  const errors: string[] = [];
  page.on('console', (m) => {
    const t = m.text();
    if (m.type() === 'error' && !t.includes('favicon')) errors.push(t.slice(0, 160));
  });
  page.on('pageerror', (e) => errors.push(`uncaught: ${String(e).slice(0, 160)}`));

  await page.goto(`${BASE}/play/${mode}`, { waitUntil: 'domcontentloaded', timeout: 30_000 });

  // 1) reaches READY (BootSplash CTA) within budget
  const ready = await page
    .waitForSelector('text=/TAP TO START/i', { timeout: READY_TIMEOUT_MS })
    .then(() => true).catch(() => false);
  if (!ready) problems.push(`did not reach READY in ${READY_TIMEOUT_MS / 1000}s`);

  // 2) start and run a few seconds so animation + rendering engage
  if (ready) {
    await page.keyboard.press('j');
    await page.waitForTimeout(4500);
  }

  // 3) zero MISSING CLIP
  const missing = errors.filter((e) => e.includes('MISSING CLIP'));
  if (missing.length) problems.push(`MISSING CLIP ×${missing.length}: ${missing[0]}`);

  // 4) non-black frame: screenshot mean luma
  const shot = await page.screenshot({ type: 'png' });
  const luma = await meanLuma(page, shot);
  if (luma < 10) problems.push(`black frame (mean luma ${luma.toFixed(1)})`);

  // 5) uncaught errors
  const uncaught = errors.filter((e) => e.startsWith('uncaught:'));
  if (uncaught.length) problems.push(uncaught[0]);

  return { mode, ok: problems.length === 0, problems };
}

/** Decode the screenshot in-page for a dependency-free luma check. */
async function meanLuma(page: Page, png: Buffer): Promise<number> {
  return page.evaluate(async (b64) => {
    const img = new Image();
    img.src = `data:image/png;base64,${b64}`;
    await new Promise((r) => { img.onload = r; });
    const c = document.createElement('canvas');
    c.width = 64; c.height = 64;
    const ctx = c.getContext('2d')!;
    ctx.drawImage(img, 0, 0, 64, 64);
    const d = ctx.getImageData(0, 0, 64, 64).data;
    let sum = 0;
    for (let i = 0; i < d.length; i += 4) sum += 0.2126 * d[i] + 0.7152 * d[i + 1] + 0.0722 * d[i + 2];
    return sum / (64 * 64);
  }, png.toString('base64'));
}

async function main(): Promise<void> {
  const browser = await chromium.launch({ args: ['--enable-unsafe-swiftshader'] });
  const results: Result[] = [];
  for (const mode of MODES) {
    const page = await browser.newPage();
    try {
      results.push(await testMode(page, mode));
    } catch (e) {
      results.push({ mode, ok: false, problems: [`test crashed: ${String(e).slice(0, 120)}`] });
    }
    await page.close();
  }
  await browser.close();

  let failed = 0;
  for (const r of results) {
    console.log(`${r.ok ? '✅' : '❌'} ${r.mode}${r.ok ? '' : ' — ' + r.problems.join(' | ')}`);
    if (!r.ok) failed++;
  }
  console.log(`\n${results.length - failed}/${results.length} modes green`);
  process.exit(failed ? 1 : 0);        // non-zero blocks the deploy
}

void main();
