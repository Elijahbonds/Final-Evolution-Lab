# Final Evolution Lab — UE 5.7 Environment Layout Plan

## 1. Project Overview
- **User Fact**: Deliverable is a set of playable Unreal Engine 5.7 environment layouts for Final Evolution Lab.
- **User Fact**: Scope owned in this document includes 3D arena layouts, spawn points, player pathing, camera zones, collision volumes, interactable objects, mode-specific props, visual identity per venue, performance-safe asset budgets for iOS, and a map smoke checklist.
- **User Fact**: Explicit exclusions are backend rules, PRQ truth, economy, App Store policy, and architecture target definition.
- **User Fact**: The Abacus architecture blueprint is the source of truth.
- **Research Finding**: The blueprint defines 13 active venue mappings plus noted gaps for Vault_Shop and Luma_Venice_Shop, with production focus centered on Venice_Beach_Court, Zen_Dojo, Baseball_Park, Gridiron_Stadium, Soccer_Stadium, Links_Course, Tennis_Court, Sand_Court, Training_Floor, Venice_Beach_Surf, Skate_Park, Mountain_Slope, and Neuro_Arena.
- **Research Finding**: The repository branch indicates a UE integration layer and a UE starter project, while the blueprint confirms UE 5.7 native host targets iOS Shipping and Linux streaming.
- **Assumption**: Because the request is for environment layouts rather than implementation files, the most useful output is a production-ready level design specification that environment, lighting, gameplay, and technical art teams can execute directly in UE 5.7.
- **Assumption**: iOS is the primary performance constraint, so each venue layout favors compact sightlines, aggressive occlusion, modular prop reuse, and low-overdraw composition.
- **Planning Mode**: Preproduction.
- **Depth**: L2 Standard, specialized for level layout and venue production.

## 2. Design Goal
- **User Fact**: Final Evolution Lab needs playable venue layouts, not abstract worldbuilding.
- **Research Finding**: The blueprint positions each mode around fast launch, readable map routing, and mode-specific gameplay identity.
- **Design Goal**: Each venue should communicate its sport fantasy within the first 3 seconds of spawn, support immediate player orientation, preserve clean traversal and camera readability, and remain safe for iOS performance budgets.
- **Design Goal**: Shared venue families should feel cohesive across the FEL brand while still giving each map a distinct silhouette, color rhythm, and prop language.
- **Design Goal**: Layouts must support both direct gameplay and smoke testing, meaning spawn-to-objective flow, collision reliability, and camera transitions should be intentionally simple to verify.
- **Assumption**: The best venue strategy is “hero play space + low-cost perimeter storytelling.” This keeps the active gameplay bowl polished while pushing expensive detail into baked or distant background layers.
- **Success Criteria**:
  - Players always know where to move next from spawn.
  - Competitive spaces avoid blind corners and unfair collision traps.
  - Camera zones reinforce action beats instead of fighting player control.
  - Interactable objects are sparse, legible, and mode-relevant.
  - Every venue can pass a repeatable smoke checklist on iOS without thermal spikes during short sessions.

## 3. Core Layout Framework

### 3.1 Shared Venue Layout Rules
- **Research Finding**: Production and staging modes cluster around sports arenas, courts, slopes, and academy spaces with fast deep-link entry expectations.
- **Layout Rule**: Every map should use a three-ring structure:
  1. **Primary play ring** — the active gameplay surface where scoring and core interaction happen.
  2. **Support ring** — spawn pads, reset lanes, camera anchors, tutorial signage, and safe spectator dressing.
  3. **Backdrop ring** — skyline, crowd, architecture, or scenic identity that sells the venue without affecting gameplay collision.
- **Layout Rule**: Main objective landmarks must be visible from initial spawn or within one turn of camera rotation.
- **Layout Rule**: Traversal routes should be limited to 2–3 meaningful choices in competitive maps to reduce confusion and camera clipping.
- **Layout Rule**: Collision should be “honest”: if a surface looks climbable, vaultable, or blocking, collision should match that expectation.
- **Layout Rule**: Interactable objects should sit on route edges or focal nodes, never in ambiguous mid-lane positions that disrupt competitive readability.

### 3.2 Spawn Point Standards
- **Spawn Type A — Match Start Spawn**: Faces the primary objective, 6–12 meters from first actionable input zone, with no decorative clutter in the first movement arc.
- **Spawn Type B — Reset Spawn**: Used after score, fail, or round transition; should preserve orientation and avoid 180-degree camera flips.
- **Spawn Type C — Spectator/Party Spawn**: For party or academy variants; can be wider and more theatrical but must still preserve a clear route to the active zone.
- **Placement Rules**:
  - Minimum 2 meters clear radius around each spawn.
  - No overlapping collision volumes, props, or VFX emitters at spawn.
  - Spawn forward vector should align with the intended first decision point.
  - Competitive mirrored modes should use symmetrical spawn offsets where fairness matters.

### 3.3 Player Pathing Standards
- **Primary Path**: Fastest route from spawn to objective; widest lane; strongest lighting guidance.
- **Secondary Path**: Tactical flank or recovery route; slightly longer; lower visual emphasis.
- **Recovery Path**: Safe return lane after failure, out-of-bounds reset, or camera correction.
- **Path Width Targets**:
  - Duel sports: 2.5–4 meters clear width.
  - Team court sports: 4–8 meters clear width in active lanes.
  - Board/slope sports: 5–10 meters clear width with soft edge recovery margins.
- **Assumption**: For iOS readability, pathing should avoid dense prop forests, narrow choke clutter, and layered transparent FX near decision points.

### 3.4 Camera Zone Standards
- **Gameplay Camera Zone**: Default zone covering the main action bowl with minimal obstruction.
- **Approach Camera Zone**: Slightly widened framing during spawn-to-objective movement.
- **Hero Camera Zone**: Triggered near scoring, stunt, or showcase moments; short duration only.
- **Recovery Camera Zone**: Pulls back slightly when the player enters edge-risk or reset areas.
- **Placement Rules**:
  - Camera transitions should happen before jumps, swings, or shot timing moments, not during them.
  - Avoid more than one camera zone trigger within a 2-second traversal window.
  - Use collision-tested blockers to prevent camera penetration into walls, bleachers, or large props.

### 3.5 Collision Volume Standards
- **Hard Collision**: Floors, walls, rails, barriers, goals, nets, ramps, and gameplay props.
- **Soft Collision**: Crowd rails, decorative planters, benches, and scenic blockers that guide movement without snagging.
- **Kill/Reset Volumes**: Water, off-stage drops, out-of-bounds sidelines, and failed stunt exits.
- **Trigger Volumes**: Camera zones, tutorial prompts, score zones, stunt windows, and interaction prompts.
- **Rule**: Decorative meshes should default to simplified collision or no collision unless they directly affect play.

### 3.6 Interactable Object Standards
- **Allowed Types**: Score triggers, pickup prompts, launch pads, stunt markers, training targets, quiz terminals, shop displays, and reset beacons.
- **Rule**: Each interactable needs one clear purpose, one readable silhouette, and one obvious approach side.
- **Rule**: Interactable density should stay low in competitive maps and moderate in academy/shop maps.

## 4. Venue-by-Venue Layout Specifications

### 4.1 Venice_Beach_Court
- **Research Finding**: Hosts basketball_h2h, basketball_dunk, basketball_3v3, and mario_party_fever in the blueprint.
- **Visual Identity**: Sunset Venice boardwalk energy, warm concrete, cyan-magenta FEL accents, chain-link edges, branded backboards, distant palm silhouettes, and low-cost crowd strips.
- **Arena Layout**:
  - Central full court with one hero half-court emphasis for H2H and dunk variants.
  - Side apron lanes for 3v3 substitutions, party props, and reset staging.
  - Perimeter boardwalk strip used as scenic support ring, not core play space.
- **Spawn Points**:
  - H2H: mirrored baseline spawns facing center court.
  - Dunk: single hero spawn aligned to runway lane and rim.
  - 3v3: team cluster spawns on opposite sidelines with immediate lane access.
  - Party: central social spawn with branching access to mini-game pads.
- **Player Pathing**:
  - Primary path runs directly into the painted key and perimeter arc.
  - Secondary path uses sideline apron for repositioning and party transitions.
  - Recovery path returns failed dunk attempts to a baseline reset strip.
- **Camera Zones**:
  - Wide gameplay zone over full court.
  - Hero zone at dunk runway and rim.
  - Party showcase zone at center logo for round transitions.
- **Collision Volumes**:
  - Hard collision on court boundaries, stanchions, bleachers, and party mini-game pads.
  - Soft collision on benches, courtside props, and fence edges.
  - Reset volumes behind bleachers and beyond fence exits.
- **Interactables / Props**:
  - Scoreboards, shot clocks, dunk runway markers, party podiums, branded kiosks, and optional tutorial hologram stand.
- **Mode-Specific Notes**:
  - Keep dunk runway visually clean with minimal side clutter.
  - 3v3 requires readable corner spacing and no snagging props near wings.
  - Party mode props should be modular and removable by sublevel.

### 4.2 Zen_Dojo
- **Research Finding**: Hosts karate_h2h and karate_endless.
- **Visual Identity**: Minimalist polished wood, matte stone, paper lantern glow, cyan edge-light trims, disciplined symmetry, and calm negative space.
- **Arena Layout**:
  - Central tatami combat square.
  - Raised perimeter walk for spectators, judges, and endless wave entrances.
  - Rear shrine wall as visual anchor only.
- **Spawn Points**:
  - H2H mirrored corner spawns facing center.
  - Endless single forward spawn with enemy ingress points at side and rear gates.
- **Player Pathing**:
  - Primary path is immediate center engagement.
  - Secondary path is circular edge repositioning around tatami.
  - Recovery path uses rear safe strip for wave reset.
- **Camera Zones**:
  - Tight duel framing in center square.
  - Slight pullback for endless wave escalation.
  - Hero zone for finishing strikes near center emblem.
- **Collision Volumes**:
  - Hard collision on pillars, walls, raised steps.
  - Soft collision on banners, floor cushions, ceremonial props.
  - Enemy spawn triggers at shoji gate thresholds.
- **Interactables / Props**:
  - Training dummies, gong trigger, wave totems, score lanterns.
- **Mode-Specific Notes**:
  - Preserve uncluttered combat readability.
  - Endless mode should use modular gate props to telegraph spawn directions.

### 4.3 Baseball_Park
- **Research Finding**: Hosts baseball.
- **Visual Identity**: Night-game stadium, bright batter spotlight, cool outfield darkness, FEL neon ribbon boards.
- **Arena Layout**:
  - Batter box hero zone with compressed infield frontage.
  - Outfield vista mostly scenic, with ball-flight readability prioritized over traversal.
  - Dugout and bullpen areas remain non-playable support ring.
- **Spawn Points**:
  - Single batter spawn in on-deck lane.
  - Reset spawn one step behind plate to preserve rhythm.
- **Player Pathing**:
  - Minimal traversal; focus on stance setup and swing lane.
  - Recovery path returns to batter box via short arc.
- **Camera Zones**:
  - Batter framing default.
  - Ball-flight hero camera on successful hits.
  - Reset camera snaps back to plate quickly.
- **Collision Volumes**:
  - Hard collision on backstop, dugout rails, foul barriers.
  - Soft collision on benches, equipment carts.
  - Home run trigger volumes in outfield sectors.
- **Interactables / Props**:
  - Pitch machine, bat rack, distance markers, replay board.

### 4.4 Gridiron_Stadium
- **Research Finding**: Hosts football kick return.
- **Visual Identity**: Stadium night game, strong lane lighting, bold yard-line contrast, tunnel-entry spectacle.
- **Arena Layout**:
  - Long central return lane from end zone to midfield target band.
  - Side hazard lanes with blockers and dodge reads.
  - End-zone tunnel spawn for dramatic entry.
- **Spawn Points**:
  - Primary spawn in receiving end zone facing upfield.
  - Reset spawn at 5-yard line for quick retries.
- **Player Pathing**:
  - Primary path follows center seam.
  - Secondary paths cut toward left/right hash lanes.
  - Recovery path exits to sideline reset corridor after tackle/failure.
- **Camera Zones**:
  - Chase camera for return run.
  - Pullback zone near blocker clusters.
  - Hero zone crossing major yard milestones.
- **Collision Volumes**:
  - Hard collision on sideline walls, blockers, tunnel edges.
  - Soft collision on benches and sideline dressing.
  - Out-of-bounds reset volumes beyond white lines.
- **Interactables / Props**:
  - Return markers, boost gates, tackle dummy clusters, crowd light towers.

### 4.5 Soccer_Stadium
- **Research Finding**: Hosts soccer penalty shootout.
- **Visual Identity**: Clean stadium bowl, bright goal focus, cool turf, animated ribbon boards, restrained crowd motion.
- **Arena Layout**:
  - Penalty arc hero space with direct line to goal.
  - Keeper zone and net volume clearly separated.
  - Peripheral stands remain scenic.
- **Spawn Points**:
  - Shooter spawn behind ball setup point.
  - Reset spawn slightly offset to avoid repetitive overlap.
- **Player Pathing**:
  - Short approach lane only.
  - Recovery path loops behind penalty arc.
- **Camera Zones**:
  - Default over-shoulder shot framing.
  - Goal hero camera on score or save.
  - Crowd reaction zone optional and brief.
- **Collision Volumes**:
  - Hard collision on goal frame, ad boards, tunnel walls.
  - Trigger volumes for shot accuracy sectors and goal confirmation.
- **Interactables / Props**:
  - Ball pedestal, target corners, keeper cue lights, scoreboard mast.

### 4.6 Links_Course
- **Research Finding**: Hosts golf closest-to-pin.
- **Visual Identity**: Coastal precision course, trimmed greens, wind-swept bunkers, distant ocean horizon, premium calm atmosphere.
- **Arena Layout**:
  - Tee box spawn plateau.
  - Fairway compression toward one hero green for short-session clarity.
  - Scenic cliffs and water remain backdrop ring.
- **Spawn Points**:
  - Single tee spawn aligned to pin.
  - Reset spawn at bag stand beside tee.
- **Player Pathing**:
  - Minimal movement between tee and observation point.
  - Optional short walk to shot review marker.
- **Camera Zones**:
  - Tee framing default.
  - Ball-flight tracking zone.
  - Pin reveal hero zone on close landings.
- **Collision Volumes**:
  - Hard collision on retaining walls, clubhouse edges, tee barriers.
  - Soft collision on rough edges and decorative fencing.
  - Water hazard reset volumes.
- **Interactables / Props**:
  - Club stand, wind flag, distance beacon, landing ring decals.

### 4.7 Tennis_Court
- **Research Finding**: Hosts tennis rally ace.
- **Visual Identity**: Rooftop cityscape, premium hard court, cool blue lighting, skyline silhouettes, FEL holographic line judges.
- **Arena Layout**:
  - Regulation-inspired court with compressed spectator perimeter.
  - Rear service alleys for reset and camera safety.
- **Spawn Points**:
  - Baseline player spawn.
  - Opponent or rally source spawn mirrored across net.
- **Player Pathing**:
  - Primary path lateral along baseline.
  - Secondary path forward to net attack zone.
  - Recovery path behind baseline to reset pocket.
- **Camera Zones**:
  - Broadcast-style gameplay zone.
  - Net-approach hero zone.
  - Rally recovery pullback near corners.
- **Collision Volumes**:
  - Hard collision on net posts, walls, seating barriers.
  - Soft collision on benches and courtside decor.
- **Interactables / Props**:
  - Ball machine, serve target markers, replay pylon, score tower.

### 4.8 Sand_Court
- **Research Finding**: Hosts volleyball.
- **Visual Identity**: Beach tournament energy, warm sand, sunset sky, cyan-magenta banners, low-cost palm silhouettes.
- **Arena Layout**:
  - Central sand court with generous dive margins.
  - Boardwalk edge and sponsor tents in support ring.
- **Spawn Points**:
  - Team spawns at rear court corners.
  - Reset spawn behind service line.
- **Player Pathing**:
  - Primary path to center receive/set/spike triangle.
  - Secondary path along sideline recovery lanes.
- **Camera Zones**:
  - Wide court framing.
  - Net hero zone for spikes and blocks.
  - Recovery zone near deep corners.
- **Collision Volumes**:
  - Hard collision on posts, barriers, judge stand.
  - Soft collision on tents, coolers, beach props.
  - Out-of-bounds reset beyond rope lines.
- **Interactables / Props**:
  - Serve markers, spike target zones, score hut, tutorial beacon.

### 4.9 Training_Floor
- **Research Finding**: Hosts gymnastics.
- **Visual Identity**: Cyber-athletic training hall, polished mats, LED lane strips, modular apparatus silhouettes, disciplined spotlighting.
- **Arena Layout**:
  - Central floor routine square.
  - Apparatus pods around perimeter for visual identity and future expansion.
  - Judges’ platform at one edge.
- **Spawn Points**:
  - Single routine start spawn.
  - Reset spawn at floor corner.
- **Player Pathing**:
  - Choreographed route through marked routine nodes.
  - Recovery path exits to side mat lane.
- **Camera Zones**:
  - Performance framing default.
  - Hero zones at tumbling diagonals and landing nodes.
  - Pullback zone for full-routine readability.
- **Collision Volumes**:
  - Hard collision on apparatus bases, walls, judges’ riser.
  - Soft collision on mat stacks and banners.
- **Interactables / Props**:
  - Routine markers, timing lights, score display, training holograms.

### 4.10 Venice_Beach_Surf
- **Research Finding**: Hosts surfing and may share Venice beach identity with production cook concerns noted in the blueprint.
- **Visual Identity**: Bright coastal surf break, stylized wave tunnel, pier silhouettes, FEL buoy markers, energetic horizon line.
- **Arena Layout**:
  - Linear wave ride lane with gentle S-curve.
  - Shoreline support strip for spawn and reset.
  - Distant beach crowd and pier remain scenic.
- **Spawn Points**:
  - Board drop-in spawn at wave entry.
  - Reset spawn on shoreline pad.
- **Player Pathing**:
  - Primary path follows wave face.
  - Secondary micro-lines allow risk/reward inside or outside carve positions.
  - Recovery path ejects to shoreline reset.
- **Camera Zones**:
  - Side-follow gameplay camera.
  - Tube hero zone in wave pocket.
  - Recovery pullback near wipeout exits.
- **Collision Volumes**:
  - Hard collision on pier pylons, shoreline barriers, rock outcrops.
  - Soft collision on foam edges where possible.
  - Water reset volumes for wipeouts.
- **Interactables / Props**:
  - Start buoy, trick gates, combo markers, shoreline timing board.

### 4.11 Skate_Park
- **Research Finding**: Staging venue for skateboarding with park lines emphasis.
- **Visual Identity**: Neon arcade skate plaza, concrete bowls, LED rails, graffiti panels, FEL trick signage.
- **Arena Layout**:
  - One hero line connecting quarter pipe, rail, manual pad, and bowl lip.
  - Alternate beginner line around perimeter.
- **Spawn Points**:
  - Main spawn at top of flow line.
  - Reset spawn at flat plaza center.
- **Player Pathing**:
  - Primary path follows trick combo line.
  - Secondary path loops through safer flatground route.
- **Camera Zones**:
  - Follow camera on line entry.
  - Hero zones at rail and bowl transfer points.
- **Collision Volumes**:
  - Hard collision on ramps, rails, ledges.
  - Soft collision on signage and crowd barriers.
- **Interactables / Props**:
  - Trick prompts, combo gates, score pylons, branded mural walls.

### 4.12 Mountain_Slope
- **Research Finding**: Staging venue for snowboarding.
- **Visual Identity**: Crisp alpine slope, blue-white palette, FEL gate lights, snow spray readability over realism density.
- **Arena Layout**:
  - Downhill hero lane with 2–3 branching carve gates.
  - Side safety berms and scenic lodge backdrop.
- **Spawn Points**:
  - Summit spawn facing first gate.
  - Reset spawn at checkpoint shelf.
- **Player Pathing**:
  - Primary downhill racing line.
  - Secondary trick line over side features.
  - Recovery path via soft berm return.
- **Camera Zones**:
  - Chase camera default.
  - Pullback on jumps and gate clusters.
  - Hero zone on major landings.
- **Collision Volumes**:
  - Hard collision on lift pylons, rock walls, lodge edges.
  - Soft collision on snowbanks where forgiving behavior is desired.
- **Interactables / Props**:
  - Gate markers, jump indicators, checkpoint beacons, finish arch.

### 4.13 Neuro_Arena
- **Research Finding**: Hosts brain_brawl and is also the closest venue fit for who_scene_it based on blueprint gaps.
- **Assumption**: Until a separate venue is formally registered, Neuro_Arena should be planned as a flexible academy/quiz arena that can support both cognitive modes through sublevel dressing.
- **Visual Identity**: Neon cerebral arena, dark clinical shell, cyan pulse lines, holographic panels, modular quiz pods.
- **Arena Layout**:
  - Central circular stage for quiz or duel presentation.
  - Outer ring for answer stations, audience lighting, and mode transitions.
  - Rear portal wall for scene reveals or briefing content.
- **Spawn Points**:
  - Brain Brawl mirrored contestant spawns.
  - Who Scene It host-facing spawn and audience-facing reveal spawn.
- **Player Pathing**:
  - Primary path from spawn to answer podium.
  - Secondary path around outer ring for multiplayer staging.
- **Camera Zones**:
  - Broadcast quiz framing.
  - Hero reveal zone for correct-answer moments.
  - Wide arena zone for multiplayer intros.
- **Collision Volumes**:
  - Hard collision on stage edges, podiums, portal wall.
  - Soft collision on hologram stands and decorative consoles.
- **Interactables / Props**:
  - Answer terminals, countdown pillars, reveal screens, category totems.

### 4.14 Vault_Shop / Market Browse
- **Research Finding**: The blueprint lists market_browse in Vault_Shop but flags the venue as missing from the venue registry.
- **Assumption**: This venue should be treated as a low-action showcase environment rather than a dense retail maze.
- **Visual Identity**: Premium dark-clinical commerce hall, reflective black floor accents, cyan shelf lighting, floating product plinths, restrained luxury tone.
- **Arena Layout**:
  - Central promenade loop with 4-card hero display zone.
  - Side alcoves for outfits, blueprints, and coaching offers.
  - Rear feature wall for seasonal spotlight content.
- **Spawn Points**:
  - Single welcome spawn facing hero display.
  - Reset spawn at promenade midpoint.
- **Player Pathing**:
  - Clockwise and counterclockwise browse loop.
  - Short direct route to featured item pedestal.
- **Camera Zones**:
  - Browse framing default.
  - Hero close-up zones at featured plinths.
- **Collision Volumes**:
  - Hard collision on display islands and walls.
  - Soft collision on ropes, signage, and decorative seating.
- **Interactables / Props**:
  - Product pedestals, purchase kiosks, creator card walls, spotlight turntables.

## 5. Mode-to-Venue Prop and Interaction Matrix
- **Basketball Modes**: backboards, shot clocks, score pylons, dunk runway decals, sideline benches, crowd banners.
- **Karate Modes**: tatami markings, dojo gong, wave gates, training dummies, ceremonial banners.
- **Baseball**: pitch machine, bat rack, foul pole indicators, distance boards.
- **Football**: yard markers, blocker dummies, tunnel smoke emitters, boost gates.
- **Soccer**: target corners, keeper cue lights, penalty spot decals, ad boards.
- **Golf**: wind flags, landing rings, tee signage, distance beacons.
- **Tennis**: ball machine, serve targets, umpire chair, replay mast.
- **Volleyball**: serve markers, spike targets, judge stand, beach sponsor tents.
- **Gymnastics**: routine nodes, timing lights, score display, apparatus silhouettes.
- **Surfing**: buoy gates, combo markers, shoreline timing board, pier silhouettes.
- **Skateboarding**: trick prompts, combo rails, mural walls, bowl lighting strips.
- **Snowboarding**: gate lights, jump markers, checkpoint beacons, finish arch.
- **Brain/Quiz Modes**: answer terminals, countdown pillars, reveal screens, category totems.
- **Market Browse**: product plinths, creator card displays, spotlight kiosks, premium signage.

## 6. iOS Performance-Safe Asset Budgets
- **User Fact**: Asset budgets must be performance-safe for iOS.
- **Research Finding**: The blueprint includes an iOS shipping target and a performance manager subsystem with thermal monitoring and dynamic resolution scaling.
- **Budget Strategy**: Favor modular kits, baked lighting where acceptable, low material variety, and aggressive LOD/HLOD planning.

### 6.1 Per-Map Budget Targets
- **Geometry Budget**:
  - Hero play space: 250k–500k visible triangles target at gameplay camera.
  - Full loaded venue peak: 700k–1.2M triangles after LODs, depending on map size.
  - Single hero prop: keep under 25k triangles unless it is the main focal object.
- **Material Budget**:
  - 1–2 master materials per venue family, with instances for variation.
  - Keep unique material slots low on gameplay-critical meshes.
  - Avoid layered translucent materials in the active play ring.
- **Texture Budget**:
  - Hero surfaces: 1K–2K only where camera proximity justifies it.
  - Most props: 512–1K.
  - Shared trim sheets and atlases preferred over unique textures.
- **Lighting Budget**:
  - Prefer baked or stationary lighting for static venue shells.
  - Limit dynamic shadow casters to gameplay-critical actors.
  - Use emissive accents carefully; avoid large overlapping glow stacks.
- **VFX Budget**:
  - 1 hero effect at a time in the main action zone.
  - Secondary ambient effects should be sparse and GPU-light.
- **Audio-Visual Crowd Budget**:
  - Use billboard or card crowds, low-motion loops, or masked strips instead of dense skeletal crowds.

### 6.2 Venue Complexity Tiers
- **Tier A — Compact Precision Maps**: Baseball_Park, Soccer_Stadium, Links_Course, Tennis_Court.
  - Lowest traversal complexity.
  - Can spend more budget on focal presentation.
- **Tier B — Mid-Complexity Arena Maps**: Venice_Beach_Court, Zen_Dojo, Sand_Court, Training_Floor, Neuro_Arena.
  - Moderate prop density.
  - Strong need for clean occlusion and low camera obstruction.
- **Tier C — Flow Maps**: Gridiron_Stadium, Venice_Beach_Surf, Skate_Park, Mountain_Slope.
  - Prioritize long-range readability and low overdraw.
  - Background detail should be heavily simplified.

### 6.3 Hard Technical Rules for Layout Teams
- No dense foliage walls in gameplay lanes.
- No more than 3 overlapping translucent FX layers in any hero shot.
- No decorative collision clutter within first 10 meters of spawn.
- Use simplified collision on all non-essential props.
- Keep skyline/backdrop meshes non-interactive and low-cost.
- Build removable sublevels for mode-specific props so shared venues do not carry unnecessary runtime weight.

## 7. Map Smoke Checklist
- **User Fact**: A map smoke checklist is required.
- **Purpose**: Validate that each venue is playable, readable, and safe before deeper content polish.

### 7.1 Universal Smoke Pass
- Spawn loads in correct venue and faces intended objective.
- No player starts inside collision, props, VFX, or invalid floor.
- Primary path from spawn to first objective is unobstructed.
- Camera does not clip through major walls, bleachers, rails, or hero props.
- All kill/reset volumes return the player to a valid reset spawn.
- Interactable prompts appear only at intended approach distance.
- Score or objective triggers fire in the correct zone.
- No decorative prop blocks a competitive lane or shot line.
- Out-of-bounds edges are readable before the player reaches them.
- Lighting contrast supports objective readability from spawn.
- Frame pacing remains stable during a 3-minute smoke run on iOS target hardware.
- Thermal behavior remains acceptable during repeated resets and hero moments.

### 7.2 Venue-Specific Smoke Focus
- **Venice_Beach_Court**: dunk runway clear, 3v3 corners readable, party props disabled cleanly when not in use.
- **Zen_Dojo**: no pillar camera clipping, endless enemy ingress readable from center.
- **Baseball_Park**: ball-flight camera returns cleanly to batter view.
- **Gridiron_Stadium**: sideline out-of-bounds resets correctly, blocker lanes remain readable at speed.
- **Soccer_Stadium**: goal trigger sectors align with visible target zones.
- **Links_Course**: water hazard reset works, pin remains visible in shot setup.
- **Tennis_Court**: corner recovery camera does not lose ball readability.
- **Sand_Court**: net collision and spike hero framing remain stable.
- **Training_Floor**: routine node order is readable and landing zones are unobstructed.
- **Venice_Beach_Surf**: wipeout reset is fast, wave camera preserves line readability.
- **Skate_Park**: combo line is continuous and rails do not snag unexpectedly.
- **Mountain_Slope**: gate sequence is readable at speed and berm recovery is forgiving.
- **Neuro_Arena**: answer podium interactions are unambiguous and reveal screens are visible from contestant spawns.
- **Vault_Shop**: browse loop is intuitive and featured items are visible from entry.

## 8. Assumptions
- **Assumption**: UE 5.7 venue production will rely on shared modular kits rather than bespoke full-map art for every mode.
- **Assumption**: Shared venues should use sublevels or equivalent content separation for mode-specific props.
- **Assumption**: who_scene_it should temporarily inherit Neuro_Arena spatial logic unless a dedicated venue is later registered.
- **Assumption**: market_browse should prioritize premium readability over dense retail realism.
- **Assumption**: iOS performance safety is more important than cinematic environmental density.

## 9. Key Risks
- **Research Finding**: The blueprint flags registry gaps around who_scene_it, mario_party_fever, and market_browse venue/routing alignment.
- **Risk**: Venue ownership may drift from registry truth if missing venues are implemented informally.
- **Risk**: Shared venues can accumulate too many mode-specific props and lose performance headroom on iOS.
- **Risk**: Flow maps like surfing, skateboarding, and snowboarding can overuse long-range scenery and translucent FX.
- **Risk**: Camera zones may become over-authored and interfere with timing-based gameplay if transitions are too frequent.
- **Risk**: Decorative collision clutter can quietly break competitive fairness and smoke tests.

## 10. Recommended Next Step
- Convert this plan into a venue production checklist with one build sheet per map, including exact spawn counts, trigger names, and sublevel breakdowns.
- Then create a UE 5.7 implementation pass for the highest-priority production venues first: Venice_Beach_Court, Zen_Dojo, Gridiron_Stadium, Soccer_Stadium, and Neuro_Arena.
