#!/usr/bin/env node
// verify_batch.mjs — check a drag-and-drop batch BEFORE it goes into Abacus.
//
//     node tools/verify_batch.mjs docs/abacus-batches/m63-basketball-dunk-v3
//     node tools/verify_batch.mjs --all
//
// This is the gate that fits how FEL is actually built. The Babylon game
// source lives in Abacus, not in this repo — so nothing here can compile the
// live app. What it CAN do is catch the mistakes that actually happen in the
// batch workflow, before a broken drop costs a deploy cycle:
//
//   · a file listed in the README's FILES table that isn't in files/
//   · a file in files/ that the README never mentions (silent orphan)
//   · unbalanced braces/parens (the classic truncated-paste failure)
//   · leftover merge markers or placeholder text
//   · an import of a sibling file the batch doesn't ship and doesn't declare
//     as a prerequisite
//
// Exit 1 on any error so CI can gate on it.

import { readdir, readFile, stat } from 'node:fs/promises';
import { existsSync } from 'node:fs';
import path from 'node:path';

// Shared infrastructure that has been live since the early batches. A batch
// importing these is normal and needs no declaration — only NEW or recently
// changed dependencies are worth flagging. Keep this list current; an entry
// here is a statement that the module is already deployed.
const KNOWN_DEPLOYED = new Set([
  'ModeHarness', 'InputBus', 'CharacterLibrary', 'BallPhysics', 'GroundRide',
  'MobSteering', 'Pickups', 'FrameGuard', 'PlayerSlot', 'gameFeel',
  'clipRegistry', 'importSanitizer', 'ballRig', 'clipBuilder', 'CharacterAnimator',
  'clipResolver', 'clipAliases', 'timing', 'authored',
  // Live since M26 alongside ModeHarness itself.
  'moods', 'sessionResult',
  'SoundKit', 'EffectsKit', 'VenueKit', 'LightRig', 'RenderPipeline',
  'CameraDirector', 'modeConfigs', 'boardCore', 'rideWorlds', 'aimSwingCore',
  'BasketballCore', 'DunkReplayCam', 'AudioEngine', 'StudioLibrary', 'SynthKit',
]);

const errors = [];
const warnings = [];
const err = (b, m) => errors.push(`${b}: ${m}`);
const warn = (b, m) => warnings.push(`${b}: ${m}`);

async function walk(dir) {
  const out = [];
  for (const entry of await readdir(dir, { withFileTypes: true })) {
    const p = path.join(dir, entry.name);
    if (entry.isDirectory()) out.push(...await walk(p));
    else out.push(p);
  }
  return out;
}

// Single-pass tokenizer. A regex-based stripper gets this WRONG — stripping
// comments first destroys any line containing `https://` inside a string,
// which false-flagged nine good files on the first run of this tool. State
// tracking is the only version that holds up.
function balanced(src) {
  const pairs = { '{': '}', '(': ')', '[': ']' };
  const closers = new Set(Object.values(pairs));
  const stack = [];
  let i = 0;
  const n = src.length;
  let state = 'code';   // code | line | block | sq | dq | tpl

  // Last significant character, used to tell a regex literal from division.
  // Without this, a regex containing a quote or backtick — e.g. /`(files\/…)`/ —
  // flips the tokenizer into string state and the rest of the file is
  // misread. This tool found that bug in ITSELF on first run.
  let prev = '';
  const REGEX_PRECEDERS = new Set(['(', ',', '=', ':', '[', '!', '&', '|', '?', '{', '}', ';', '+', '-', '*', '%', '<', '>', '~', '^', '']);

  while (i < n) {
    const c = src[i], c2 = src[i + 1];
    switch (state) {
      case 'code':
        if (c === '/' && c2 === '/') { state = 'line'; i += 2; continue; }
        if (c === '/' && c2 === '*') { state = 'block'; i += 2; continue; }
        if (c === '/' && REGEX_PRECEDERS.has(prev)) {
          // consume a regex literal whole: /…/flags, honouring escapes and
          // character classes (a '/' inside [...] does not end the literal)
          i++;
          let inClass = false;
          while (i < n) {
            const r = src[i];
            if (r === '\\') { i += 2; continue; }
            if (r === '[') inClass = true;
            else if (r === ']') inClass = false;
            else if (r === '/' && !inClass) { i++; break; }
            else if (r === '\n') break;              // unterminated — bail out
            i++;
          }
          while (i < n && /[gimsuyd]/.test(src[i])) i++;
          prev = '/';
          continue;
        }
        if (c === "'") { state = 'sq'; i++; continue; }
        if (c === '"') { state = 'dq'; i++; continue; }
        if (c === '`') { state = 'tpl'; i++; continue; }
        if (pairs[c]) stack.push({ c: pairs[c], back: null });
        else if (closers.has(c)) {
          const top = stack.pop();
          if (!top || top.c !== c) return false;
          // Closing a `${` returns us to the template literal it opened in.
          if (top.back) { state = top.back; i++; prev = c; continue; }
        }
        if (!/\s/.test(c)) prev = c;
        i++;
        continue;
      case 'line':
        if (c === '\n') state = 'code';
        i++;
        continue;
      case 'block':
        if (c === '*' && c2 === '/') { state = 'code'; i += 2; continue; }
        i++;
        continue;
      case 'sq':
      case 'dq':
      case 'tpl': {
        if (c === '\\') { i += 2; continue; }
        const quote = state === 'sq' ? "'" : state === 'dq' ? '"' : '`';
        if (c === quote) { state = 'code'; i++; prev = c; continue; }
        // A template literal's `${...}` is REAL CODE and must be tokenized as
        // such — the earlier assumption that its braces "balance either way"
        // is wrong for NESTED template literals:
        //     `a ${cond ? `b ${x}` : ''} c`
        // Skipping the expression makes the inner backtick look like the
        // outer literal's terminator, after which the rest of the file is
        // parsed inside-out. That is exactly how this tool reported a
        // truncated paste in a file Node itself accepts.
        if (state === 'tpl' && c === '$' && c2 === '{') {
          stack.push({ c: '}', back: 'tpl' });
          state = 'code';
          i += 2;
          prev = '{';
          continue;
        }
        i++;
        continue;
      }
    }
  }
  return stack.length === 0 && state === 'code';
}

async function verifyBatch(batchDir) {
  const name = path.basename(batchDir);
  // the prompt file is normally 00-README-PROMPT.md; spec-only batches use
  // 00-READ-FIRST.md, which is equally valid
  const entries = await readdir(batchDir);
  const promptFile = entries.find((f) => /^00-.*\.md$/i.test(f));
  const filesDir = path.join(batchDir, 'files');
  const hasFiles = existsSync(filesDir);

  // ORDER MATTERS. The missing-prompt check used to run first, which made
  // this gate red on m14/m15/m16/m22 — four directories that are historical
  // planning documents, not drop-in batches: no files/, nothing to drag
  // anywhere, so there is nothing for a prompt to instruct Abacus about.
  // A gate that is permanently red on something that cannot be fixed teaches
  // people to ignore it, so classify FIRST and demand a prompt only from
  // things that actually ship code.
  if (!hasFiles) {
    if (!promptFile) warn(name, 'no files/ and no 00-*.md — documentation directory, not a drop-in batch');
    else warn(name, 'no files/ directory — treating as a documentation-only batch');
    return;
  }
  if (!promptFile) {
    err(name, 'no 00-*.md prompt file — Abacus needs the prompt to know what to do');
    return;
  }
  const readme = await readFile(path.join(batchDir, promptFile), 'utf8');

  const shipped = (await walk(filesDir)).map((p) => path.relative(batchDir, p).split(path.sep).join('/'));

  // every `files/...` path mentioned in the README must exist
  const mentioned = new Set(
    [...readme.matchAll(/`(files\/[A-Za-z0-9_\-./]+\.[A-Za-z0-9]+)`/g)].map((m) => m[1]),
  );
  for (const m of mentioned) {
    if (!shipped.includes(m)) err(name, `README lists \`${m}\` but it is not in the batch`);
  }
  for (const s of shipped) {
    if (!mentioned.has(s)) warn(name, `\`${s}\` ships but the README never mentions it`);
  }

  const codeFiles = shipped.filter((f) => /\.(ts|tsx|mjs|js|py)$/.test(f));
  if (codeFiles.length === 0) warn(name, 'no code files in files/');

  for (const rel of codeFiles) {
    const full = path.join(batchDir, rel);
    const src = await readFile(full, 'utf8');
    const info = await stat(full);

    if (info.size === 0) { err(name, `${rel} is empty`); continue; }
    if (/^(<<<<<<<|>>>>>>>|=======)$/m.test(src)) err(name, `${rel} contains merge conflict markers`);
    // Truncation markers. The patterns are split with character classes so
    // this file does not match its own detector — the first version did.
    const TRUNC = [
      // the comment prefix is REQUIRED: bare `...rest,` is a spread
      // operator, and treating it as a marker false-flagged real code
      /^\s*(?:\/\/|#|\/\*)\s*\.{3}\s*(?:rest|remainder|continues|unchanged)\b/mi,
      /\[TRUNCA[T]ED\]/i,
      /<sni[p]>/i,
    ];
    if (TRUNC.some((re) => re.test(src))) {
      err(name, `${rel} looks truncated (placeholder text found) — Abacus would get a partial file`);
    }
    // .tsx is deliberately EXCLUDED: JSX text carries apostrophes
    // (`WHAT'S ON IT?`) which a non-JSX tokenizer reads as a string opener,
    // and every .tsx then false-flags. A tool that cries wolf gets switched
    // off, so it only claims what it can actually prove. Real .tsx checking
    // needs a JSX parser — out of scope here.
    if (/\.(ts|mjs|js)$/.test(rel) && !balanced(src)) {
      err(name, `${rel} has unbalanced braces/parens — likely a truncated paste or a stray closer`);
    }

    // relative imports must resolve inside the batch, or be declared as a
    // prerequisite in the README (batches re-ship or depend on earlier files)
    if (/\.(ts|tsx)$/.test(rel)) {
      const dir = path.posix.dirname(rel);
      for (const m of src.matchAll(/from\s+'(\.\.?\/[^']+)'/g)) {
        const target = path.posix.normalize(path.posix.join(dir, m[1]));
        const hit = shipped.some((s) => s === `${target}.ts` || s === `${target}.tsx` || s === target);
        if (!hit) {
          // Strip the extension before matching. A README that declares
          // `FixedStep` as a prerequisite must satisfy an import written
          // `FixedStep.ts` — tests import with the extension, source without,
          // and a gate that treats those as different names warns about
          // prerequisites that ARE declared. That is a tool crying wolf, which
          // is how a tool ends up switched off.
          const base = path.posix.basename(target).replace(/\.(ts|tsx)$/, '');
          const declared = new RegExp(`\\b${base}\\b`).test(readme);
          if (!declared && !KNOWN_DEPLOYED.has(base)) {
            warn(name, `${rel} imports '${m[1]}' — not shipped here, not in the README, `
              + 'and not a known-deployed module. Ship it, declare it as a prerequisite, '
              + 'or add it to KNOWN_DEPLOYED if it is already live.');
          }
        }
      }
    }
  }

  console.log(`  checked ${name}: ${codeFiles.length} code file(s)`);
}

async function main() {
  const args = process.argv.slice(2);
  const root = 'docs/abacus-batches';
  let batches = [];

  if (args[0] === '--all' || args.length === 0) {
    for (const e of await readdir(root, { withFileTypes: true })) {
      if (e.isDirectory()) batches.push(path.join(root, e.name));
    }
  } else {
    batches = args;
  }

  console.log(`[BATCH] verifying ${batches.length} batch(es)\n`);
  for (const b of batches) await verifyBatch(b);

  console.log('');
  for (const w of warnings) console.log(`[BATCH] WARN  ${w}`);
  for (const e of errors) console.log(`[BATCH] ERROR ${e}`);
  console.log(`\n[BATCH] ${errors.length} error(s), ${warnings.length} warning(s)`);

  if (errors.length) {
    console.log('[BATCH] FAILING — fix before dragging into Abacus.');
    process.exit(1);
  }
}

main().catch((e) => { console.error(e); process.exit(1); });
