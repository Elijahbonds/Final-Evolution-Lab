# Copyright (c) Final Evolution Lab.
#
# Creates /Game/FEL/Venues/SoccerStadium/SoccerStadium — flat pitch + PlayerStart.
# Import Meshy stadium GLB into /Game/FEL/Environment/Soccer/ and merge into this map for full art.
# Run: py "<path>/fel_quick_soccer_stadium_level.py"
#
# Readiness active_mode soccer → OpenLevel SoccerStadium (see FELReadinessIO + FELDigitalTwinVenuePaths).

import unreal

MAP_PACKAGE = "/Game/FEL/Venues/SoccerStadium"
MAP_NAME = "SoccerStadium"
MAP_PATH = f"{MAP_PACKAGE}/{MAP_NAME}"


def _ensure_dir(path: str) -> None:
    if not unreal.EditorAssetLibrary.does_directory_exist(path):
        unreal.EditorAssetLibrary.make_directory(path)


def _ensure_world_asset() -> str:
    asset_full = f"{MAP_PATH}.{MAP_NAME}"
    if unreal.EditorAssetLibrary.does_asset_exist(asset_full):
        unreal.log(f"FEL: Soccer map already exists: {asset_full}")
        return asset_full

    _ensure_dir(MAP_PACKAGE)
    factory = unreal.WorldFactory()
    asset_tools = unreal.AssetToolsHelpers.get_asset_tools()
    asset_tools.create_asset(MAP_NAME, MAP_PACKAGE, unreal.World, factory)
    unreal.log(f"FEL: Created world {asset_full}")
    return asset_full


def _load_map(asset_full: str) -> bool:
    pkg = asset_full.rsplit(".", 1)[0]
    ok = unreal.EditorLoadingAndSavingUtils.load_map(pkg)
    if not ok:
        unreal.log_error(f"FEL: load_map failed for {pkg}")
    return ok


def _spawn_pitch_floor():
    mesh = unreal.EditorAssetLibrary.load_asset("/Engine/BasicShapes/Cube.Cube")
    if not mesh:
        unreal.log_error("FEL: Could not load Cube")
        return
    loc = unreal.Vector(0.0, 0.0, 0.0)
    actor = unreal.EditorLevelLibrary.spawn_actor_from_class(unreal.StaticMeshActor, loc, unreal.Rotator(0.0, 0.0, 0.0))
    if actor:
        actor.set_actor_label("FEL_SoccerPitchFloor")
        actor.static_mesh_component.set_static_mesh(mesh)
        actor.set_actor_scale3d(unreal.Vector(120.0, 80.0, 0.2))
        actor.set_actor_location(unreal.Vector(0.0, 0.0, -20.0), False, False)
        unreal.log("FEL: Spawned pitch floor (scale for Meshy import tuning).")


def _spawn_player_start():
    loc = unreal.Vector(0.0, 0.0, 100.0)
    rot = unreal.Rotator(0.0, 0.0, 0.0)
    actor = unreal.EditorLevelLibrary.spawn_actor_from_class(unreal.PlayerStart, loc, rot)
    if actor:
        actor.set_actor_label("PlayerStart")
        unreal.log("FEL: Spawned PlayerStart (facing +X — goals align in FELSoccerStadiumPresentation).")


def run():
    unreal.log("FEL: Building SoccerStadium level (pitch + PlayerStart)…")
    asset_full = _ensure_world_asset()
    if not _load_map(asset_full):
        return
    _spawn_pitch_floor()
    _spawn_player_start()
    unreal.EditorAssetLibrary.save_asset(f"{MAP_PATH}.{MAP_NAME}")
    unreal.log(
        "FEL: Saved SoccerStadium. Set readiness active_mode soccer to travel here; "
        "import ball/goal/stadium Meshy assets per Content/FEL/External/Meshy/README.md"
    )


if __name__ == "__main__":
    run()
