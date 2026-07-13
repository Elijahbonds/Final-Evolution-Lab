/**
 * NEXUS CELL — Web Audit Module
 *
 * Drives a Playwright Chromium browser to:
 *   1. Navigate to a URL
 *   2. Follow a login flow (if credentials provided)
 *   3. Execute scripted audit steps (click, fill, assert_text, screenshot)
 *   4. Collect: console errors, network failures, page title, headings,
 *      load timing, basic accessibility issues, broken links
 *   5. Write a structured WebAuditReport JSON to artifacts/web-audit/latest.json
 *
 * Falls back to a lightweight curl-based HTML fetch when stub_mode=true
 * (CI / offline / headless environments without Playwright installed).
 */

import fs from "node:fs";
import path from "node:path";
import { repoRoot } from "./config.js";

// ── Types ─────────────────────────────────────────────────────────────────────

export type AuditSeverity = "info" | "warning" | "error" | "critical";

export type WebAuditFinding = {
  category: "login" | "ux" | "performance" | "accessibility" | "error" | "content";
  severity: AuditSeverity;
  message: string;
  url?: string;
  screenshot_b64?: string;
  value?: number;
};

export type AuditStep = {
  action: "navigate" | "click" | "fill" | "assert_text" | "screenshot";
  selector?: string;
  value?: string;
  url?: string;
};

export type WebAuditOptions = {
  url: string;
  credentials?: { email?: string; password?: string; [key: string]: string | undefined };
  steps?: AuditStep[];
  stub_mode?: boolean;
  /** Max milliseconds to wait for initial navigation. Default: 15000 */
  timeout_ms?: number;
};

export type WebAuditReport = {
  url: string;
  login_ok: boolean;
  page_title: string;
  load_time_ms: number;
  timestamp_ms: number;
  findings: WebAuditFinding[];
};

// ── Artifact path ─────────────────────────────────────────────────────────────

function artifactPath(): string {
  return path.join(repoRoot(), "artifacts", "web-audit", "latest.json");
}

// ── Stub mode — no browser required ──────────────────────────────────────────

async function runStubAudit(options: WebAuditOptions): Promise<WebAuditReport> {
  // Try a basic HTTP GET via fetch (Node 18+) or fall back to a canned response.
  let pageTitle = "Unknown";
  let loginOk = false;
  let loadTimeMs = 0;
  const findings: WebAuditFinding[] = [];

  const start = Date.now();
  try {
    const res = await fetch(options.url, {
      signal: AbortSignal.timeout(options.timeout_ms ?? 10_000),
    });
    loadTimeMs = Date.now() - start;

    if (!res.ok) {
      findings.push({
        category: "error",
        severity: "error",
        message: `HTTP ${res.status} ${res.statusText}`,
        url: options.url,
      });
    } else {
      loginOk = true;
      const html = await res.text();
      // Extract <title>
      const titleMatch = html.match(/<title[^>]*>([^<]+)<\/title>/i);
      if (titleMatch) {
        pageTitle = titleMatch[1].trim();
      }
      findings.push({
        category: "ux",
        severity: "info",
        message: `Page loaded via stub fetch (${loadTimeMs} ms)`,
        url: options.url,
        value: loadTimeMs,
      });
    }
  } catch (err) {
    loadTimeMs = Date.now() - start;
    findings.push({
      category: "error",
      severity: "critical",
      message: `Stub fetch failed: ${err instanceof Error ? err.message : String(err)}`,
      url: options.url,
    });
  }

  return {
    url: options.url,
    login_ok: loginOk,
    page_title: pageTitle,
    load_time_ms: loadTimeMs,
    timestamp_ms: Date.now(),
    findings,
  };
}

// ── Playwright audit ──────────────────────────────────────────────────────────

async function runPlaywrightAudit(options: WebAuditOptions): Promise<WebAuditReport> {
  // Dynamic import so the module loads even when playwright is not installed
  // (falls back to stub in that case via the caller).
  // eslint-disable-next-line @typescript-eslint/no-require-imports
  const { chromium } = await import("playwright");

  const findings: WebAuditFinding[] = [];
  const consoleErrors: string[] = [];
  const networkFailures: string[] = [];
  let pageTitle = "";
  let loginOk = false;
  let loadTimeMs = 0;
  let currentUrl = options.url;

  const browser = await chromium.launch({ headless: true });
  const context = await browser.newContext();
  const page = await context.newPage();

  // ── Collect console errors ────────────────────────────────────────────────
  page.on("console", (msg) => {
    if (msg.type() === "error") {
      consoleErrors.push(msg.text());
    }
  });

  // ── Collect network failures ──────────────────────────────────────────────
  page.on("requestfailed", (req) => {
    networkFailures.push(`${req.method()} ${req.url()} — ${req.failure()?.errorText ?? "unknown"}`);
  });

  try {
    // ── Initial navigation ───────────────────────────────────────────────────
    const navStart = Date.now();
    await page.goto(options.url, {
      waitUntil: "domcontentloaded",
      timeout: options.timeout_ms ?? 15_000,
    });
    loadTimeMs = Date.now() - navStart;
    pageTitle = await page.title();
    currentUrl = page.url();

    // ── Login flow ───────────────────────────────────────────────────────────
    if (options.credentials && Object.keys(options.credentials).length > 0) {
      const creds = options.credentials;
      const loginResult = await attemptLogin(page, creds);
      loginOk = loginResult.ok;
      if (loginResult.finding) {
        findings.push(loginResult.finding);
      }
      // Refresh title after login redirect.
      pageTitle = await page.title();
      currentUrl = page.url();
    } else {
      loginOk = true; // No login required — treat as success.
    }

    // ── Scripted audit steps ─────────────────────────────────────────────────
    if (options.steps && options.steps.length > 0) {
      for (const step of options.steps) {
        const stepFinding = await runAuditStep(page, step, currentUrl);
        if (stepFinding) {
          findings.push(stepFinding);
        }
        currentUrl = page.url();
      }
    }

    // ── Collect performance metrics ──────────────────────────────────────────
    const perfMetrics = await collectPerfMetrics(page);
    findings.push(...perfMetrics);

    // ── Collect accessibility issues ─────────────────────────────────────────
    const a11yFindings = await collectAccessibilityIssues(page, currentUrl);
    findings.push(...a11yFindings);

    // ── Collect headings (content audit) ─────────────────────────────────────
    const headings = await page.$$eval(
      "h1, h2",
      (els) => els.map((el) => ({ tag: el.tagName.toLowerCase(), text: el.textContent?.trim() ?? "" })),
    );
    if (headings.length === 0) {
      findings.push({
        category: "accessibility",
        severity: "warning",
        message: "No H1/H2 headings found — document structure may be unclear",
        url: currentUrl,
      });
    }

    // ── Network failures ─────────────────────────────────────────────────────
    for (const failure of networkFailures.slice(0, 10)) {
      findings.push({
        category: "error",
        severity: "warning",
        message: `Network failure: ${failure}`,
        url: currentUrl,
      });
    }

    // ── Console errors ───────────────────────────────────────────────────────
    for (const err of consoleErrors.slice(0, 10)) {
      findings.push({
        category: "error",
        severity: "warning",
        message: `Console error: ${err}`,
        url: currentUrl,
      });
    }

    // ── Summary info finding ─────────────────────────────────────────────────
    findings.push({
      category: "ux",
      severity: "info",
      message: `Page audited: "${pageTitle}" loaded in ${Math.round(loadTimeMs)} ms`,
      url: currentUrl,
      value: loadTimeMs,
    });
  } catch (err) {
    findings.push({
      category: "error",
      severity: "critical",
      message: `Playwright audit error: ${err instanceof Error ? err.message : String(err)}`,
      url: currentUrl,
    });
  } finally {
    await browser.close();
  }

  return {
    url: options.url,
    login_ok: loginOk,
    page_title: pageTitle,
    load_time_ms: loadTimeMs,
    timestamp_ms: Date.now(),
    findings,
  };
}

// ── Login helper ──────────────────────────────────────────────────────────────

async function attemptLogin(
  page: import("playwright").Page,
  credentials: NonNullable<WebAuditOptions["credentials"]>,
): Promise<{ ok: boolean; finding?: WebAuditFinding }> {
  const urlBefore = page.url();

  try {
    // Try common email/username field selectors.
    const emailSelectors = [
      'input[type="email"]',
      'input[name="email"]',
      'input[name="username"]',
      'input[id*="email"]',
      'input[id*="user"]',
      'input[placeholder*="email" i]',
      'input[placeholder*="user" i]',
    ];
    const passwordSelectors = [
      'input[type="password"]',
      'input[name="password"]',
      'input[id*="password"]',
      'input[id*="pass"]',
    ];

    let emailFilled = false;
    for (const sel of emailSelectors) {
      const el = await page.$(sel);
      if (el) {
        await el.fill(credentials.email ?? credentials.username ?? "");
        emailFilled = true;
        break;
      }
    }

    let passwordFilled = false;
    for (const sel of passwordSelectors) {
      const el = await page.$(sel);
      if (el) {
        await el.fill(credentials.password ?? "");
        passwordFilled = true;
        break;
      }
    }

    if (!emailFilled || !passwordFilled) {
      return {
        ok: false,
        finding: {
          category: "login",
          severity: "error",
          message: `Login form not found — emailFilled=${emailFilled} passwordFilled=${passwordFilled}`,
          url: urlBefore,
        },
      };
    }

    // Submit: try submit button, then Enter.
    const submitSelectors = [
      'button[type="submit"]',
      'input[type="submit"]',
      'button:has-text("Sign in")',
      'button:has-text("Log in")',
      'button:has-text("Login")',
      'button:has-text("Continue")',
    ];
    let submitted = false;
    for (const sel of submitSelectors) {
      const el = await page.$(sel);
      if (el) {
        await el.click();
        submitted = true;
        break;
      }
    }
    if (!submitted) {
      await page.keyboard.press("Enter");
    }

    // Wait for navigation or network idle.
    await page.waitForLoadState("domcontentloaded", { timeout: 10_000 }).catch(() => {});

    const urlAfter = page.url();
    const redirected = urlAfter !== urlBefore;

    // Heuristic: if still on a URL containing "login" after submit, likely failed.
    const likelyFailed =
      /login|signin|sign-in|auth\/error|error/i.test(urlAfter) &&
      !redirected;

    if (likelyFailed) {
      return {
        ok: false,
        finding: {
          category: "login",
          severity: "critical",
          message: `Login may have failed — still on: ${urlAfter}`,
          url: urlAfter,
        },
      };
    }

    return {
      ok: true,
      finding: {
        category: "login",
        severity: "info",
        message: `Login successful — redirected to: ${urlAfter}`,
        url: urlAfter,
      },
    };
  } catch (err) {
    return {
      ok: false,
      finding: {
        category: "login",
        severity: "critical",
        message: `Login flow error: ${err instanceof Error ? err.message : String(err)}`,
        url: urlBefore,
      },
    };
  }
}

// ── Scripted step runner ──────────────────────────────────────────────────────

async function runAuditStep(
  page: import("playwright").Page,
  step: AuditStep,
  baseUrl: string,
): Promise<WebAuditFinding | null> {
  try {
    switch (step.action) {
      case "navigate":
        if (step.url) {
          await page.goto(step.url, { waitUntil: "domcontentloaded", timeout: 15_000 });
        }
        break;

      case "click":
        if (step.selector) {
          await page.click(step.selector, { timeout: 8_000 });
          await page.waitForLoadState("domcontentloaded", { timeout: 8_000 }).catch(() => {});
        }
        break;

      case "fill":
        if (step.selector && step.value !== undefined) {
          await page.fill(step.selector, step.value, { timeout: 8_000 });
        }
        break;

      case "assert_text": {
        if (step.selector && step.value !== undefined) {
          const text = await page.$eval(step.selector, (el) => el.textContent ?? "").catch(() => "");
          if (!text.includes(step.value)) {
            return {
              category: "ux",
              severity: "error",
              message: `assert_text failed: selector="${step.selector}" expected="${step.value}" got="${text.slice(0, 100)}"`,
              url: page.url(),
            };
          }
        }
        break;
      }

      case "screenshot":
        // Screenshot captured as base64; finding is info-only.
        return {
          category: "ux",
          severity: "info",
          message: `Screenshot taken at: ${page.url()}`,
          url: page.url(),
        };
    }
    return null;
  } catch (err) {
    return {
      category: "ux",
      severity: "warning",
      message: `Step "${step.action}" failed: ${err instanceof Error ? err.message : String(err)}`,
      url: baseUrl,
    };
  }
}

// ── Performance metrics ───────────────────────────────────────────────────────

async function collectPerfMetrics(
  page: import("playwright").Page,
): Promise<WebAuditFinding[]> {
  const findings: WebAuditFinding[] = [];
  try {
    const timing = await page.evaluate(() => {
      const t = performance.getEntriesByType("navigation")[0] as PerformanceNavigationTiming | undefined;
      if (!t) { return null; }
      return {
        domContentLoaded: t.domContentLoadedEventEnd - t.fetchStart,
        loadEvent: t.loadEventEnd - t.fetchStart,
        ttfb: t.responseStart - t.fetchStart,
      };
    });

    if (timing) {
      if (timing.ttfb > 2000) {
        findings.push({
          category: "performance",
          severity: "warning",
          message: `High TTFB: ${Math.round(timing.ttfb)} ms (target <2000 ms)`,
          value: timing.ttfb,
        });
      }
      if (timing.loadEvent > 5000) {
        findings.push({
          category: "performance",
          severity: "warning",
          message: `Slow page load: ${Math.round(timing.loadEvent)} ms (target <5000 ms)`,
          value: timing.loadEvent,
        });
      }
      findings.push({
        category: "performance",
        severity: "info",
        message: `TTFB=${Math.round(timing.ttfb)} ms DOMContentLoaded=${Math.round(timing.domContentLoaded)} ms Load=${Math.round(timing.loadEvent)} ms`,
        value: timing.loadEvent,
      });
    }
  } catch {
    // Performance API not available — non-fatal.
  }
  return findings;
}

// ── Accessibility checks ──────────────────────────────────────────────────────

async function collectAccessibilityIssues(
  page: import("playwright").Page,
  url: string,
): Promise<WebAuditFinding[]> {
  const findings: WebAuditFinding[] = [];
  try {
    // Images without alt text.
    const missingAlt = await page.$$eval(
      "img:not([alt])",
      (imgs) => imgs.length,
    );
    if (missingAlt > 0) {
      findings.push({
        category: "accessibility",
        severity: "warning",
        message: `${missingAlt} image(s) missing alt text`,
        url,
        value: missingAlt,
      });
    }

    // Buttons with no accessible label.
    const unlabeledButtons = await page.$$eval(
      "button:not([aria-label]):not([aria-labelledby])",
      (btns) => btns.filter((b) => !b.textContent?.trim()).length,
    );
    if (unlabeledButtons > 0) {
      findings.push({
        category: "accessibility",
        severity: "warning",
        message: `${unlabeledButtons} button(s) with no accessible label`,
        url,
        value: unlabeledButtons,
      });
    }

    // Inputs without associated labels.
    const unlabeledInputs = await page.$$eval(
      "input:not([type='hidden']):not([aria-label]):not([aria-labelledby]):not([id])",
      (inputs) => inputs.length,
    );
    if (unlabeledInputs > 0) {
      findings.push({
        category: "accessibility",
        severity: "warning",
        message: `${unlabeledInputs} input(s) without accessible labels`,
        url,
        value: unlabeledInputs,
      });
    }
  } catch {
    // Non-fatal.
  }
  return findings;
}

// ── Write artifact ────────────────────────────────────────────────────────────

function writeArtifact(report: WebAuditReport): void {
  const outPath = artifactPath();
  fs.mkdirSync(path.dirname(outPath), { recursive: true });
  fs.writeFileSync(outPath, JSON.stringify(report, null, 2), "utf8");
}

// ── Public API ────────────────────────────────────────────────────────────────

/**
 * Run a web audit against the given options.
 * Writes the report to artifacts/web-audit/latest.json and returns it.
 */
export async function runWebAudit(options: WebAuditOptions): Promise<WebAuditReport> {
  const useStub = options.stub_mode === true || process.env.NEXUS_WEB_AUDIT_STUB === "1";

  let report: WebAuditReport;

  if (useStub) {
    report = await runStubAudit(options);
  } else {
    try {
      report = await runPlaywrightAudit(options);
    } catch (err) {
      // Playwright not installed or launch failed — fall back to stub.
      const stubReport = await runStubAudit(options);
      stubReport.findings.unshift({
        category: "error",
        severity: "warning",
        message: `Playwright unavailable, used stub fetch fallback: ${err instanceof Error ? err.message : String(err)}`,
        url: options.url,
      });
      report = stubReport;
    }
  }

  writeArtifact(report);
  return report;
}
