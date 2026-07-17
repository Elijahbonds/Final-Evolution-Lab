# M13-08 — QA Acceptance Checklist (run before calling M13 done)

Run on BOTH: desktop Chrome 1280×800 (keyboard) and a phone-sized touch viewport
(430×932). Record video of each mode.

## Global (every mode)
- [ ] Ready gate: no live input accepted before explicit start; 3-2-1 countdown plays.
- [ ] Controller overlay renders on touch; every button drives the same action as its key.
- [ ] Desktop hint bar matches the actual bindings (generated from the same config).
- [ ] Every state-changing input plays a visible animation within 100 ms.
- [ ] Character faces movement direction, or its engagement target when engaged.
- [ ] Player + objective (ball/rim/target/gate) in frame 100% of active play.
- [ ] Camera never auto-switches modes mid-attempt; toggle works (button + C).
- [ ] No pink capsule placeholders anywhere.
- [ ] No raw tuning values (AGGR/SPD/etc.) on the player HUD.
- [ ] Loads clean; no frame where the ground plane is invisible/black.

## Dunk Contest
- [ ] Ball in hand during drive; ball visible and trackable through entire flight;
      through the net on make, off the rim on miss.
- [ ] Slam timeable by watching the player reach the rim (bar is secondary, near rim).
- [ ] POWER / FLASHY / SIG have visibly different air animations.
- [ ] Style cards shrink after lock; center frame clear during slam.
- [ ] Skinned rival takes alternating turns; can win to 21.
- [ ] Court floor opaque concrete; intact palms; no debris; crowd reaction on GREAT+.
- [ ] Landing crouch + impact hold on every made dunk.

## Karate (Endless + Versus)
- [ ] Fighters square up automatically; all five attacks play clips; hit-reacts + KO falls.
- [ ] Wave clears ONLY via KOs; banner count == actual KOs; wave-clear beat between waves.
- [ ] HP + chi meters visible; pillar never occludes the fight.
- [ ] Versus: KO freeze-frame + round banner; best-of-3 flow correct.

## Board sports (Skate · Surf · Snowboard)
- [ ] Surface lit, textured, opaque at every camera angle reached in play.
- [ ] Camera elevated with downward pitch floor; ground always in lower frame.
- [ ] Board contacts surface with contact shadow; landing compression plays.
- [ ] Trick inputs play clips and score.

## Street Football
- [ ] Skinned defenders with run cycles pursue on real angles; dive/whiff anims.
- [ ] Juke L/R, spin, hurdle, stiff-arm all play clips and can evade moving defenders.
- [ ] Runner sprint cycle, football mesh tucked, faces down-field.
- [ ] Grace distance after gate; average first run ≥ 30 yd; breakaway state past 50.
- [ ] Yard markers, end zone, TD celebration.

## Guest funnel (`/try`)
- [ ] Fully playable with thumbs on a phone; overlay present; no keyboard-only hints.
- [ ] First dunk achievable inside 60 seconds by a new player.
- [ ] Claim-athlete CTA appears after the session.

## Meta (verify not regressed)
- [ ] Result screens (XP/shards/credits/PRQ Δ/season XP) still correct.
- [ ] Season pass tier progress, CHALLENGE A FRIEND, REPLAY, HUB buttons work.
- [ ] PRQ updates in the top bar after a session.
