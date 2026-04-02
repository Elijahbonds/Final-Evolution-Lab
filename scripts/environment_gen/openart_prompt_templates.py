"""
OpenArt Prompt Templates for Enhanced Environment Asset Generation.

Defines detailed prompt templates for each of the 12 preset environments.
Each environment has prompt sets for:
  • props     – background structures, furniture, equipment
  • textures  – surface materials (walls, floors, ground)
  • materials – PBR material sets with map-specific prompts
  • atmosphere – fog, particles, light effects, weather
  • skybox    – panoramic sky variations (day, night, weather)
  • details   – graffiti, signs, decorations, storytelling elements
"""

from typing import Dict, List, Any

# ---------------------------------------------------------------------------
# Per-environment prompt definitions
# ---------------------------------------------------------------------------

ENVIRONMENT_ASSET_PROMPTS: Dict[str, Dict[str, List[Dict[str, Any]]]] = {
    # ======================================================================
    # 1. RETRO TOKYO NIGHT
    # ======================================================================
    "retro_tokyo_night": {
        "props": [
            {"id": "neon_sign_01", "prompt": "Tokyo neon street sign Japanese kanji, glowing cyan and pink, retro 2006 urban style", "type": "sign"},
            {"id": "vending_machine_01", "prompt": "Japanese vending machine glowing in dark alley, retro Tokyo night aesthetic", "type": "box"},
            {"id": "street_lamp_01", "prompt": "Japanese style street lamp with warm glow, Tokyo night atmosphere", "type": "lamp"},
            {"id": "trash_can_01", "prompt": "Urban metal trash can wet from rain, Tokyo street at night", "type": "barrel"},
            {"id": "bench_01", "prompt": "Urban park bench near basketball court, Tokyo night scene", "type": "bench"},
            {"id": "power_lines_01", "prompt": "Electric power line pole with cables, Tokyo urban skyline", "type": "fence"},
            {"id": "manhole_cover_01", "prompt": "Decorative Japanese manhole cover, wet pavement, neon reflections", "type": "detail"},
            {"id": "bike_rack_01", "prompt": "Metal bicycle rack near street court, Tokyo urban scene", "type": "fence"},
            {"id": "phone_booth_01", "prompt": "Japanese red phone booth glowing at night, retro Tokyo", "type": "box"},
            {"id": "graffiti_wall_01", "prompt": "Japanese street art graffiti on concrete wall, neon-lit, urban basketball culture", "type": "sign"},
            {"id": "ramen_cart_01", "prompt": "Mobile ramen food cart with paper lanterns, Tokyo street food vendor night", "type": "box"},
            {"id": "shrine_gate_01", "prompt": "Small torii gate shrine entrance near street court, Tokyo night neon glow", "type": "fence"},
        ],
        "textures": [
            {"id": "wet_asphalt", "prompt": "Wet asphalt road surface at night, neon reflections, Tokyo street, tileable seamless"},
            {"id": "concrete_wall", "prompt": "Urban concrete wall with Japanese graffiti and poster remnants, Tokyo night, tileable"},
            {"id": "brick_alley", "prompt": "Dark brick alley wall, wet from rain, neon light bleeding, tileable seamless texture"},
            {"id": "metal_shutter", "prompt": "Corrugated metal shutter door, rust and graffiti, Tokyo backstreet, tileable"},
            {"id": "tile_floor", "prompt": "Japanese ceramic tile floor, wet surface, indoor court, tileable seamless"},
        ],
        "materials": [
            {"id": "neon_concrete", "prompt": "Concrete with neon light reflections, Tokyo night urban surface"},
            {"id": "wet_metal", "prompt": "Wet brushed metal surface, dark urban aesthetic, rain droplets"},
            {"id": "graffiti_brick", "prompt": "Brick wall with layers of graffiti and wheat-paste posters, Tokyo urban"},
        ],
        "atmosphere": [
            {"id": "neon_fog", "prompt": "Neon-tinted fog and mist, cyan and magenta atmospheric haze, Tokyo night"},
            {"id": "rain_particles", "prompt": "Rain particles falling through neon light, Tokyo night rain effect"},
            {"id": "light_rays_neon", "prompt": "Volumetric light rays from neon signs, god rays through fog, Tokyo night"},
        ],
        "skybox": [
            {"id": "tokyo_night_clear", "prompt": "Tokyo night skyline panoramic, neon signs, skyscrapers, starless city sky"},
            {"id": "tokyo_night_rain", "prompt": "Tokyo rainy night panoramic sky, dark clouds, wet neon reflections upward"},
            {"id": "tokyo_night_haze", "prompt": "Tokyo night hazy skyline, light pollution glow, moody urban panoramic"},
        ],
        "details": [
            {"id": "kanji_stencil", "prompt": "Japanese kanji street art stencil on wall, neon paint splatter"},
            {"id": "poster_torn", "prompt": "Torn anime poster on wall, Tokyo nightlife advertisement remnants"},
            {"id": "puddle_reflection", "prompt": "Neon puddle reflection on wet ground, abstract color pattern"},
            {"id": "crack_pattern", "prompt": "Concrete crack pattern on ground, urban decay, wet surface"},
        ],
    },

    # ======================================================================
    # 2. VENICE BEACH SUNSET
    # ======================================================================
    "venice_beach_sunset": {
        "props": [
            {"id": "palm_tree_01", "prompt": "Venice Beach tall palm tree silhouette against sunset sky", "type": "tree"},
            {"id": "palm_tree_02", "prompt": "California palm tree with coconuts, golden hour light", "type": "tree"},
            {"id": "lifeguard_tower", "prompt": "Venice Beach lifeguard tower, classic California coastal, sunset colors", "type": "box"},
            {"id": "skateboard_ramp", "prompt": "Concrete skateboard half-pipe ramp, Venice Beach skatepark", "type": "box"},
            {"id": "basketball_hoop_outdoor", "prompt": "Outdoor chain-net basketball hoop on beach court, sunset glow", "type": "hoop"},
            {"id": "graffiti_wall_venice", "prompt": "Venice Beach art wall with colorful murals and graffiti", "type": "sign"},
            {"id": "beach_speaker", "prompt": "Portable speaker playing music at beach court, California vibes", "type": "speaker"},
            {"id": "surfboard_rack", "prompt": "Surfboard rack with boards leaning, Venice Beach scene", "type": "fence"},
            {"id": "bike_path_sign", "prompt": "Venice Beach bike path sign, California coastal directional sign", "type": "sign"},
            {"id": "muscle_beach_sign", "prompt": "Muscle Beach outdoor gym sign, Venice Beach iconic landmark", "type": "sign"},
            {"id": "beach_bench", "prompt": "Wooden bench on Venice Beach boardwalk, sunset golden light", "type": "bench"},
            {"id": "taco_truck", "prompt": "Colorful taco food truck near beach court, Venice Beach California", "type": "box"},
        ],
        "textures": [
            {"id": "beach_sand", "prompt": "California beach sand texture, warm golden sunset light, tileable seamless"},
            {"id": "concrete_court", "prompt": "Outdoor basketball concrete court surface, Venice Beach, painted lines, tileable"},
            {"id": "boardwalk_wood", "prompt": "Venice Beach wooden boardwalk planks, weathered sun-bleached wood, tileable"},
            {"id": "stucco_wall", "prompt": "California stucco wall surface, warm sunset tones, tileable seamless"},
            {"id": "asphalt_path", "prompt": "Venice Beach bike path asphalt, warm tones, tileable seamless texture"},
        ],
        "materials": [
            {"id": "sun_bleached_wood", "prompt": "Sun-bleached weathered wood, California coastal, warm golden tones"},
            {"id": "beach_concrete", "prompt": "Beach concrete court surface, sandy texture, warm California light"},
            {"id": "rusty_chain_link", "prompt": "Rusty chain-link fence, Venice Beach outdoor court, sunset patina"},
        ],
        "atmosphere": [
            {"id": "golden_haze", "prompt": "Golden hour atmospheric haze, warm sunset fog, California beach"},
            {"id": "dust_particles", "prompt": "Dust particles floating in golden sunset light, beach atmosphere"},
            {"id": "sunset_rays", "prompt": "Sunset god rays through palm trees, golden light beams, Venice Beach"},
        ],
        "skybox": [
            {"id": "venice_sunset_01", "prompt": "Venice Beach sunset panoramic sky, orange pink purple gradient, ocean horizon"},
            {"id": "venice_golden_hour", "prompt": "California golden hour panoramic, dramatic clouds lit from below, warm"},
            {"id": "venice_dusk", "prompt": "Venice Beach dusk sky panoramic, deep purple and blue, first stars appearing"},
        ],
        "details": [
            {"id": "surf_sticker", "prompt": "Surf brand sticker collection on wall, Venice Beach culture"},
            {"id": "sand_footprints", "prompt": "Footprints in beach sand, basketball shoe treads, warm sand"},
            {"id": "court_line_paint", "prompt": "Worn painted court lines on concrete, sun-faded colors"},
            {"id": "shell_scatter", "prompt": "Scattered seashells on sand near court edge, beach details"},
        ],
    },

    # ======================================================================
    # 3. CYBERPUNK GYM
    # ======================================================================
    "cyberpunk_gym": {
        "props": [
            {"id": "hologram_display", "prompt": "Holographic stat display floating in air, cyberpunk gym, cyan glow", "type": "sign"},
            {"id": "neon_tube_01", "prompt": "Vertical neon tube light, cyan and magenta, cyberpunk gym wall", "type": "lamp"},
            {"id": "weight_rack_cyber", "prompt": "Futuristic chrome weight rack with glowing indicators, cyberpunk gym", "type": "fence"},
            {"id": "punching_bag_led", "prompt": "Heavy punching bag with LED impact sensors, cyberpunk training gym", "type": "barrel"},
            {"id": "energy_drink_vending", "prompt": "Futuristic energy drink vending machine, neon cyberpunk aesthetic", "type": "box"},
            {"id": "training_pod", "prompt": "Cyberpunk training pod capsule, glass and chrome, holographic readouts", "type": "box"},
            {"id": "drone_camera", "prompt": "Small hovering camera drone, filming training session, cyberpunk gym", "type": "lamp"},
            {"id": "locker_bank", "prompt": "Futuristic locker bank with biometric scanners, cyberpunk gym", "type": "box"},
            {"id": "floor_light_strip", "prompt": "LED floor light strip, glowing cyan line on dark floor, cyberpunk", "type": "lamp"},
            {"id": "score_screen", "prompt": "Large LED scoreboard screen showing stats, cyberpunk gym, neon graphics", "type": "sign"},
            {"id": "power_cable_bundle", "prompt": "Thick power cable bundle running along ceiling, industrial cyberpunk", "type": "fence"},
            {"id": "cyber_bench_press", "prompt": "Futuristic bench press with holographic weight counter, cyberpunk gym", "type": "bench"},
        ],
        "textures": [
            {"id": "hex_floor", "prompt": "Hexagonal tile floor pattern, dark with glowing cyan edges, cyberpunk gym, tileable"},
            {"id": "carbon_fiber", "prompt": "Carbon fiber panel surface, dark weave with subtle sheen, tileable seamless"},
            {"id": "brushed_chrome", "prompt": "Brushed chrome metal surface with neon reflections, tileable seamless"},
            {"id": "circuit_wall", "prompt": "Circuit board pattern wall panel, cyberpunk aesthetic, glowing traces, tileable"},
            {"id": "rubber_floor", "prompt": "Black rubber gym floor with subtle texture, tileable seamless"},
        ],
        "materials": [
            {"id": "neon_chrome", "prompt": "Chrome surface reflecting neon lights, cyberpunk gym metal"},
            {"id": "dark_composite", "prompt": "Dark composite material, carbon fiber and rubber, futuristic gym surface"},
            {"id": "led_panel", "prompt": "LED panel glass surface, faintly glowing, cyberpunk tech aesthetic"},
        ],
        "atmosphere": [
            {"id": "cyber_haze", "prompt": "Cyan and magenta atmospheric haze, cyberpunk gym ambient fog"},
            {"id": "hologram_particles", "prompt": "Holographic data particles floating in air, cyberpunk gym VFX"},
            {"id": "neon_light_bloom", "prompt": "Neon light bloom and lens flare, cyberpunk gym atmosphere"},
        ],
        "skybox": [
            {"id": "cyber_city_night", "prompt": "Cyberpunk city through rain-streaked windows, neon towers, flying cars panoramic"},
            {"id": "cyber_interior", "prompt": "Cyberpunk gym interior ceiling view, exposed pipes, neon lights, dark panoramic"},
            {"id": "cyber_storm", "prompt": "Cyberpunk rainstorm outside windows, lightning over neon city panoramic"},
        ],
        "details": [
            {"id": "tech_graffiti", "prompt": "Digital graffiti tag on wall, glitch art style, cyberpunk"},
            {"id": "warning_label", "prompt": "Futuristic warning label decal, hazard symbols, cyberpunk"},
            {"id": "qr_code_sticker", "prompt": "Holographic QR code sticker on equipment, cyberpunk gym"},
            {"id": "impact_crack", "prompt": "Impact crack on reinforced glass, spider web pattern, cyberpunk"},
        ],
    },

    # ======================================================================
    # 4. CLASSIC NBA ARENA
    # ======================================================================
    "classic_nba_arena": {
        "props": [
            {"id": "jumbotron", "prompt": "Classic NBA arena jumbotron overhead scoreboard, 1990s retro style", "type": "sign"},
            {"id": "courtside_seat", "prompt": "Padded courtside folding chair, classic NBA arena, red cushion", "type": "bench"},
            {"id": "scorers_table", "prompt": "Official scorer's table with microphone and stat sheets, NBA arena", "type": "bench"},
            {"id": "basketball_rack", "prompt": "Ball rack with basketballs, NBA warmup equipment, arena sideline", "type": "fence"},
            {"id": "banner_championship", "prompt": "Championship banner hanging from rafters, classic NBA arena", "type": "sign"},
            {"id": "camera_platform", "prompt": "Television camera on platform, NBA arena broadcast position", "type": "box"},
            {"id": "team_bench", "prompt": "NBA team bench with chairs and equipment, courtside", "type": "bench"},
            {"id": "water_cooler", "prompt": "Gatorade water cooler station, NBA sideline, classic arena", "type": "barrel"},
            {"id": "shot_clock", "prompt": "Shot clock display mounted on backboard support, NBA arena", "type": "sign"},
            {"id": "press_row_desk", "prompt": "Press row desk with laptops and notebooks, NBA arena media", "type": "bench"},
            {"id": "basket_stanchion", "prompt": "NBA regulation basketball stanchion and backboard, padded base", "type": "hoop"},
            {"id": "arena_speaker", "prompt": "Large arena speaker cluster hanging from ceiling, PA system", "type": "speaker"},
        ],
        "textures": [
            {"id": "hardwood_court", "prompt": "NBA hardwood maple court floor with grain, polished, tileable seamless"},
            {"id": "painted_lane", "prompt": "Painted free-throw lane on hardwood, classic NBA colors, tileable"},
            {"id": "arena_seat_fabric", "prompt": "Arena stadium seat upholstery fabric, red cushion, tileable seamless"},
            {"id": "concrete_concourse", "prompt": "Arena concrete concourse floor, polished, tileable seamless"},
            {"id": "padded_wall", "prompt": "Arena padded wall behind basket, sponsor logos, tileable"},
        ],
        "materials": [
            {"id": "polished_hardwood", "prompt": "Polished maple hardwood surface, classic NBA court, warm wood tones"},
            {"id": "arena_metal", "prompt": "Painted metal arena infrastructure, scoreboard support beams"},
            {"id": "leather_ball", "prompt": "Basketball leather surface, orange pebbled texture, Spalding style"},
        ],
        "atmosphere": [
            {"id": "spotlight_haze", "prompt": "Arena spotlight haze and atmosphere, dramatic overhead lighting"},
            {"id": "crowd_dust", "prompt": "Dust particles visible in spotlight beams, arena atmosphere"},
            {"id": "spotlight_beams", "prompt": "Dramatic spotlight beams from arena ceiling, light rays through haze"},
        ],
        "skybox": [
            {"id": "arena_ceiling", "prompt": "NBA arena ceiling view panoramic, rafters, banners, jumbotron, spotlights"},
            {"id": "arena_crowd", "prompt": "NBA arena crowd panoramic, packed stadium, signs and banners, electric atmosphere"},
            {"id": "arena_dark", "prompt": "Dark arena before game, only spotlights on court, moody panoramic"},
        ],
        "details": [
            {"id": "sponsor_decal", "prompt": "Arena court sponsor logo decal, flat on hardwood floor"},
            {"id": "shoe_scuff", "prompt": "Basketball shoe scuff marks on hardwood, black rubber marks"},
            {"id": "tape_line", "prompt": "Athletic tape on floor marking positions, coaching detail"},
            {"id": "sweat_stain", "prompt": "Sweat drip stain on hardwood court, game intensity detail"},
        ],
    },

    # ======================================================================
    # 5. UNDERGROUND BUNKER
    # ======================================================================
    "underground_bunker": {
        "props": [
            {"id": "heavy_bag", "prompt": "Heavy punching bag hanging from ceiling chain, underground bunker gym", "type": "barrel"},
            {"id": "speed_bag", "prompt": "Speed bag on wall mount, underground training bunker, concrete walls", "type": "barrel"},
            {"id": "ammo_crate", "prompt": "Military ammo crate used as equipment box, stenciled markings", "type": "box"},
            {"id": "floodlight", "prompt": "Industrial floodlight on tripod, harsh white light, bunker training", "type": "lamp"},
            {"id": "pull_up_bar", "prompt": "Wall-mounted pull-up bar, welded steel, underground bunker gym", "type": "fence"},
            {"id": "tire_stack", "prompt": "Stack of training tires for flipping exercises, bunker gym", "type": "barrel"},
            {"id": "chalk_bucket", "prompt": "Chalk bucket for grip training, powder dust in air, bunker gym", "type": "barrel"},
            {"id": "military_locker", "prompt": "Green military locker row, dented and worn, underground bunker", "type": "box"},
            {"id": "ventilation_fan", "prompt": "Industrial ventilation fan in wall duct, bunker air system", "type": "box"},
            {"id": "motivational_sign", "prompt": "Stenciled motivational military sign on concrete wall, bunker gym", "type": "sign"},
            {"id": "battle_ropes", "prompt": "Battle ropes anchored to wall, training equipment, bunker gym", "type": "fence"},
            {"id": "water_pipe", "prompt": "Exposed water pipe along ceiling, industrial, dripping condensation", "type": "fence"},
        ],
        "textures": [
            {"id": "raw_concrete", "prompt": "Raw poured concrete wall surface, bunker aesthetic, stains, tileable seamless"},
            {"id": "military_floor", "prompt": "Military bunker floor, concrete with painted markings, tileable"},
            {"id": "rusted_metal", "prompt": "Rusted corrugated metal wall panel, underground bunker, tileable seamless"},
            {"id": "cinder_block", "prompt": "Unpainted cinder block wall, bunker construction, tileable seamless"},
            {"id": "rubber_mat", "prompt": "Black rubber training mat, interlocking tiles, gym floor, tileable"},
        ],
        "materials": [
            {"id": "bunker_concrete", "prompt": "Rough poured concrete, military bunker construction, cold grey"},
            {"id": "oxidized_steel", "prompt": "Oxidized steel surface, rust patina, underground bunker pipes"},
            {"id": "worn_rubber", "prompt": "Worn rubber gym mat surface, scuff marks and chalk dust"},
        ],
        "atmosphere": [
            {"id": "chalk_dust", "prompt": "Chalk dust particles floating in harsh light, bunker gym atmosphere"},
            {"id": "condensation_fog", "prompt": "Cold condensation fog near ceiling, underground bunker moisture"},
            {"id": "harsh_spotlight", "prompt": "Harsh industrial spotlight beams cutting through dusty air, bunker"},
        ],
        "skybox": [
            {"id": "bunker_ceiling", "prompt": "Underground bunker concrete ceiling, exposed pipes, ventilation ducts, harsh lights panoramic"},
            {"id": "bunker_dark", "prompt": "Dark underground bunker panoramic, dim emergency lighting, concrete everywhere"},
            {"id": "bunker_lit", "prompt": "Brightly lit bunker interior panoramic, industrial floodlights, military aesthetic"},
        ],
        "details": [
            {"id": "stencil_marking", "prompt": "Military stencil marking on concrete wall, numbers and letters"},
            {"id": "water_stain", "prompt": "Water damage stain on concrete ceiling, mineral deposits, bunker"},
            {"id": "chalk_handprint", "prompt": "Chalk handprint on wall, fighter's ritual, training culture"},
            {"id": "rust_drip", "prompt": "Rust drip stain running down wall from pipe, bunker detail"},
        ],
    },

    # ======================================================================
    # 6. ROOFTOP CITYSCAPE
    # ======================================================================
    "rooftop_cityscape": {
        "props": [
            {"id": "chain_link_fence", "prompt": "Chain-link fence around rooftop court, city skyline visible through", "type": "fence"},
            {"id": "rooftop_light", "prompt": "Rooftop pole light illuminating court, city dusk backdrop", "type": "lamp"},
            {"id": "ac_unit", "prompt": "Rooftop HVAC air conditioning unit, industrial building equipment", "type": "box"},
            {"id": "water_tower", "prompt": "Wooden water tower on adjacent rooftop, New York style", "type": "barrel"},
            {"id": "satellite_dish", "prompt": "Satellite dish on rooftop edge, urban telecommunications", "type": "box"},
            {"id": "fire_escape", "prompt": "Metal fire escape stairway on building side, urban rooftop", "type": "fence"},
            {"id": "ventilation_duct", "prompt": "Large ventilation duct exhaust on rooftop, metal construction", "type": "box"},
            {"id": "folding_table", "prompt": "Folding table with water bottles and towels, rooftop court sideline", "type": "bench"},
            {"id": "portable_hoop", "prompt": "Portable basketball hoop system on rooftop, city backdrop", "type": "hoop"},
            {"id": "graffiti_rooftop", "prompt": "Rooftop graffiti mural on wall, urban art with city skyline theme", "type": "sign"},
            {"id": "pigeon_coop", "prompt": "Rooftop pigeon coop wire cage, urban culture detail", "type": "box"},
            {"id": "radio_antenna", "prompt": "Radio antenna mast on rooftop, blinking red warning light", "type": "lamp"},
        ],
        "textures": [
            {"id": "tar_roof", "prompt": "Black tar rooftop surface, patches and seams, tileable seamless"},
            {"id": "painted_court_roof", "prompt": "Painted basketball court on rooftop, concrete surface, tileable"},
            {"id": "brick_parapet", "prompt": "Brick building parapet wall, urban rooftop, tileable seamless"},
            {"id": "metal_grating", "prompt": "Metal grating walkway surface, rooftop access, tileable seamless"},
            {"id": "gravel_roof", "prompt": "Gravel rooftop surface, small stones, building membrane visible, tileable"},
        ],
        "materials": [
            {"id": "weathered_tar", "prompt": "Weathered rooftop tar surface, cracked and patched, urban"},
            {"id": "galvanized_steel", "prompt": "Galvanized steel surface, air conditioning ducts, rooftop equipment"},
            {"id": "faded_paint", "prompt": "Faded painted concrete, rooftop court markings, sun-worn"},
        ],
        "atmosphere": [
            {"id": "city_haze", "prompt": "Urban city haze at dusk, smog and warm light, rooftop atmosphere"},
            {"id": "wind_dust", "prompt": "Wind-blown dust and particles on rooftop, city environment"},
            {"id": "sunset_rays_city", "prompt": "Sunset light rays between buildings, urban god rays, rooftop view"},
        ],
        "skybox": [
            {"id": "city_dusk", "prompt": "Megacity skyline at dusk panoramic, lit windows, dramatic clouds, orange and blue"},
            {"id": "city_night", "prompt": "City night skyline panoramic from rooftop, millions of lights, dark sky"},
            {"id": "city_golden", "prompt": "Golden hour city skyline panoramic, warm light on buildings, long shadows"},
        ],
        "details": [
            {"id": "pigeon_droppings", "prompt": "Bird droppings stain on rooftop surface, urban detail"},
            {"id": "roof_patch", "prompt": "Tar patch repair on rooftop, different colored surface patch"},
            {"id": "cigarette_butts", "prompt": "Scattered cigarette butts in corner of rooftop, urban grit"},
            {"id": "tag_spraypaint", "prompt": "Quick spraypaint tag on rooftop wall, urban graffiti marker"},
        ],
    },

    # ======================================================================
    # 7. WINTER OUTDOOR
    # ======================================================================
    "winter_outdoor": {
        "props": [
            {"id": "bare_tree_01", "prompt": "Bare winter tree with snow on branches, outdoor court scene", "type": "tree"},
            {"id": "bare_tree_02", "prompt": "Leafless oak tree silhouette, winter evening, frost", "type": "tree"},
            {"id": "street_lamp_warm", "prompt": "Street lamp with warm yellow glow, snow falling, winter night", "type": "lamp"},
            {"id": "snow_bench", "prompt": "Park bench covered in snow, near outdoor basketball court", "type": "bench"},
            {"id": "chain_hoop_frozen", "prompt": "Basketball hoop with frozen chain net, ice and frost", "type": "hoop"},
            {"id": "fire_barrel", "prompt": "Metal barrel fire for warmth, flames and embers, winter outdoor court", "type": "barrel"},
            {"id": "snow_pile", "prompt": "Snow pile shoveled to side of court, winter scene", "type": "barrel"},
            {"id": "park_fence", "prompt": "Black iron park fence with snow on top rail, winter scene", "type": "fence"},
            {"id": "hot_chocolate_cart", "prompt": "Hot chocolate vendor cart with steam, winter park setting", "type": "box"},
            {"id": "snow_shovel", "prompt": "Snow shovel leaning against court fence, winter maintenance", "type": "fence"},
            {"id": "ice_formation", "prompt": "Icicle formation hanging from backboard frame, winter frost", "type": "detail"},
            {"id": "evergreen_tree", "prompt": "Snow-covered evergreen pine tree, winter landscape backdrop", "type": "tree"},
        ],
        "textures": [
            {"id": "snow_ground", "prompt": "Fresh snow on ground surface, footprints and tracks, tileable seamless"},
            {"id": "icy_concrete", "prompt": "Icy frozen concrete court surface, frost patterns, tileable seamless"},
            {"id": "frozen_asphalt", "prompt": "Frozen asphalt with black ice patches, winter road, tileable"},
            {"id": "snow_brick", "prompt": "Brick wall with snow dusting, frost in mortar lines, tileable seamless"},
            {"id": "slush_puddle", "prompt": "Melting slush and dirty snow puddle texture, winter urban, tileable"},
        ],
        "materials": [
            {"id": "frost_metal", "prompt": "Frosted metal surface, ice crystals and condensation, winter cold"},
            {"id": "wet_frozen_concrete", "prompt": "Wet frozen concrete, black ice sheen, winter court surface"},
            {"id": "snow_crust", "prompt": "Crusted snow surface, partially frozen, ice crystals visible"},
        ],
        "atmosphere": [
            {"id": "snowfall", "prompt": "Snow particles falling gently, winter atmosphere, soft white flakes"},
            {"id": "breath_fog", "prompt": "Cold breath fog mist, visible exhalation in winter air"},
            {"id": "warm_glow", "prompt": "Warm street lamp glow through falling snow, winter atmosphere light"},
        ],
        "skybox": [
            {"id": "winter_overcast", "prompt": "Overcast winter sky panoramic, heavy grey clouds, muted light, cold atmosphere"},
            {"id": "winter_clear", "prompt": "Clear winter evening sky panoramic, deep blue, early stars, cold crisp"},
            {"id": "winter_storm", "prompt": "Winter snowstorm sky panoramic, heavy snow, low visibility, blizzard approaching"},
        ],
        "details": [
            {"id": "frost_pattern", "prompt": "Frost crystal pattern on glass surface, winter ice decoration"},
            {"id": "tire_tracks_snow", "prompt": "Tire tracks in snow leading to court, winter detail"},
            {"id": "boot_prints", "prompt": "Boot footprints in fresh snow, walking to basketball court"},
            {"id": "icicle_drip", "prompt": "Icicle dripping and melting, winter thaw detail"},
        ],
    },

    # ======================================================================
    # 8. BEACH TROPICAL
    # ======================================================================
    "beach_tropical": {
        "props": [
            {"id": "coconut_palm", "prompt": "Tropical coconut palm tree, bright sunny day, beach paradise", "type": "tree"},
            {"id": "banana_plant", "prompt": "Tropical banana plant, large green leaves, beach landscape", "type": "tree"},
            {"id": "beach_umbrella", "prompt": "Colorful beach umbrella tilted in sand, tropical paradise", "type": "box"},
            {"id": "volleyball_net", "prompt": "Beach volleyball net set up on white sand, tropical beach", "type": "fence"},
            {"id": "tiki_torch", "prompt": "Bamboo tiki torch with flame, tropical beach atmosphere", "type": "lamp"},
            {"id": "surfboard_01", "prompt": "Surfboard stuck in sand, tropical beach sport equipment", "type": "fence"},
            {"id": "beach_chair", "prompt": "Wooden beach lounge chair on white sand, tropical paradise", "type": "bench"},
            {"id": "cooler_box", "prompt": "Beach cooler box with drinks, ice visible, tropical setting", "type": "box"},
            {"id": "hammock", "prompt": "Hammock strung between palm trees, tropical beach relaxation", "type": "bench"},
            {"id": "boat_beached", "prompt": "Small wooden boat beached on sand, tropical island scene", "type": "box"},
            {"id": "coral_decoration", "prompt": "Coral and seashell decoration pile, tropical beach aesthetic", "type": "barrel"},
            {"id": "bamboo_fence", "prompt": "Bamboo fence border around beach court, tropical construction", "type": "fence"},
        ],
        "textures": [
            {"id": "white_sand", "prompt": "White tropical beach sand, fine grain, bright sunlight, tileable seamless"},
            {"id": "wet_sand", "prompt": "Wet sand near ocean waterline, tropical beach, tileable seamless"},
            {"id": "palm_bark", "prompt": "Palm tree bark texture, tropical wood, rough surface, tileable"},
            {"id": "bamboo_mat", "prompt": "Woven bamboo mat surface, tropical island construction, tileable seamless"},
            {"id": "coral_stone", "prompt": "Coral stone surface, tropical island rock, natural pattern, tileable"},
        ],
        "materials": [
            {"id": "tropical_wood", "prompt": "Tropical driftwood surface, sun-bleached, salt-weathered, beach"},
            {"id": "wet_sand_material", "prompt": "Wet tropical sand, reflective water film, beach shore"},
            {"id": "woven_palm", "prompt": "Woven palm frond material, tropical island construction, natural"},
        ],
        "atmosphere": [
            {"id": "ocean_mist", "prompt": "Ocean spray mist, salty sea air, tropical beach atmosphere"},
            {"id": "sun_sparkle", "prompt": "Sunlight sparkle particles on water, tropical ocean surface light"},
            {"id": "tropical_rays", "prompt": "Tropical sun rays through palm fronds, dappled light beams"},
        ],
        "skybox": [
            {"id": "tropical_sunny", "prompt": "Tropical paradise sky panoramic, bright blue, fluffy white clouds, turquoise ocean"},
            {"id": "tropical_sunset", "prompt": "Tropical sunset sky panoramic, vibrant orange and pink, palm silhouettes"},
            {"id": "tropical_storm", "prompt": "Tropical storm approaching panoramic, dramatic dark clouds, turquoise sea contrast"},
        ],
        "details": [
            {"id": "shell_scatter", "prompt": "Seashell scatter on beach sand, various shells and coral pieces"},
            {"id": "wave_foam", "prompt": "Ocean wave foam pattern on sand, white water residue, beach"},
            {"id": "crab_tracks", "prompt": "Small crab tracks in wet sand, tropical beach nature detail"},
            {"id": "coconut_fallen", "prompt": "Fallen coconut on beach sand, split open, tropical detail"},
        ],
    },

    # ======================================================================
    # 9. WAREHOUSE INDUSTRIAL
    # ======================================================================
    "warehouse_industrial": {
        "props": [
            {"id": "steel_beam", "prompt": "Exposed I-beam steel beam, warehouse ceiling structure, industrial", "type": "fence"},
            {"id": "cage_light", "prompt": "Hanging cage light industrial fixture, warm bulb, warehouse", "type": "lamp"},
            {"id": "pallet_stack", "prompt": "Wooden pallet stack against wall, warehouse storage, industrial", "type": "box"},
            {"id": "boxing_ring", "prompt": "Boxing ring in warehouse corner, ropes and turnbuckles, gym", "type": "fence"},
            {"id": "forklift", "prompt": "Parked forklift in warehouse, yellow industrial vehicle", "type": "box"},
            {"id": "loading_dock", "prompt": "Warehouse loading dock roller door, partially open, industrial", "type": "box"},
            {"id": "chain_hoist", "prompt": "Chain hoist hanging from ceiling beam, industrial warehouse tool", "type": "fence"},
            {"id": "oil_drum", "prompt": "Oil drum in warehouse corner, industrial storage, slight rust", "type": "barrel"},
            {"id": "concrete_pillar", "prompt": "Thick concrete support pillar, warehouse structure, industrial", "type": "barrel"},
            {"id": "metal_shelf", "prompt": "Industrial metal shelving unit, warehouse storage, heavy duty", "type": "fence"},
            {"id": "spray_booth", "prompt": "Industrial spray paint booth area, protective sheets, warehouse art", "type": "box"},
            {"id": "fire_extinguisher", "prompt": "Red fire extinguisher mounted on wall, industrial safety equipment", "type": "barrel"},
        ],
        "textures": [
            {"id": "exposed_brick", "prompt": "Exposed red brick wall, warehouse interior, old mortar, tileable seamless"},
            {"id": "concrete_floor_painted", "prompt": "Painted concrete warehouse floor, court lines, scuff marks, tileable"},
            {"id": "corrugated_metal", "prompt": "Corrugated metal wall panel, warehouse exterior, slight rust, tileable"},
            {"id": "rough_concrete", "prompt": "Rough poured concrete wall, warehouse construction, tileable seamless"},
            {"id": "wood_plank_floor", "prompt": "Old wood plank floor, warehouse conversion, worn and aged, tileable"},
        ],
        "materials": [
            {"id": "aged_brick", "prompt": "Aged red brick surface, 100 year old warehouse, mortar crumbling"},
            {"id": "industrial_concrete", "prompt": "Industrial poured concrete, warehouse floor, oil stains and wear"},
            {"id": "painted_steel", "prompt": "Painted steel beam surface, chipping industrial paint, warehouse"},
        ],
        "atmosphere": [
            {"id": "warehouse_haze", "prompt": "Warehouse dust haze, particles in warm cage light, industrial atmosphere"},
            {"id": "smoke_wisps", "prompt": "Smoke wisps from welding or cigarettes, warehouse gym atmosphere"},
            {"id": "light_shafts", "prompt": "Light shafts through warehouse skylights, dust motes visible, industrial"},
        ],
        "skybox": [
            {"id": "warehouse_ceiling", "prompt": "Warehouse ceiling panoramic, exposed steel trusses, skylights, cage lights"},
            {"id": "warehouse_windows", "prompt": "Warehouse with high windows, grey overcast sky visible, industrial interior panoramic"},
            {"id": "warehouse_dark", "prompt": "Dark warehouse interior panoramic, only pool of light on court area"},
        ],
        "details": [
            {"id": "oil_stain", "prompt": "Old oil stain on concrete floor, industrial warehouse detail"},
            {"id": "paint_drip", "prompt": "Spray paint drip on brick wall, warehouse art detail"},
            {"id": "chalk_tally", "prompt": "Chalk tally marks on wall, keeping score, warehouse gym culture"},
            {"id": "boot_scuff", "prompt": "Heavy boot scuff marks on concrete, warehouse worker detail"},
        ],
    },

    # ======================================================================
    # 10. NEON ARCADE
    # ======================================================================
    "neon_arcade": {
        "props": [
            {"id": "arcade_cabinet", "prompt": "Classic arcade cabinet machine, glowing screen, synthwave neon aesthetic", "type": "box"},
            {"id": "neon_grid_panel", "prompt": "Neon grid floor panel segment, Tron-like, glowing purple and cyan lines", "type": "lamp"},
            {"id": "pixel_scoreboard", "prompt": "Giant pixel art scoreboard, retro 8-bit graphics, neon colors", "type": "sign"},
            {"id": "claw_machine", "prompt": "Neon claw machine with glowing prizes, arcade aesthetic", "type": "box"},
            {"id": "pinball_machine", "prompt": "Pinball machine with neon bumpers, synthwave arcade setting", "type": "box"},
            {"id": "jukebox", "prompt": "Retro neon jukebox, glowing bubbles, synthwave music aesthetic", "type": "box"},
            {"id": "neon_palm", "prompt": "Neon palm tree light sculpture, vaporwave aesthetic prop", "type": "lamp"},
            {"id": "token_dispenser", "prompt": "Arcade token change machine, neon lit, retro gaming aesthetic", "type": "box"},
            {"id": "racing_seat", "prompt": "Arcade racing game seat setup, neon screen glow, synthwave", "type": "bench"},
            {"id": "basketball_arcade", "prompt": "Arcade basketball shooting game, neon backboard, point counter", "type": "hoop"},
            {"id": "disco_ball", "prompt": "Disco ball hanging from ceiling, reflecting neon colors, arcade", "type": "lamp"},
            {"id": "led_wall_panel", "prompt": "Large LED panel wall display, abstract synthwave graphics, neon", "type": "sign"},
        ],
        "textures": [
            {"id": "neon_grid_floor", "prompt": "Neon grid floor, glowing lines on black, Tron aesthetic, tileable seamless"},
            {"id": "pixel_tile", "prompt": "Pixel art mosaic tile surface, retro 8-bit pattern, neon colors, tileable"},
            {"id": "chrome_panel", "prompt": "Reflective chrome panel with neon color reflections, tileable seamless"},
            {"id": "rubber_arcade_floor", "prompt": "Black rubber arcade floor with neon speckles, tileable seamless"},
            {"id": "led_strip_wall", "prompt": "Wall with LED strip lighting grooves, neon arcade, tileable"},
        ],
        "materials": [
            {"id": "neon_glass", "prompt": "Neon-lit glass surface, pink and cyan reflections, arcade aesthetic"},
            {"id": "glowing_grid", "prompt": "Glowing grid line surface, Tron floor material, electric blue"},
            {"id": "retro_chrome", "prompt": "Retro polished chrome, reflecting neon lights, synthwave aesthetic"},
        ],
        "atmosphere": [
            {"id": "neon_haze", "prompt": "Neon-tinted atmospheric haze, purple and cyan fog, arcade ambiance"},
            {"id": "sparkle_particles", "prompt": "Sparkle particles floating in neon light, magical arcade atmosphere"},
            {"id": "laser_beams", "prompt": "Laser beam light show, crossing neon rays, arcade spectacle"},
        ],
        "skybox": [
            {"id": "synthwave_sky", "prompt": "Synthwave sunset panoramic, purple grid landscape, retro sun, vaporwave"},
            {"id": "arcade_ceiling", "prompt": "Arcade ceiling panoramic, black ceiling with neon tube patterns, disco ball"},
            {"id": "digital_void", "prompt": "Digital void space panoramic, floating neon geometric shapes, vaporwave"},
        ],
        "details": [
            {"id": "pixel_sticker", "prompt": "Pixel art sticker on arcade cabinet, retro gaming character"},
            {"id": "neon_crack", "prompt": "Cracked neon tube on wall, sparking, broken arcade decoration"},
            {"id": "high_score_list", "prompt": "Arcade high score list engraved on wall, retro pixel font"},
            {"id": "gum_wad", "prompt": "Gum stuck under arcade cabinet edge, neon-lit detail"},
        ],
    },

    # ======================================================================
    # 11. ZEN DOJO
    # ======================================================================
    "zen_dojo": {
        "props": [
            {"id": "bonsai_tree", "prompt": "Traditional Japanese bonsai tree on wooden stand, zen dojo decoration", "type": "tree"},
            {"id": "paper_screen", "prompt": "Japanese shoji paper screen door, warm backlight, zen dojo", "type": "box"},
            {"id": "wooden_rack", "prompt": "Wooden weapon rack with bokken and jo staff, zen dojo training hall", "type": "fence"},
            {"id": "stone_lantern", "prompt": "Japanese stone garden lantern, moss covered, zen aesthetic", "type": "lamp"},
            {"id": "meditation_cushion", "prompt": "Zafu meditation cushion on tatami, zen dojo corner", "type": "bench"},
            {"id": "calligraphy_scroll", "prompt": "Hanging calligraphy scroll on wall, Japanese brush art, zen dojo", "type": "sign"},
            {"id": "incense_holder", "prompt": "Bronze incense holder with smoke rising, zen dojo spiritual", "type": "barrel"},
            {"id": "bamboo_fountain", "prompt": "Bamboo water fountain, shishi-odoshi, zen garden sound", "type": "barrel"},
            {"id": "tokonoma_alcove", "prompt": "Tokonoma display alcove with ikebana flower arrangement, zen dojo", "type": "box"},
            {"id": "wooden_geta", "prompt": "Row of wooden geta sandals at dojo entrance, Japanese tradition", "type": "bench"},
            {"id": "tea_set", "prompt": "Japanese tea ceremony set on low table, ceramic cups, matcha", "type": "box"},
            {"id": "round_window", "prompt": "Circular moon window in dojo wall, garden view, zen architecture", "type": "box"},
        ],
        "textures": [
            {"id": "tatami_mat", "prompt": "Japanese tatami mat straw weave, traditional dojo floor, tileable seamless"},
            {"id": "wood_beam", "prompt": "Dark wooden beam surface, aged Japanese architecture, tileable seamless"},
            {"id": "paper_wall", "prompt": "Japanese washi paper wall panel, warm translucent, tileable seamless"},
            {"id": "stone_garden", "prompt": "Raked zen rock garden sand pattern, concentric circles, tileable"},
            {"id": "bamboo_surface", "prompt": "Bamboo surface, split bamboo panels, zen dojo wall, tileable seamless"},
        ],
        "materials": [
            {"id": "aged_wood", "prompt": "Aged Japanese cedar wood, warm dark patina, dojo architecture"},
            {"id": "washi_paper", "prompt": "Washi paper surface, soft texture, warm backlit translucency, zen"},
            {"id": "garden_stone", "prompt": "Smooth river stone surface, zen garden element, natural"},
        ],
        "atmosphere": [
            {"id": "incense_smoke", "prompt": "Incense smoke wisps rising gently, zen dojo serene atmosphere"},
            {"id": "dust_motes_light", "prompt": "Dust motes in warm shaft of sunlight, zen dojo peaceful"},
            {"id": "warm_glow", "prompt": "Warm paper lantern glow atmosphere, soft zen dojo ambient light"},
        ],
        "skybox": [
            {"id": "zen_garden_view", "prompt": "Japanese zen garden panoramic, cherry blossoms, stone lanterns, serene"},
            {"id": "dojo_interior", "prompt": "Traditional dojo interior ceiling panoramic, dark wooden beams, paper screens, warm"},
            {"id": "zen_sunset", "prompt": "Japanese garden sunset panoramic, golden light through maple trees, peaceful"},
        ],
        "details": [
            {"id": "calligraphy_mark", "prompt": "Japanese calligraphy brush mark on paper, single kanji character"},
            {"id": "tea_stain", "prompt": "Matcha tea stain ring on wooden surface, zen dojo tea ceremony"},
            {"id": "scratch_bamboo", "prompt": "Scratch marks on bamboo floor, training session wear, dojo"},
            {"id": "flower_petal", "prompt": "Scattered cherry blossom petals on tatami, zen dojo spring detail"},
        ],
    },

    # ======================================================================
    # 12. STADIUM NIGHT GAME
    # ======================================================================
    "stadium_night_game": {
        "props": [
            {"id": "floodlight_tower", "prompt": "Stadium floodlight tower, bright halogen lights, night game", "type": "lamp"},
            {"id": "goal_post", "prompt": "Soccer goal with net, professional stadium, night floodlights", "type": "hoop"},
            {"id": "corner_flag", "prompt": "Soccer corner flag, stadium corner, night game atmosphere", "type": "fence"},
            {"id": "coach_bench", "prompt": "Team technical area bench, stadium sideline, night game", "type": "bench"},
            {"id": "camera_crane", "prompt": "Television broadcast camera crane, stadium coverage, night game", "type": "box"},
            {"id": "electronic_board", "prompt": "Electronic substitution board, stadium sideline, LED numbers", "type": "sign"},
            {"id": "barrier_fence", "prompt": "Stadium advertising barrier fence, sponsor boards, night game", "type": "fence"},
            {"id": "ball_boy_chair", "prompt": "Ball boy high chair, stadium sideline, night game", "type": "bench"},
            {"id": "var_screen", "prompt": "VAR review screen on sideline, electronic display, stadium", "type": "sign"},
            {"id": "stretcher", "prompt": "Medical stretcher on sideline, stadium medical team, night game", "type": "bench"},
            {"id": "pyro_firework", "prompt": "Stadium firework launcher, pre-game pyrotechnics display", "type": "box"},
            {"id": "tunnel_entrance", "prompt": "Player tunnel entrance, stadium architecture, night game lights", "type": "box"},
        ],
        "textures": [
            {"id": "grass_pitch", "prompt": "Pristine green grass football pitch, mowed stripes, tileable seamless"},
            {"id": "running_track", "prompt": "Red running track surface around pitch, rubber athletics, tileable"},
            {"id": "concrete_terrace", "prompt": "Stadium concrete terrace seating surface, tileable seamless"},
            {"id": "painted_grass", "prompt": "White painted lines on green grass, football pitch markings, tileable"},
            {"id": "astroturf", "prompt": "Artificial astroturf surface, green synthetic grass, tileable seamless"},
        ],
        "materials": [
            {"id": "match_grass", "prompt": "Professional match-day grass surface, pristine green, stadium quality"},
            {"id": "stadium_concrete", "prompt": "Stadium concrete structure surface, modern arena construction"},
            {"id": "sponsor_vinyl", "prompt": "Vinyl advertising board material, glossy printed sponsor surface"},
        ],
        "atmosphere": [
            {"id": "floodlight_haze", "prompt": "Stadium floodlight atmospheric haze, bright lights through mist"},
            {"id": "crowd_smoke", "prompt": "Crowd flare smoke drifting across pitch, red and green, stadium atmosphere"},
            {"id": "halftime_fireworks", "prompt": "Firework sparks and smoke, stadium celebration atmosphere"},
        ],
        "skybox": [
            {"id": "stadium_night", "prompt": "Stadium night sky panoramic, floodlights pointing up, dark sky, light pollution"},
            {"id": "stadium_packed", "prompt": "Packed stadium panoramic, full crowd, banners, night game electric atmosphere"},
            {"id": "stadium_fireworks", "prompt": "Stadium with fireworks panoramic, celebration night, explosive colours"},
        ],
        "details": [
            {"id": "pitch_divot", "prompt": "Grass divot from football boot stud, torn turf, pitch detail"},
            {"id": "boot_mud", "prompt": "Muddy boot print on pitch, rain game detail"},
            {"id": "confetti_scatter", "prompt": "Confetti scattered on pitch, celebration aftermath, stadium"},
            {"id": "sponsor_logo", "prompt": "Worn sponsor logo painted on grass, fading pitch markings"},
        ],
    },
}


def get_environment_prompts(env_key: str) -> Dict[str, List[Dict[str, Any]]]:
    """Return all prompt templates for a given environment."""
    return ENVIRONMENT_ASSET_PROMPTS.get(env_key, {})


def get_all_environment_keys() -> List[str]:
    """Return all environment keys."""
    return list(ENVIRONMENT_ASSET_PROMPTS.keys())


def get_asset_count_per_environment(env_key: str) -> Dict[str, int]:
    """Return count of assets per category for an environment."""
    prompts = get_environment_prompts(env_key)
    return {cat: len(items) for cat, items in prompts.items()}


def get_total_asset_count() -> int:
    """Return total number of assets across all environments."""
    total = 0
    for env_key in get_all_environment_keys():
        for cat, items in get_environment_prompts(env_key).items():
            total += len(items)
    return total
