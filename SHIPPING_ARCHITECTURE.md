# Final Evolution Lab — Shipping Architecture

> **Leadership decision (canonical):** Unreal Engine 5.7 is the production shipping target.

## Production shipping target (single path)

- **Game host:** Unreal Engine 5.7 project at `~/Developer/FinalEvolutionLab57/FinalEvolutionLab.uproject`.
- **In-game OS / dashboard:** native iOS `WKWebView` overlay inside Unreal.
- **Native iOS:** Swift/SwiftUI code is integration/reference support only unless explicitly wired into the Unreal-host build.
- **Unity 6:** reference/prototype track only; not the production shipping host.

Do not treat Unity export, Swift-first navigation, Unreal-as-a-Library, or XCFramework embedding as the default shipping path.

---

## Authoritative build path

```bash
cd "$HOME/Documents/rork-final-evolution-lab"
UPROJECT="$HOME/Developer/FinalEvolutionLab57/FinalEvolutionLab.uproject" \
SKIP_GENERATE=1 \
./fel_ue5_ios_shipping_package.sh --full-cook --shipping --export-ipa
```

Verify descriptor-safe cooked payload:

```bash
cd "$HOME/Documents/rork-final-evolution-lab"
UE_PROJECT="$HOME/Developer/FinalEvolutionLab57" \
./infra/fix_ios_descriptor_path.sh
```

Install to device:

```bash
xcrun devicectl device install app \
  --device "00008140-001079E402FA801E" \
  "$HOME/Developer/FinalEvolutionLab57/Binaries/IOS/FinalEvolutionLab.app"
```

Expected IPA: `~/Developer/FinalEvolutionLab57/Binaries/IOS/FinalEvolutionLab.ipa`

---

## Distribution

- **App Store Connect / TestFlight** — primary distribution channel
- **Superapp** — tracks release metadata only (does not host an install feed)
- **No:** sideload / AltStore / Sovereign Store language
- **No:** app switching between separate apps
- **No:** Unreal-as-a-Library / XCFramework embedding

---

## Architecture decisions (locked)

| Decision | Value |
|----------|-------|
| Game host | Unreal Engine 5.7 |
| iOS app model | One retail iOS app |
| Dashboard | Native WKWebView overlay inside Unreal |
| Unity | Reference/prototype only |
| SwiftUI | Not the app shell |
| UaaL / XCFramework | Not used |
| Distribution | App Store Connect / TestFlight |

---

## Anti-drift rule for agents

```
Unreal Engine 5.7 is the production target.
Do not implement new production gameplay in Unity.
Do not revive SwiftUI-first hosting.
Do not use Unreal-as-a-Library or XCFramework embedding.
Do not create a second app.
The shipping app is:
  Unreal host + native WKWebView dashboard overlay + App Store/TestFlight distribution.
Unity and SwiftUI remain useful references, but production fixes must land in the
Unreal project, Unreal integration code, iOS packaging scripts, dashboard bridge,
cooked payload verification, privacy keys, and App Store release pipeline.
```

---

*Last updated: Unreal Engine 5.7 re-baseline per leadership decision.*
