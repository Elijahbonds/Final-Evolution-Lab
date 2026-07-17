# M13-04 · P2 — Dunk Contest (Venice Beach Court)

## Observed (live playtest, guest `/try` + account)

1. **The ball is never in the player's hands.**
   - During the drive, the ball sits detached ON THE FLOOR beside/behind the runner.
   - During the entire flight and slam window the ball is INVISIBLE — not in frame,
     not in hand. "GREAT · +2.0 PTS" scores with no ball ever touching the rim visually.
   - This is the root of "you can't watch the ball on its flight path to the rim":
     there is no ball flight to watch.
2. **Slam QTE is a UI-bar exercise.** You time SPACE off a small green/yellow meter at
   mid-screen left while the player floats near the rim. Eyes are forced OFF the action.
3. **Airborne pose is one static spread-arm glide** regardless of style picked; POWER /
   FLASHY / SIG are indistinguishable in the air (see doc 01 clip map).
4. **Style cards stay on screen through the slam window,** covering center-frame where
   the action is.
5. **Opponent is a static pink capsule minifig** that never moves or takes its turn.
   Scoreboard says "DUNK · FIRST TO 21" but the opponent scored 0 across ~20 attempts —
   there is no visible opposing turn.
6. **Score format:** "0.0 / 2.0" reads oddly; misses print "MISS · +0.0 PTS".
7. **Environment reads as flooded ruins, not Venice Beach:** the court surface is dark
   reflective water-like material, palm trees are shattered black polygon clumps,
   surrounding buildings look like collapsed debris, and water surrounds/covers the
   playfield. Golden-hour sky and pink rim/backboard are good and worth keeping.
8. **Landing has no weight** — same idle pose on touchdown, no crouch, no crowd/impact
   beat (crowd doesn't exist).

## Required fix

### Ball pipeline (the headline fix)
- Parent the ball to the runner's hand socket during drive/gather/rise (switch to
  two-hand carry on gather).
- At the slam, drive the ball along an authored hand→rim path; on release/flush,
  activate net physics/animation and a rim-shake.
- On MISS, the ball must visibly clank off rim/backboard and bounce away — misses
  currently just print text.
- The slam timing window should correspond to the player+ball arriving at the rim so
  the QTE is timeable by watching the dunk itself. Keep the bar as a secondary cue,
  smaller, docked near the rim.

### Style identity
- Three distinct air clips + apex silhouettes (doc 01). Style cards collapse to small
  icons once a style is locked; nothing overlaps center frame during the slam.

### Opponent turn
- Replace capsule with a skinned rival using the same animation set; alternate
  attempts (player dunk → rival dunk) so "FIRST TO 21" is a real duel. Rival make
  probability tuned by difficulty/DDA.

### Presentation
- Impact hold (0.2–0.3 s) + landing crouch + score pop AT THE RIM, not only in the HUD.
- Integer or one-decimal points consistently; misses show "MISS" without "+0.0 PTS".

### Environment pass (Venice Beach Court)
- Court: opaque concrete/asphalt material with painted lines — kill the water-mirror
  floor. Water belongs beyond the boardwalk edge only.
- Palm trees: replace shattered geometry with intact low-poly palms.
- Replace debris blocks with boardwalk set dressing (rail, shops facade, pier lights).
- Add a minimal crowd strip (billboards/sprites acceptable at M13) that reacts on
  GREAT/PERFECT.

## Acceptance
- Recorded attempt shows the ball in hand during the run, in flight with the player,
  through the net on make, off the rim on miss — trackable end to end at full speed.
- The three styles are visually tellable apart with the HUD hidden.
- Rival takes visible alternating turns and can reach 21 first.
- Court floor is opaque; no debris clumps; palms intact.
