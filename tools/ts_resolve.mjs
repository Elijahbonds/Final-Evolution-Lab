// ts_resolve.mjs — let executable tests import batch source the way the APP
// imports it.
//
//     node --experimental-strip-types --import ./tools/ts_resolve.mjs tests/foo.ts
//
// THE PROBLEM THIS SOLVES, WHICH HAS NOW COST THREE BATCHES
// The app is bundled by Next.js/webpack, where `import { x } from './Thing'`
// is correct and `'./Thing.ts'` is not. Node's ESM resolver is the opposite:
// it requires the extension. So batch source could either be importable by the
// app or executable by the test suite, never both.
//
// Every workaround so far has bent the CODE to suit the test runner: splitting
// a module in two, inlining a table, dropping an import. Each one was a real
// improvement on its own merits, but the pattern was a warning. The right
// place to fix a resolver mismatch is the resolver.
//
// This registers a resolve hook that retries a failed relative specifier with
// `.ts`, then `.tsx`, then `/index.ts`. Nothing else changes: no transpiler, no
// config, no dependency. Source keeps the app's convention and the tests run.

import { registerHooks } from 'node:module';

const CANDIDATES = ['.ts', '.tsx', '/index.ts', '/index.tsx'];

registerHooks({
  resolve(specifier, context, nextResolve) {
    try {
      return nextResolve(specifier, context);
    } catch (err) {
      // Only rescue RELATIVE specifiers. A bare specifier that failed is a
      // genuinely missing dependency — '@babylonjs/core' must still fail
      // loudly, because a test that silently resolved it would be testing
      // nothing.
      if (!specifier.startsWith('.')) throw err;
      if (/\.(ts|tsx|js|mjs|json)$/.test(specifier)) throw err;

      for (const ext of CANDIDATES) {
        try {
          return nextResolve(specifier + ext, context);
        } catch { /* try the next one */ }
      }
      throw err;
    }
  },
});
