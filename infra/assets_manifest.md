# FEL Assets Manifest (per mode)

Generated from `backend/FEL_ModeManager.production.json` (22 registered modes; movement-adjacent modules included).
Formats: models/animations glTF 2.0 preferred (pipeline also ingests FBX/BVH/GLB via `scripts/asset_pipeline/`); textures PNG/JPG (2K); audio WAV/CAF.
License floor: CC0 / public domain / CC-BY (with attribution in `infra/ASSET_ATTRIBUTION.md`) / owner-generated (Meshy, DeepMotion).
`present_in_repo` fields reference assets already integrated on `feature/phase2-input-design-tokens`.

## basketball_h2h  —  High priority
1v1 street basketball to 21
- Animations: idle, dribble, dribble_cross, run, sprint, jump_shot, layup, dunk, block, steal, celebrate, defeat
- Props: basketball, hoop_with_net, court_markings
- Environment: Venice blacktop court · sky: beach/outdoor 2k HDRI · ground: asphalt/PBR · IN REPO: VenueVeniceBlacktop.usdz + BackgroundBasketball.png (feature branch)
- Audio: crowd_loop, buzzer, score_sting, ui_confirm, ball_bounce, net_swish, rim_clank, sneaker_squeak
- Notes: Owner DeepMotion dunk/dribble mocap staged (assets/motion); CMU 06_xx dribble/shoot BVH downloaded.

## basketball_dunk  —  Medium priority
2D dunk contest (canvas)
- Animations: dunk, approach_run, celebrate
- Props: basketball
- Environment: 2D court backdrop · sky: beach/outdoor 2k HDRI · ground: asphalt/PBR
- Audio: crowd_loop, buzzer, score_sting, ui_confirm, rim_clank, crowd_hype

## basketball_dunk_3d  —  High priority
3D judged dunk contest
- Animations: idle, approach_run, launch, dunk, windmill, tomahawk, between_legs, land, celebrate
- Props: basketball, hoop_with_net, judge_table
- Environment: Venice blacktop court · sky: beach/outdoor 2k HDRI · ground: asphalt/PBR · IN REPO: VenueVeniceBlacktop.usdz; ElijahDunk.usdz rim-normalized 3.05m; NPC judges
- Audio: crowd_loop, buzzer, score_sting, ui_confirm, rim_clank, net_swish, crowd_hype, announcer_sting
- Notes: 6 real ElijahDunkMSDunks crops processed in assets/motion/clips (feature branch).

## basketball_dunk_irl  —  Low priority
IRL camera-judged dunk
- Animations: —
- Props: —
- Environment: camera passthrough · sky: n/a · ground: n/a
- Audio: crowd_loop, buzzer, score_sting, ui_confirm, announcer_sting

## basketball_3v3  —  Medium priority
3v3 streetball
- Animations: idle, dribble, dribble_cross, run, sprint, jump_shot, layup, dunk, block, steal, celebrate, defeat, pass, receive
- Props: basketball, hoop_with_net
- Environment: Venice blacktop court · sky: beach/outdoor 2k HDRI · ground: asphalt/PBR · IN REPO: VenueVeniceBlacktop.usdz
- Audio: crowd_loop, buzzer, score_sting, ui_confirm, ball_bounce, net_swish

## karate_h2h  —  High priority
1v1 sparring with strikes/blocks
- Animations: fight_idle, jab, hook, uppercut, roundhouse_kick, high_kick, block, perfect_guard, hit_react, ko_fall, celebrate
- Props: dojo_mat
- Environment: Shimogamo dojo interior · sky: indoor dojo HDRI · ground: tatami/wood PBR · IN REPO: VenueShimogamoDojo.usdz; ElijahStrike*.usdz clips wired to face buttons
- Audio: crowd_loop, buzzer, score_sting, ui_confirm, strike_whoosh, impact_thud, gi_rustle, kiai_shout
- Notes: Strike set acquired via Meshy presets (actions 191/193/195/207/215/209).

## karate_endless  —  High priority
Wave survival karate
- Animations: fight_idle, jab, roundhouse_kick, block, hit_react, ko_fall, wave_taunt
- Props: stage_platform
- Environment: Muscle Beach stage · sky: beach/outdoor 2k HDRI · ground: asphalt/PBR · IN REPO: VenueMuscleBeachStage.usdz + BackgroundMuscleBeach.png
- Audio: crowd_loop, buzzer, score_sting, ui_confirm, strike_whoosh, impact_thud, wave_horn

## baseball  —  Medium priority
Home-run derby swing timing
- Animations: bat_idle, bat_swing, watch_flight, celebrate
- Props: baseball_bat, baseball, backstop
- Environment: Catalina beach ballpark · sky: beach/outdoor 2k HDRI · ground: asphalt/PBR · IN REPO: VenueBallpark.usdz + PropsBaseball.usdz + BackgroundBaseball.png
- Audio: crowd_loop, buzzer, score_sting, ui_confirm, bat_crack, mitt_catch, organ_sting
- Notes: CMU has pitching-adjacent 'throw' takes; Meshy preset 393 baseball_pitching available via owner account.

## football  —  Medium priority
Kick-return rhythm runner
- Animations: run, sprint, juke_left, juke_right, catch, touchdown_celebrate, tackled_fall
- Props: football, goal_posts, yard_markers
- Environment: Gridiron field · sky: beach/outdoor 2k HDRI · ground: asphalt/PBR · IN REPO: PropsFootball.usdz + BackgroundFootball.png
- Audio: crowd_loop, buzzer, score_sting, ui_confirm, whistle, pad_hit, crowd_roar

## soccer  —  Medium priority
Penalty shootout
- Animations: idle, penalty_run_up, kick_low, kick_high, gk_dive_left, gk_dive_right, celebrate, miss_react
- Props: soccer_ball, goal_with_net
- Environment: Coastal FC stadium · sky: beach/outdoor 2k HDRI · ground: asphalt/PBR · IN REPO: VenueSoccerStadium.usdz + PropsSoccer.usdz + BackgroundSoccer.png
- Audio: crowd_loop, buzzer, score_sting, ui_confirm, ball_kick_thump, net_ripple, crowd_chant
- Notes: CMU 10_01..11_01 kick takes downloaded.

## golf  —  Medium priority
Wii-style swing cadence
- Animations: golf_idle, golf_drive, golf_putt, watch_flight, celebrate
- Props: golf_club, golf_ball, flag_pin
- Environment: Coastal links course · sky: sunny coastal HDRI · ground: grass PBR · IN REPO: VenueLinksGolf.usdz + BackgroundGolf.png
- Audio: crowd_loop, buzzer, score_sting, ui_confirm, club_swish, ball_click, polite_applause
- Notes: Meshy preset 323 golf_drive already acquired on Elijah rig.

## tennis  —  High priority
Ace Rally — serve/rally timing
- Animations: ready_stance, serve, forehand, backhand, volley, celebrate, miss_react
- Props: tennis_racket, tennis_ball, net
- Environment: Venice tennis court · sky: beach/outdoor 2k HDRI · ground: asphalt/PBR · IN REPO: VenueTennisCourt.usdz + PropsTennis.usdz + BackgroundTennis.png; racket also in Seeles pack
- Audio: crowd_loop, buzzer, score_sting, ui_confirm, racket_pop, ball_bounce_court, line_call
- Notes: Seeles anim_tennis_serve.fbx staged; racket attach = right-hand socket.

## volleyball  —  Medium priority
Beach rally ace timing
- Animations: ready_stance, serve_overhand, bump, set, spike, block, celebrate
- Props: volleyball, net_posts
- Environment: Sand court · sky: beach sunset HDRI · ground: sand PBR · IN REPO: PropsVolleyball.usdz + BackgroundVolleyball.png
- Audio: crowd_loop, buzzer, score_sting, ui_confirm, ball_pop, sand_step, whistle

## surfing  —  Medium priority
Balance/line wave riding
- Animations: paddle, pop_up, ride_loop, carve, wipeout
- Props: surfboard
- Environment: Surf break · sky: ocean HDRI · ground: water shader · IN REPO: VenueSurfBreak.usdz + PropsBoardSports.usdz
- Audio: crowd_loop, buzzer, score_sting, ui_confirm, wave_wash, spray, seagulls

## gymnastics  —  High priority
Rhythm-timed routine
- Animations: salute, run, cartwheel, back_handspring, vault, dismount_stick, wobble, celebrate
- Props: vault_table, balance_beam, mat
- Environment: Pacifica gymnastics gym · sky: indoor gym HDRI · ground: spring floor PBR · IN REPO: VenueGymnasticsGym.usdz + BackgroundGymnastics.png
- Audio: crowd_loop, buzzer, score_sting, ui_confirm, springboard_thunk, chalk_clap, judge_beep
- Notes: CMU 05_06 cartwheel take downloaded.

## brain_brawl  —  High priority
Kahoot-style timed quiz
- Animations: thinking_idle, buzz_in, correct_celebrate, wrong_slump
- Props: podium, buzzer_prop
- Environment: Neuro arena · sky: dark stage HDRI · ground: stage floor · IN REPO: Seeles neuro_arena FBX in FEL57 staging
- Audio: crowd_loop, buzzer, score_sting, ui_confirm, question_sting, correct_ding, wrong_buzz, timer_tick

## who_scene_it  —  Low priority
Media recognition quiz
- Animations: thinking_idle, buzz_in
- Props: podium
- Environment: Neuro arena · sky: beach/outdoor 2k HDRI · ground: asphalt/PBR
- Audio: crowd_loop, buzzer, score_sting, ui_confirm, question_sting, reveal_sting

## court_carnival  —  Medium priority
Around-the-world shot stations
- Animations: dribble, jump_shot, celebrate
- Props: basketball, hoop_with_net, station_markers, hoopbus
- Environment: Venice blacktop + HoopBus · sky: beach/outdoor 2k HDRI · ground: asphalt/PBR · IN REPO: Meshy HoopBus GLBs in FEL57 External; PropsSedan.usdz street dressing
- Audio: crowd_loop, buzzer, score_sting, ui_confirm, net_swish, carnival_sting

## skateboarding  —  High priority
Line/trick/combo skate
- Animations: push_ride, ollie, kickflip, grind, manual, bail_fall, celebrate
- Props: skateboard
- Environment: Venice skatepark · sky: beach/outdoor 2k HDRI · ground: asphalt/PBR · IN REPO: VenueSkatePark.usdz + PropsBoardSports.usdz + BackgroundSkateboarding.png
- Audio: crowd_loop, buzzer, score_sting, ui_confirm, deck_pop, wheel_roll, grind_scrape, bail_clatter
- Notes: Seeles anim_skateboard_ollie.fbx staged.

## snowboarding  —  Medium priority
Slope run with gates/tricks
- Animations: carve_loop, gate_turn, air_grab, land, wipeout
- Props: snowboard
- Environment: Mountain slope · sky: alpine HDRI · ground: snow PBR · IN REPO: VenueMountainSlope.usdz
- Audio: crowd_loop, buzzer, score_sting, ui_confirm, snow_carve, wind_rush, gate_slap

## market_browse  —  Low priority
Shop/market non-game module
- Animations: walk, browse_idle
- Props: shelf_props
- Environment: Muscle Beach gym interior · sky: beach/outdoor 2k HDRI · ground: asphalt/PBR · IN REPO: VenueMuscleBeachGym.usdz
- Audio: crowd_loop, buzzer, score_sting, ui_confirm, ambient_market

## movement_lab  —  Low priority
Mocap playback lab
- Animations: any_registered_clip
- Props: —
- Environment: Training floor · sky: beach/outdoor 2k HDRI · ground: asphalt/PBR
- Audio: crowd_loop, buzzer, score_sting, ui_confirm

## Source key
- **quaternius**: https://quaternius.com (CC0)
- **kenney**: https://kenney.nl/assets (CC0)
- **mixamo**: https://www.mixamo.com (free w/ Adobe login — MANUAL download by maintainer)
- **sketchfab_cc0**: https://sketchfab.com/search?licenses=322a749bcfa841b29dff1e8a1bb74b0b&type=models (filter CC0)
- **polyhaven**: https://polyhaven.com (CC0 HDRIs/textures)
- **ambientcg**: https://ambientcg.com (CC0 PBR textures)
- **freesound**: https://freesound.org (filter CC0 — account needed for some downloads)
- **opengameart**: https://opengameart.org (check per-asset license)
- **cmu_mocap**: http://mocap.cs.cmu.edu via github.com/una-dinosauria/cmu-mocap (free incl. commercial, credit required)
- **meshy_owned**: Owner's Meshy subscription output (licensed to owner; already in pipeline)
- **deepmotion_owned**: Owner's DeepMotion mocap of own performances (owner-generated)