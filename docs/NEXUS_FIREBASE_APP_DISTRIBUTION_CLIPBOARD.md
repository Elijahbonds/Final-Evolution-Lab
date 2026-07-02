# NEXUS — Firebase App Distribution “Click to copy URL” (iOS)

**Date:** 2026-06-19  
**Repos searched:** `/Users/elijahbonds/Final-Evolution-Lab` (canonical NEXUS ship), `/Users/elijahbonds/Documents/rork-final-evolution-lab` (legacy mirror)  
**Ship target:** NEXUS iOS (Swift + Metal engine) — **not** Unreal `FELIOSWebOverlay`  
**Reference image:** `image_2.png` (requested from workspace/uploads) — **not found** in either repo or Cursor uploads; analysis is code-based.

---

## Executive summary

| Question | Answer |
|----------|--------|
| **Where does copy fail?** | Almost certainly **outside the NEXUS app** — on the **Firebase Console** App Distribution web UI (`console.firebase.google.com`) opened in **iOS Safari** or a **third-party in-app browser** (Mail, Slack, Teams, etc.). |
| **Is NEXUS WKWebView the cause?** | **No** for current ship. NEXUS has one `WKWebView` (NEXUS Studio `editor.html` bundle only). No Swift surface loads Firebase Console or App Distribution invite pages. |
| **Is NEXUS overlay blocking taps?** | **No** for Firebase Console. In-app `FELOverlayView` uses `.allowsHitTesting(false)` and only draws a PRQ badge. |
| **Recommended fix for testers** | Use **desktop Safari/Chrome**, **long-press** the visible URL, or **Open in Safari** from email — not an in-app browser. No NEXUS Swift patch required today. |

**Root-cause hypothesis:** **A — Firebase Console in Safari / embedded browser (NOT NEXUS)**  
**Confidence:** High (code audit shows no in-app Firebase web surface; pattern matches iOS `navigator.clipboard` restrictions).

---

## 1. WebView inventory (both repos)

### NEXUS iOS (canonical — production ship)

| Surface | Path | Web tech | Loads Firebase / App Distribution? |
|---------|------|----------|-----------------------------------|
| **NEXUS Studio editor** | `FinalEvolutionLab/Views/NexusStudio/NexusStudioCodeEditorView.swift` + `FinalEvolutionLab/Resources/NexusStudio/editor.html` | `WKWebView`, local file `loadFileURL` | **No** — bundled editor only; bridge handler `contentChanged` |
| **Streaming Portal** | `FinalEvolutionLab/Views/StreamingPortalView.swift` | Native SwiftUI | **No** |
| **HLS player** | `FinalEvolutionLab/Views/HlsPlayerView.swift` | `AVPlayer` / `VideoPlayer` | **No** |
| **Game HUD overlay** | `FinalEvolutionLab/Views/FELOverlayView.swift` | SwiftUI (`.allowsHitTesting(false)`) | **No** |
| **External links** | `DoorDashOrderBridgeView`, `CookbookView`, `NEXUSCursorBridge` | `UIApplication.shared.open(url)` → system Safari | **No embedded browser** |
| **Clipboard (native)** | `NEXUSCursorBridge.swift`, `NEXUSAgentService.swift`, `SettingsSheet.swift` | `UIPasteboard.general.string = …` | N/A — native copy, not web |

**Grep result:** No `SFSafariViewController`, `ASWebAuthenticationSession`, or generic in-app browser in NEXUS Swift.

### Legacy / mirror only (not NEXUS retail ship)

| Surface | Path | Notes |
|---------|------|-------|
| **FELIOSWebOverlay** | `UnrealIntegration/Source/FinalEvolutionLab/FELIOSWebOverlay.mm` | UE in-process `WKWebView`; `FELBridge` JS injection; **no clipboard bridge**; not used in NEXUS ship |
| **UE WebBrowser HUD** | `UnrealIntegration/.../BPFL_HUDManager.*` | CEF `UWebBrowser` for React HUD |
| **FELOSDashboard (web)** | `frontend/src/components/FELOSDashboard.js` | `navigator.clipboard.writeText(passUrl)` on share modal — same async-clipboard pitfall as Firebase Console if ever hosted in WKWebView |

Mirror repo (`rork-final-evolution-lab`) matches the same NEXUS Swift layout; trailing canonical by design per `README_NEXUS_CANONICAL.md`.

---

## 2. Hypothesis matrix

### A) Firebase Console in Safari (or Mail/Slack in-app browser) — **LIKELY**

Firebase App Distribution release UI (“Click to copy URL” for tester invite / public link) runs on `https://console.firebase.google.com/.../appdistribution/...`.

**Why the button appears dead on iPhone:**

1. **Async clipboard write** — If the button calls an API first, then `navigator.clipboard.writeText()` in the success handler, iOS treats that as **not a direct user gesture** and silently rejects the write ([Safari clipboard behavior](https://community.wappler.io/t/write-to-clipboard-safari-behavior/58651)).
2. **Embedded WKWebView in other apps** — Opening the console link from Mail/Slack uses a host app `WKWebView`. Clipboard API is **more restricted** than standalone Safari; failures often show **no error UI** (button looks like it did nothing).
3. **Secure context** — Console is HTTPS (OK), but gesture + embedding rules still apply.
4. **Not a NEXUS bug** — User is in browser/console, not inside Final Evolution Lab.

**How to confirm:** Reproduce on **Mac desktop Chrome** (copy works) vs **iPhone Safari** on the same releases page. If desktop works and phone fails → A.

### B) In-app WKWebView inside NEXUS loading App Distribution page — **UNLIKELY**

NEXUS does not navigate `WKWebView` to `console.firebase.google.com` or `appdistribution.firebase.google.com`. The only `WKWebView` loads `editor.html` from the app bundle.

**Exception (not NEXUS):** Legacy `FELIOSWebOverlay.mm` could load arbitrary URLs in UE builds, still without clipboard bridge — irrelevant to NEXUS ship.

### C) Custom Nexus overlay blocking clicks — **RULED OUT**

- `FELOverlayView`: `.allowsHitTesting(false)` — does not intercept taps.
- `ContentView` places overlay top-trailing only; does not cover full screen for hit testing.
- Firebase Console is not rendered inside NEXUS.

---

## 3. Deliverable — four investigation questions

### 3.1 Common custom engine / mobile WebView clipboard issues

| Issue | Symptom | Applies to NEXUS? |
|-------|---------|-------------------|
| `navigator.clipboard.writeText()` without synchronous user gesture | Button tap does nothing; no toast | Firebase Console (A); legacy web dashboard if overlaid |
| WKWebView lacks native clipboard bridge | Same silent failure in embedded browsers | Only if NEXUS later embeds remote HTTPS pages |
| `document.execCommand('copy')` deprecated / blocked | Older fallback also fails on iOS | Third-party in-app browsers |
| Cross-origin iframe copy | Copy button in iframe blocked | Possible in Google Console SPA |
| iOS 16+ pasteboard permission alerts | “Allow paste” dialogs on **read**, not write | Firebase Dynamic Links install flow (different feature) |
| Missing `WKUIDelegate` for `requestMediaCapturePermission` etc. | Unrelated to clipboard | — |

**NEXUS Studio** does not use clipboard APIs in `editor.html`; editor bridge is `contentChanged` only.

### 3.2 Nexus security policies that might block clipboard

Audit of `NexusStudioCodeEditorView.swift` and legacy `FELIOSWebOverlay.mm`:

| Setting | NEXUS Studio | Legacy FELIOSWebOverlay |
|---------|--------------|-------------------------|
| `javaScriptEnabled` | Default **on** (not explicitly disabled) | Default **on** |
| `allowsLinkPreview` | Not set (default) | Not set |
| Content blockers | None configured | None |
| `WKUserContentController` | `contentChanged` handler only | `FELBridge` injection at document start |
| Remote URL loading | **Disabled** (local bundle only) | Can `loadRequest:` arbitrary URL |
| App Transport Security | Standard; no Firebase console exception needed | Same |

**Conclusion:** NEXUS does not apply policies that would block Firebase Console — because it never hosts that page. Failures are upstream (browser / Google web app).

### 3.3 Debug steps + JS snippet (WebView / Safari)

**Step 1 — Identify context**

On the device where copy fails, note:

- Standalone **Safari** vs **in-app** browser (address bar often minimal in embedded views)
- iOS version
- URL host: `console.firebase.google.com` vs `appdistribution.firebase.google.com`

**Step 2 — Safari Web Inspector (Mac + USB iPhone)**

1. iPhone: Settings → Safari → Advanced → Web Inspector ON  
2. Mac Safari → Develop → [device] → select Firebase Console tab  
3. Console tab: tap “Click to copy URL”, watch for errors:

```text
NotAllowedError: Write permission denied.
DOMException: The request is not allowed by the user agent or the platform.
```

**Step 3 — Paste test**

After tap, focus Notes and paste. Empty paste = write failed (not UI-only).

**Step 4 — In-page clipboard probe (paste in Web Inspector console)**

Run **synchronously** on a button you add via console, or evaluate in a test `WKWebView`:

```javascript
(function () {
  const probe = document.createElement('button');
  probe.textContent = 'NEXUS clipboard probe';
  probe.style.cssText = 'position:fixed;bottom:12px;left:12px;z-index:99999;padding:12px;';
  probe.onclick = async () => {
    const text = location.href;
    let ok = false, err = '';
    try {
      if (navigator.clipboard && navigator.clipboard.writeText) {
        await navigator.clipboard.writeText(text);
        ok = true;
      }
    } catch (e) { err = String(e); }
    if (!ok) {
      try {
        const ta = document.createElement('textarea');
        ta.value = text;
        ta.style.position = 'fixed';
        ta.style.left = '-9999px';
        document.body.appendChild(ta);
        ta.focus();
        ta.select();
        ok = document.execCommand('copy');
        document.body.removeChild(ta);
      } catch (e2) { err += ' | ' + String(e2); }
    }
    alert(ok ? 'CLIPBOARD OK: ' + text.slice(0, 80) : 'CLIPBOARD FAIL: ' + err);
    console.log('[NEXUS probe]', { ok, err, href: text });
  };
  document.body.appendChild(probe);
})();
```

- **Probe OK, Firebase button fails** → Firebase UI uses async copy after network (gesture chain broken).  
- **Probe fails in embedded browser, OK in Safari** → Hypothesis A (host app WKWebView).  
- **Probe fails everywhere on device** → OS / profile restriction (rare).

**Step 5 — NEXUS app sanity check**

Open NEXUS → NEXUS Studio (if available). Confirm editor loads; no Firebase URL in network tab. Copy issue is **not** reproducible inside NEXUS for App Distribution.

### 3.4 How to grant clipboard in Nexus (if you add in-app web later)

**Not required for current Firebase Console issue.** Reference patterns for a future `WKWebView` that loads HTTPS admin pages:

#### Option 1 — `WKScriptMessageHandler` + `UIPasteboard` (recommended for WKWebView)

Swift (inject at document start):

```swift
// Register: userContentController.add(handler, name: "felClipboard")
let js = """
window.felCopyToClipboard = function(text) {
  window.webkit.messageHandlers.felClipboard.postMessage(String(text || ''));
};
"""
```

Handler:

```swift
func userContentController(_ ucc: WKUserContentController, didReceive message: WKScriptMessage) {
    guard message.name == "felClipboard", let text = message.body as? String else { return }
    UIPasteboard.general.string = text
    // Optional: FelToastCenter.shared.show("Copied to clipboard")
}
```

Firebase/Google pages would need to call `window.felCopyToClipboard(url)` — you cannot patch Google’s bundle; so this only helps **your** web surfaces.

#### Option 2 — `evaluateJavaScript` from native after user action

Native toolbar “Copy link” that reads `webView.url?.absoluteString` and sets `UIPasteboard.general.string`.

#### Option 3 — `SFSafariViewController` (recommended for Firebase Console)

For any future in-app link to Firebase Console:

```swift
import SafariServices
// Present SFSafariViewController(url: consoleURL) — uses system Safari cookie store + full clipboard behavior
```

**Best practice for testers today:** Open distribution links in **standalone Safari** or **desktop browser**, not inside NEXUS or email clients.

---

## 4. Swift fix status

| Component | Action |
|-----------|--------|
| `StreamingPortalView` | No change — no WebView |
| `HlsPlayerView` | No change — AVPlayer only |
| `NexusStudioCodeEditorView` | No change — no Firebase pages |
| `FELOverlayView` | No change — does not block hits |
| New clipboard bridge | **Deferred** — not needed until NEXUS embeds remote web with copy actions |

---

## 5. Tester workarounds (recommended)

1. **Desktop** — Open [App Distribution releases](https://console.firebase.google.com/project/final-evolution-lab/appdistribution/app/ios:com.finalevolutionlab.app/releases) on Mac/PC; use “Click to copy URL” there.
2. **iPhone Safari** — Long-press the **visible URL text** on the release card (if shown) → Copy. Or tap Share → Copy.
3. **Email invite** — Open invite in **Safari** (tap share icon → “Open in Safari”), not the Mail inline browser.
4. **CLI alternative** — Distribute with tester emails via `fastlane` / Firebase CLI; testers receive email with link (no console copy needed). See `infra/FIREBASE_APP_DISTRIBUTION.md`, `fastlane/Fastfile`.
5. **Firebase App Tester app** — Install from App Store; accept invite in-app (separate from console copy button).

Related checklist: `Config/FEL_FIREBASE_TESTFLIGHT_CHECKLIST.txt` (bundle ID `com.finalevolutionlab.app`, ad-hoc IPA path).

---

## 6. Handoff

### Root cause hypothesis

**Primary: A — Firebase Console / Safari (or third-party in-app browser) clipboard API restrictions**, not NEXUS engine or overlay.

**Secondary (only if user insists they are inside NEXUS):** Re-check reproduction — NEXUS has no App Distribution web UI; they may be conflating the **Firebase App Tester** app or **Safari** with NEXUS.

### Recommended fix for user testers

| Audience | Action |
|----------|--------|
| **QA / internal testers** | Copy invite URLs on **desktop browser** or **long-press in Safari**; distribute IPA via console upload + email testers (`Config/FEL_FIREBASE_TESTFLIGHT_CHECKLIST.txt` LANE A). |
| **Engineering** | No NEXUS Swift hotfix for this report. If product later embeds Firebase Console in-app, ship `SFSafariViewController` or a `felClipboard` WK bridge per §3.4. |
| **Firebase Console UX** | Optional Google-side issue: copy button may use async `writeText` after fetch — fails iOS gesture rules; not fixable from NEXUS repo. |

### Evidence gaps

- `image_2.png` not located — if provided later, verify Safari vs in-app chrome vs NEXUS UI in screenshot.
- Live repro on tester device not run in this pass (code-only audit).

### Files referenced

- `FinalEvolutionLab/Views/NexusStudio/NexusStudioCodeEditorView.swift`
- `FinalEvolutionLab/Views/FELOverlayView.swift`
- `FinalEvolutionLab/Views/StreamingPortalView.swift`
- `FinalEvolutionLab/Views/HlsPlayerView.swift`
- `UnrealIntegration/Source/FinalEvolutionLab/FELIOSWebOverlay.mm` (legacy)
- `Config/FEL_FIREBASE_TESTFLIGHT_CHECKLIST.txt`
- `infra/FIREBASE_APP_DISTRIBUTION.md`
