# Asset Attribution

Every third-party asset in this project, its author, license, and required
credit line. Update this file in the SAME commit that adds an asset.

## CMU Graphics Lab Motion Capture Database
- Files: `assets/external/animation/*.bvh`, `assets/motion/external/cmu/*.bvh` (feature branch)
- Source: http://mocap.cs.cmu.edu — BVH conversion by Bruce Hahne (cgspeed), mirror github.com/una-dinosauria/cmu-mocap
- License: free for all uses (including commercial)
- REQUIRED CREDIT (include in app credits screen):
  "The data used in this project was obtained from mocap.cs.cmu.edu.
   The database was created with funding from NSF EIA-0196217."

## Poly Haven
- Files: `assets/external/hdri/venice_sunset_2k.hdr` (+ any HDRI fetched by scripts/fetch_assets.sh)
- Source: https://polyhaven.com/a/venice_sunset — author: Greg Zaal / Poly Haven
- License: CC0 1.0 — attribution not required (credited here as courtesy)

## AmbientCG
- Files: `assets/external/texture/file_Asphalt025C_2K-JPG.zip` (+ any texture fetched)
- Source: https://ambientcg.com/view?id=Asphalt025C — author: Lennart Demes / ambientCG
- License: CC0 1.0 — attribution not required (credited here as courtesy)

## Owner-generated (not third-party, recorded for provenance)
- Meshy outputs (venues, props, character rigs, preset animations): generated
  under the repository owner's Meshy subscription; licensed to subscriber per
  Meshy ToS. Task IDs recorded in assets/motion/external/meshy/ filenames.
- DeepMotion mocap: owner's own recorded performances processed through the
  owner's DeepMotion account (`assets/motion/` registry).
- Seeles asset pack (FinalEvolutionLab57/Content/FEL/External/Seeles): licensed
  to owner; not redistributable outside this project.

## Kenney (web demo starter kit)
- Files: `assets/demo/audio/*.ogg` (8 clips, curated from Interface Sounds),
  `assets/demo/vfx/celebration_particles.png` (sheet assembled from Particle Pack)
- Source: https://opengameart.org/content/interface-sounds and
  https://opengameart.org/content/particle-pack-80-sprites (self-published by
  Kenney; stable mirrors of https://kenney.nl/assets/interface-sounds and
  https://kenney.nl/assets/particle-pack) — author: Kenney (kenney.nl)
- License: CC0 1.0 — attribution not required (credited here as courtesy)
- Clip mapping (pack file -> committed file) lives in scripts/build_demo_assets.sh:
  confirmation_001->correct_ding, confirmation_002->celebrate_chime,
  error_004->wrong_buzz, error_006->buzzer, tick_001->countdown_tick,
  question_001->question_sting, glass_005->reveal_sting, click_001->ui_confirm

## Blender Foundation — Yo Frankie! applause
- File: `assets/demo/audio/crowd_cheer.m4a` (AAC transcode of applause.wav)
- Source: https://opengameart.org/content/applause — author: Blender Foundation
  (Yo Frankie! / Project Apricot)
- License: CC-BY 3.0
- REQUIRED CREDIT (include in app credits screen):
  "Applause sound by the Blender Foundation (Yo Frankie! project),
   opengameart.org/content/applause, licensed CC-BY 3.0."

## game-icons.net (web demo UI icons)
- Files: `assets/demo/icons/*.svg` (timer, buzzer, correct, wrong, streak, podium, trophy)
- Source: https://game-icons.net — authors per icon:
  Lorc (stopwatch->timer.svg, ringing-bell->buzzer.svg, cross-mark->wrong.svg),
  Delapouite (check-mark->correct.svg, podium->podium.svg, trophy-cup->trophy.svg),
  Carl Olsen (flame->streak.svg)
- License: CC-BY 3.0
- REQUIRED CREDIT (include in app credits screen):
  "Icons by Lorc, Delapouite and Carl Olsen via game-icons.net, licensed CC-BY 3.0."

## Poly Haven (web demo stage backdrops)
- Files: `assets/demo/backdrops/stage_music_hall.jpg`, `assets/demo/backdrops/stage_theater.jpg`
  (downscaled tonemapped renders of the music_hall_01 / theater_01 HDRIs)
- Source: https://polyhaven.com/a/music_hall_01 (author: Sergej Majboroda),
  https://polyhaven.com/a/theater_01 (author: Oliksiy Yakovlyev)
- License: CC0 1.0 — attribution not required (credited here as courtesy)

## Open Trivia Database (demo question seed)
- File: `assets/mock/opentdb_questions.json` (~100 general-knowledge questions)
- Source: https://opentdb.com (public API, category 9; fetched by
  `scripts/fetch_assets.sh --opentdb`)
- License: CC BY-SA 4.0 — attribution embedded in the JSON dump itself.
- REQUIRED CREDIT (include wherever the questions are displayed):
  "Trivia questions from the Open Trivia Database (opentdb.com), CC BY-SA 4.0."
- ShareAlike note: the dump and any derivative QUESTION SETS stay CC BY-SA 4.0;
  demo/mock data only — see ASSET_LICENSE_SUMMARY.md carve-out before shipping.

## Pending (add entries BEFORE merging assets)
- Quaternius Universal Animation Library — CC0; credit "Quaternius" (courtesy).
- Kenney packs (Sports Pack; others not listed above) — CC0; credit "Kenney.nl" (courtesy).
- Mixamo clips — Adobe terms: usable in projects, NO raw redistribution; raw
  FBX must stay out of the repo (converted, integrated forms only).
- Freesound picks — record per-file: sound ID, author, exact CC license.
