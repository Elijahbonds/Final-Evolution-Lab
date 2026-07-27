// fel_batch_alias.mjs — resolve `./Thing` inside a batch to whichever batch
// SHIPS it.
//
//     node --experimental-strip-types \
//       --import ./tools/ts_resolve.mjs --import ./tools/fel_batch_alias.mjs test.ts
//
// A batch imports its dependencies the way the APP will see them once every
// batch is integrated into one `core/` directory — `./MotionModel`, flat. On
// disk they are still spread across m81/, m82/, m83/. Copying them together to
// make a test run would hand Abacus duplicate files that then drift apart,
// which is exactly the PRQ-weight-table bug M82 had to fix.
//
// So the resolver does the flattening instead, and the shipped source keeps
// the convention it will actually run under.

import { registerHooks } from 'node:module';
import { existsSync } from 'node:fs';
import path from 'node:path';
import { fileURLToPath } from 'node:url';

const ROOT = path.resolve(path.dirname(fileURLToPath(import.meta.url)), '..');
const BATCHES = path.join(ROOT, 'docs/abacus-batches');

// Newest batch wins, matching integration order: a later batch REPLACES an
// earlier file of the same name (InputBus and ModeHarness both do this).
const SEARCH = ['m84-phase1-integration-kit', 'm83-determinism-and-ghosts',
  'm82-accessibility-and-prq', 'm81-feel-foundation', 'm80-external-animation']
  .map((b) => path.join(BATCHES, b, 'files'));

registerHooks({
  resolve(specifier, context, nextResolve) {
    try {
      return nextResolve(specifier, context);
    } catch (err) {
      if (!specifier.startsWith('./') && !specifier.startsWith('../')) throw err;
      const bare = specifier.replace(/^.*\//, '');
      for (const base of SEARCH) {
        for (const sub of ['core', 'anim', 'nexus', 'modes']) {
          for (const ext of ['.ts', '.tsx']) {
            const p = path.join(base, sub, bare + ext);
            if (existsSync(p)) return nextResolve(`file://${p}`, context);
          }
        }
      }
      throw err;
    }
  },
});
