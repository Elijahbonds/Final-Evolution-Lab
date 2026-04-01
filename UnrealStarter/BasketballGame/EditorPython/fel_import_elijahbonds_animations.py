#!/usr/bin/env python3
"""
Auto-generated Unreal Editor Python script for importing Elijah Bonds motion capture animations.
Generated: 2026-04-01T16:28:05.636676+00:00

Run in Unreal Editor: Edit → Editor Preferences → Python → Execute Script
Or: Window → Developer Tools → Output Log → Python console
"""
import unreal

asset_tools = unreal.AssetToolsHelpers.get_asset_tools()

# ─── Elijah Bonds Motion Capture Animations ───────────────────────
ELIJAHBONDS_ANIMATIONS = [
    # PENDING: 01_dunk_session_multiple_dunks_reverse_alleyoop (awaiting DeepMotion processing)
    # {
    #     "source_file": r"/home/ubuntu/rork-final-evolution-lab/GeneratedAssets/Animations/ElijahBonds/01_dunk_session_multiple_dunks_reverse_alleyoop/01_dunk_session_multiple_dunks_reverse_alleyoop.fbx",
    #     "destination": "/Game/FEL/Animations/ElijahBonds/01_dunk_session_multiple_dunks_reverse_alleyoop",
    # },
    # PENDING: 02_running_jump_one_hand_dunk (awaiting DeepMotion processing)
    # {
    #     "source_file": r"/home/ubuntu/rork-final-evolution-lab/GeneratedAssets/Animations/ElijahBonds/02_running_jump_one_hand_dunk/02_running_jump_one_hand_dunk.fbx",
    #     "destination": "/Game/FEL/Animations/ElijahBonds/02_running_jump_one_hand_dunk",
    # },
    # PENDING: 03_self_alleyoop_dunks_hoopbus (awaiting DeepMotion processing)
    # {
    #     "source_file": r"/home/ubuntu/rork-final-evolution-lab/GeneratedAssets/Animations/ElijahBonds/03_self_alleyoop_dunks_hoopbus/03_self_alleyoop_dunks_hoopbus.fbx",
    #     "destination": "/Game/FEL/Animations/ElijahBonds/03_self_alleyoop_dunks_hoopbus",
    # },
    # PENDING: 04_reverse_dunk_over_3_people_nba_allstar (awaiting DeepMotion processing)
    # {
    #     "source_file": r"/home/ubuntu/rork-final-evolution-lab/GeneratedAssets/Animations/ElijahBonds/04_reverse_dunk_over_3_people_nba_allstar/04_reverse_dunk_over_3_people_nba_allstar.fbx",
    #     "destination": "/Game/FEL/Animations/ElijahBonds/04_reverse_dunk_over_3_people_nba_allstar",
    # },
    # PENDING: 05_dunk_compilation_multiple_players (awaiting DeepMotion processing)
    # {
    #     "source_file": r"/home/ubuntu/rork-final-evolution-lab/GeneratedAssets/Animations/ElijahBonds/05_dunk_compilation_multiple_players/05_dunk_compilation_multiple_players.fbx",
    #     "destination": "/Game/FEL/Animations/ElijahBonds/05_dunk_compilation_multiple_players",
    # },
    # PENDING: 06_dribble_drive_windmill_dunk_practice (awaiting DeepMotion processing)
    # {
    #     "source_file": r"/home/ubuntu/rork-final-evolution-lab/GeneratedAssets/Animations/ElijahBonds/06_dribble_drive_windmill_dunk_practice/06_dribble_drive_windmill_dunk_practice.fbx",
    #     "destination": "/Game/FEL/Animations/ElijahBonds/06_dribble_drive_windmill_dunk_practice",
    # },
    # PENDING: 07_lateral_shuffle_drive_dunk_gameplay (awaiting DeepMotion processing)
    # {
    #     "source_file": r"/home/ubuntu/rork-final-evolution-lab/GeneratedAssets/Animations/ElijahBonds/07_lateral_shuffle_drive_dunk_gameplay/07_lateral_shuffle_drive_dunk_gameplay.fbx",
    #     "destination": "/Game/FEL/Animations/ElijahBonds/07_lateral_shuffle_drive_dunk_gameplay",
    # },
    # PENDING: 08_casual_game_dribbling_shooting_dunking (awaiting DeepMotion processing)
    # {
    #     "source_file": r"/home/ubuntu/rork-final-evolution-lab/GeneratedAssets/Animations/ElijahBonds/08_casual_game_dribbling_shooting_dunking/08_casual_game_dribbling_shooting_dunking.fbx",
    #     "destination": "/Game/FEL/Animations/ElijahBonds/08_casual_game_dribbling_shooting_dunking",
    # },
    # PENDING: 09_slam_dunks_ball_tricks_session (awaiting DeepMotion processing)
    # {
    #     "source_file": r"/home/ubuntu/rork-final-evolution-lab/GeneratedAssets/Animations/ElijahBonds/09_slam_dunks_ball_tricks_session/09_slam_dunks_ball_tricks_session.fbx",
    #     "destination": "/Game/FEL/Animations/ElijahBonds/09_slam_dunks_ball_tricks_session",
    # },
    # PENDING: 10_full_court_game_crossover_eurostep_layups (awaiting DeepMotion processing)
    # {
    #     "source_file": r"/home/ubuntu/rork-final-evolution-lab/GeneratedAssets/Animations/ElijahBonds/10_full_court_game_crossover_eurostep_layups/10_full_court_game_crossover_eurostep_layups.fbx",
    #     "destination": "/Game/FEL/Animations/ElijahBonds/10_full_court_game_crossover_eurostep_layups",
    # },
]

# ─── UE5 Catalogue Animations (Marketplace / Mannequin) ─────────
UE5_CATALOGUE_REFS = {
    "baseball_bat_swing": "/Game/Characters/Mannequins/Animations/Baseball_BatSwing",
    "baseball_catch": "/Game/Characters/Mannequins/Animations/Baseball_Catch",
    "baseball_pitch": "/Game/Characters/Mannequins/Animations/Baseball_Pitch",
    "baseball_slide": "/Game/Characters/Mannequins/Animations/Baseball_Slide",
    "boxing_block": "/Game/Characters/Mannequins/Animations/Boxing_Block",
    "boxing_cross": "/Game/Characters/Mannequins/Animations/Boxing_Cross",
    "boxing_dodge": "/Game/Characters/Mannequins/Animations/Boxing_Dodge",
    "boxing_hook": "/Game/Characters/Mannequins/Animations/Boxing_Hook",
    "boxing_jab": "/Game/Characters/Mannequins/Animations/Boxing_Jab",
    "boxing_uppercut": "/Game/Characters/Mannequins/Animations/Boxing_Uppercut",
    "football_catch": "/Game/Characters/Mannequins/Animations/Football_Catch",
    "football_hike": "/Game/Characters/Mannequins/Animations/Football_Hike",
    "football_tackle": "/Game/Characters/Mannequins/Animations/Football_Tackle",
    "football_throw": "/Game/Characters/Mannequins/Animations/Football_Throw",
    "gymnastics_cartwheel": "/Game/Characters/Mannequins/Animations/Gymnastics_Cartwheel",
    "gymnastics_flip": "/Game/Characters/Mannequins/Animations/Gymnastics_Flip",
    "gymnastics_handstand": "/Game/Characters/Mannequins/Animations/Gymnastics_Handstand",
    "gymnastics_vault": "/Game/Characters/Mannequins/Animations/Gymnastics_Vault",
    "idle": "/Game/Characters/Mannequins/Animations/Manny/MM_Idle",
    "jump": "/Game/Characters/Mannequins/Animations/Manny/MM_Jump",
    "land": "/Game/Characters/Mannequins/Animations/Manny/MM_Land",
    "martial_arts_block": "/Game/Characters/Mannequins/Animations/MartialArts_Block",
    "martial_arts_kata": "/Game/Characters/Mannequins/Animations/MartialArts_Kata",
    "martial_arts_kick": "/Game/Characters/Mannequins/Animations/MartialArts_Kick",
    "martial_arts_punch": "/Game/Characters/Mannequins/Animations/MartialArts_Punch",
    "run": "/Game/Characters/Mannequins/Animations/Manny/MM_Run_Fwd",
    "skateboard_grind": "/Game/Characters/Mannequins/Animations/Skateboard_Grind",
    "skateboard_kickflip": "/Game/Characters/Mannequins/Animations/Skateboard_Kickflip",
    "skateboard_ollie": "/Game/Characters/Mannequins/Animations/Skateboard_Ollie",
    "skateboard_push": "/Game/Characters/Mannequins/Animations/Skateboard_Push",
    "soccer_dribble": "/Game/Characters/Mannequins/Animations/Soccer_Dribble",
    "soccer_header": "/Game/Characters/Mannequins/Animations/Soccer_Header",
    "soccer_kick": "/Game/Characters/Mannequins/Animations/Soccer_Kick",
    "soccer_save": "/Game/Characters/Mannequins/Animations/Soccer_GoalieSave",
    "sprint": "/Game/Characters/Mannequins/Animations/Manny/MM_Sprint_Fwd",
    "swimming_backstroke": "/Game/Characters/Mannequins/Animations/Swim_Backstroke",
    "swimming_butterfly": "/Game/Characters/Mannequins/Animations/Swim_Butterfly",
    "swimming_dive": "/Game/Characters/Mannequins/Animations/Swim_Dive",
    "swimming_freestyle": "/Game/Characters/Mannequins/Animations/Swim_Freestyle",
    "swimming_turn": "/Game/Characters/Mannequins/Animations/Swim_Turn",
    "tennis_backhand": "/Game/Characters/Mannequins/Animations/Tennis_Backhand",
    "tennis_forehand": "/Game/Characters/Mannequins/Animations/Tennis_Forehand",
    "tennis_serve": "/Game/Characters/Mannequins/Animations/Tennis_Serve",
    "tennis_volley": "/Game/Characters/Mannequins/Animations/Tennis_Volley",
    "track_high_jump": "/Game/Characters/Mannequins/Animations/Track_HighJump",
    "track_hurdle": "/Game/Characters/Mannequins/Animations/Track_Hurdle",
    "track_javelin": "/Game/Characters/Mannequins/Animations/Track_Javelin",
    "track_long_jump": "/Game/Characters/Mannequins/Animations/Track_LongJump",
    "track_sprint_start": "/Game/Characters/Mannequins/Animations/Track_SprintStart",
    "volleyball_dig": "/Game/Characters/Mannequins/Animations/Volleyball_Dig",
    "volleyball_serve": "/Game/Characters/Mannequins/Animations/Volleyball_Serve",
    "volleyball_set": "/Game/Characters/Mannequins/Animations/Volleyball_Set",
    "volleyball_spike": "/Game/Characters/Mannequins/Animations/Volleyball_Spike",
    "walk": "/Game/Characters/Mannequins/Animations/Manny/MM_Walk_Fwd",
    "wrestling_escape": "/Game/Characters/Mannequins/Animations/Wrestling_Escape",
    "wrestling_grapple": "/Game/Characters/Mannequins/Animations/Wrestling_Grapple",
    "wrestling_pin": "/Game/Characters/Mannequins/Animations/Wrestling_Pin",
    "wrestling_takedown": "/Game/Characters/Mannequins/Animations/Wrestling_Takedown",
}


def import_elijahbonds_animations():
    """Import all Elijah Bonds FBX animations into Unreal."""
    tasks = []
    for anim in ELIJAHBONDS_ANIMATIONS:
        if isinstance(anim, dict) and "source_file" in anim:
            import_path = anim["source_file"]
            import unreal
            import os
            if not os.path.exists(import_path):
                unreal.log_warning(f"Skipping {import_path} (file not found)")
                continue
            task = unreal.AssetImportTask()
            task.set_editor_property("filename", import_path)
            task.set_editor_property("destination_path", anim["destination"])
            task.set_editor_property("automated", True)
            task.set_editor_property("replace_existing", True)
            task.set_editor_property("save", True)
            # FBX import settings
            fbx_options = unreal.FbxImportUI()
            fbx_options.set_editor_property("import_as_skeletal", True)
            fbx_options.set_editor_property("import_animations", True)
            fbx_options.set_editor_property("import_mesh", False)
            fbx_options.set_editor_property("create_physics_asset", False)
            fbx_options.skeleton = unreal.load_asset("/Game/Characters/Mannequins/Meshes/SKM_Manny")
            task.set_editor_property("options", fbx_options)
            tasks.append(task)
            unreal.log(f"Queued: {import_path} → {anim['destination']}")
    
    if tasks:
        asset_tools.import_asset_tasks(tasks)
        unreal.log(f"Imported {len(tasks)} Elijah Bonds animations")
    else:
        unreal.log_warning("No animation files found. Run DeepMotion processing first.")


def verify_ue5_catalogue():
    """Check which UE5 catalogue animations are available."""
    available = 0
    missing = []
    for name, path in UE5_CATALOGUE_REFS.items():
        asset = unreal.load_asset(path)
        if asset:
            available += 1
        else:
            missing.append(name)
    unreal.log(f"UE5 Catalogue: {available}/{len(UE5_CATALOGUE_REFS)} available")
    if missing:
        unreal.log_warning(f"Missing: {missing}")
    return missing


if __name__ == "__main__":
    import_elijahbonds_animations()
    verify_ue5_catalogue()
