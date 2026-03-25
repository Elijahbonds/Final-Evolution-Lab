# Dark Clinical — Wix ↔ App HUD (Bonds Standard)

Use these tokens so **FinalEvolutionGroup.com** (Wix) matches the **iOS / Unreal** shell (deep blacks, neon cyan, clinical blue).

| Token | Hex | Usage |
|--------|-----|--------|
| **BG Deep** | `#0a0c10` | Page background, PWA `--bg-deep` |
| **BG Card** | `#12151c` at 65% opacity | Sections, cards |
| **Accent Cyan** | `#5ce1e6` | Headings, badges, “Sovereign” highlights — matches `Theme.brandCyan` |
| **Accent Blue** | `#1e90ff` | Primary buttons, links — matches `Theme.brandBlue` |
| **Body** | `#e8f4ff` at 88–92% opacity | Paragraph text |
| **Border** | `rgba(92, 225, 230, 0.18–0.24)` | 1px clinical frames |

**Typography:** SF Pro / system sans; uppercase micro-labels with `letter-spacing: 0.22–0.35em` for “forensic” section headers (mirrors app tab chrome).

**JOIN NOW button:** Fill `#1e90ff`, text white; hover slightly brighter blue; never pure white page background on marketing pages.

Reference implementations: `web/shared/fel-clinical.css`, `web/play/index.html` inline theme, Swift `Theme.swift`.
