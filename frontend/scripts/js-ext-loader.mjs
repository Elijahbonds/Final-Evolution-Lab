/**
 * js-ext-loader.mjs — Node ESM resolve hook so the determinism harness can load
 * the app's audioEngine.js, which uses webpack-style EXTENSIONLESS relative
 * imports ("./synthVoices"). Node ESM requires the extension; webpack does not.
 * This hook appends ".js" to bare relative specifiers that lack an extension.
 * Verification-only; not part of the app build.
 */
export async function resolve(specifier, context, next) {
  if ((specifier.startsWith("./") || specifier.startsWith("../")) && !/\.[a-z]+$/i.test(specifier)) {
    try {
      return await next(specifier + ".js", context);
    } catch {
      return next(specifier, context);
    }
  }
  return next(specifier, context);
}
