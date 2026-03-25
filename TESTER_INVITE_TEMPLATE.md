# Final Evolution — DA COMPOUND TestFlight invite (1.0.0 Ignition)

Use this note when inviting athletes to the **TestFlight** build. Replace bracketed fields before sending.

---

**Subject:** Final Evolution — TestFlight access (System Scan + AI Coach)

Hi [Name],

You have been added to the **Final Evolution** TestFlight. Install the build from the TestFlight app on your iPhone, then sign in with your Apple ID if prompted.

## System Scan (forensic movement capture)

1. Open **Final Evolution** and go to the **Lab** tab (or the entry point labeled **System Scan** / biomechanics flow in your build).
2. Start **System Scan** from the Lab dashboard when you are ready to record. For best results, use **bright, even lighting** — on the **Arena** tab, `ArenaView.swift` runs a **Lighting Check**; if ambient light is too low, the **Lighting Pause Overlay** (blurred full-screen layer, sun icon) appears with: *“Forensic Scan Paused: Increase Ambient Light for 1.0.0 Accuracy.”* Move to a brighter area before relying on forensic scan data.
3. Complete the scan so your profile and **readiness** data stay aligned with the **Unreal Arena** handshake (`readiness_snapshot.json`).

## AI Coach — fatigue alerts

- After sessions or when the coach model flags fatigue, watch the **Arena** tab: a **System Scan**–related banner can appear when **fatigue** is detected so you know to prioritize recovery.
- Longer-term **AI Coach** insights and metrics that follow **`readiness_snapshot.json`** are surfaced from the **Lab** / **Athlete Hub** flows after you stay signed in post–System Scan (see in-app copy: *“AI Coach metrics follow readiness_snapshot.json — stay signed in after System Scan.”*)

## Troubleshooting — “Compromised Data” flags

If the app or coach flow indicates **compromised** or **inconsistent** biometric data (Unreal `Validation_StressTest` / readiness export):

1. **Lighting** — Open the **Arena** tab (`ArenaView.swift`) and ensure the **Lighting Pause Overlay** is **not** blocking: you should **not** see the blurred forensic pause with the sun icon and *“Forensic Scan Paused…”* copy. Move to **brighter, even** light until the overlay dismisses and the **Calibration Progress** bar can complete under optimal lighting.
2. **System Scan** — Re-run **System Scan** from the **Lab** with a clear, well-lit capture so **height/weight** scales and **flight time** match real movement.
3. **Sovereign gear** — If bonuses did not record after a session, complete another scan-aligned session; the engine withholds Sovereign writes when **physics integrity** checks fail (protects twin parity).
4. **Still stuck** — Force-quit and relaunch, then repeat Scan → Arena. Contact [support channel] with your **TestFlight build number**.

## Need help?

Reply to this thread or contact [support channel].

— [Your name], Final Evolution / DA COMPOUND
