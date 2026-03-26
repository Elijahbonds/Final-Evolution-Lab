# Copyright (c) Final Evolution Lab.
#
# Titan / Gold Master: minimal playable .umap for every MapsToCook venue.
# Clinical placeholder: Engine cube floor + PlayerStart (+ NeuroArena cyan fill light).
#
# Interactive (Editor Output Log — one process, all venues):
#   py "<repo>/UnrealStarter/BasketballGame/EditorPython/fel_clinical_placeholder_venues.py"
#
# Unattended / CI (recommended — one Editor process per map avoids UE world-leak fatal):
#   bash "<repo>/UnrealStarter/BasketballGame/EditorPython/fel_clinical_placeholder_venues_batch.sh"
#   Or: FEL_VENUE_INDEX=3 UnrealEditor ... -ExecutePythonScript=... (0-based index into VENUES)
#
# Config/DefaultGame.ini already merges MapsToCook for Gold Master.

import os

import unreal

# (package_parent, map_short_name, use_neuro_aesthetic)
VENUES = [
    ("/Game/FEL/Venues/VeniceBeach", "VeniceBeach", False),
    ("/Game/FEL/Venues/Dojo", "Dojo", False),
    ("/Game/FEL/Venues/SoccerStadium", "SoccerStadium", False),
    ("/Game/FEL/Venues/BaseballPark", "BaseballPark", False),
    ("/Game/FEL/Venues/Gridiron", "Gridiron", False),
    ("/Game/FEL/Venues/Links", "Links", False),
    ("/Game/FEL/Venues/TennisCourt", "TennisCourt", False),
    ("/Game/FEL/Venues/SandCourt", "SandCourt", False),
    ("/Game/FEL/Venues/TrainingFloor", "TrainingFloor", False),
    ("/Game/FEL/Venues/NeuroArena", "NeuroArena", True),
    ("/Game/FEL/Venues/Luma_Venice_Shop", "Luma_Venice_Shop", False),
]


def _ensure_dir(path: str) -> None:
    if not unreal.EditorAssetLibrary.does_directory_exist(path):
        unreal.EditorAssetLibrary.make_directory(path)


def _ensure_world(package_parent: str, map_name: str) -> str:
    asset_path = f"{package_parent}/{map_name}.{map_name}"
    if unreal.EditorAssetLibrary.does_asset_exist(asset_path):
        unreal.log(f"FEL Titan: map exists — {asset_path}")
        return asset_path
    _ensure_dir(package_parent)
    factory = unreal.WorldFactory()
    tools = unreal.AssetToolsHelpers.get_asset_tools()
    tools.create_asset(map_name, package_parent, unreal.World, factory)
    unreal.EditorAssetLibrary.save_asset(asset_path)
    try:
        unreal.SystemLibrary.collect_garbage(True)
    except Exception:
        pass
    unreal.log(f"FEL Titan: created world {asset_path}")
    return asset_path


def _load_map(package_parent: str, map_name: str) -> bool:
    pkg = f"{package_parent}/{map_name}"
    ok = unreal.EditorLoadingAndSavingUtils.load_map(pkg)
    if not ok:
        unreal.log_error(f"FEL Titan: load_map failed {pkg}")
    return ok


def _spawn_floor(label: str, scale, z_offset: float):
    mesh = unreal.EditorAssetLibrary.load_asset("/Engine/BasicShapes/Cube.Cube")
    if not mesh:
        unreal.log_error("FEL Titan: Cube mesh missing")
        return
    actor = unreal.EditorLevelLibrary.spawn_actor_from_class(
        unreal.StaticMeshActor, unreal.Vector(0.0, 0.0, 0.0), unreal.Rotator(0.0, 0.0, 0.0)
    )
    if not actor:
        return
    actor.set_actor_label(label)
    actor.static_mesh_component.set_static_mesh(mesh)
    actor.set_actor_scale3d(unreal.Vector(scale[0], scale[1], scale[2]))
    actor.set_actor_location(unreal.Vector(0.0, 0.0, z_offset), False, False)


def _spawn_player_start():
    loc = unreal.Vector(0.0, 0.0, 260.0)
    rot = unreal.Rotator(0.0, 0.0, 0.0)
    ps = unreal.EditorLevelLibrary.spawn_actor_from_class(unreal.PlayerStart, loc, rot)
    if ps:
        ps.set_actor_label("PlayerStart")


def _release_world_before_next_map():
    """Best-effort teardown between maps (interactive multi-venue only)."""
    template = "/Engine/Maps/Templates/Template_Default"
    try:
        if not unreal.EditorLoadingAndSavingUtils.load_map(template):
            unreal.EditorLoadingAndSavingUtils.new_blank_map(False)
    except Exception as exc:
        unreal.log_warning(f"FEL Titan: release world — {exc}")
    try:
        unreal.SystemLibrary.collect_garbage(True)
    except Exception:
        pass


def _spawn_neuro_fill_light():
    pl = unreal.EditorLevelLibrary.spawn_actor_from_class(
        unreal.PointLight, unreal.Vector(280.0, -180.0, 420.0), unreal.Rotator(0.0, 0.0, 0.0)
    )
    if pl:
        pl.set_actor_label("FEL_NeuroFill")
        pl.light_component.set_light_color(unreal.LinearColor(0.35, 0.92, 1.0, 1.0))
        pl.light_component.set_intensity(25000.0)
        pl.light_component.set_attenuation_radius(8000.0)


def _build_one(package_parent: str, map_name: str, neuro: bool, post_release: bool):
    asset_full = _ensure_world(package_parent, map_name)
    if not _load_map(package_parent, map_name):
        return
    if neuro:
        _spawn_neuro_fill_light()
        _spawn_floor("FEL_NeuroFloor", (96.0, 96.0, 0.25), -30.0)
    else:
        _spawn_floor("FEL_ClinicalFloor", (140.0, 140.0, 0.2), -20.0)
    _spawn_player_start()
    unreal.EditorAssetLibrary.save_asset(asset_full)
    unreal.log(f"FEL Titan: saved placeholder {asset_full}")
    if post_release:
        _release_world_before_next_map()


def run():
    env_idx = os.environ.get("FEL_VENUE_INDEX", "").strip()
    if env_idx != "":
        idx = int(env_idx)
        if not (0 <= idx < len(VENUES)):
            unreal.log_error(f"FEL Titan: FEL_VENUE_INDEX={env_idx} out of range 0..{len(VENUES) - 1}")
            return
        pkg, name, neuro = VENUES[idx]
        unreal.log(f"FEL Titan: batch single-venue mode index={idx} ({name})")
        _build_one(pkg, name, neuro, post_release=False)
        return

    unreal.log("FEL Titan: interactive full pass (all venues in one Editor session)…")
    _release_world_before_next_map()
    n = len(VENUES)
    for i, (pkg, name, neuro) in enumerate(VENUES):
        _build_one(pkg, name, neuro, post_release=(i < n - 1))
    unreal.log("FEL Titan: done.")


if __name__ == "__main__":
    run()
