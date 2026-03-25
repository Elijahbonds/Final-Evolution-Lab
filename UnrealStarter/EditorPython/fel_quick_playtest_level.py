# Copyright (c) Final Evolution Lab.
#
# Creates asset + level: /Game/FEL/Maps/L_FEL_Playtest
#   - Floor: scaled /Engine/BasicShapes/Cube
#   - PlayerStart
#   - Two AFELHoopScoreVolume actors (scoring works out of the box)
#
# Prerequisites:
#   - Python Editor Script Plugin (Edit → Plugins → Scripting), Editor restart.
#   - MyProjec C++ compiled so /Script/MyProjec.FELHoopScoreVolume exists.
#
# Run (macOS example):
#   py "/Users/you/.../final-evolution-lab/UnrealStarter/EditorPython/fel_quick_playtest_level.py"
# Or: Tools → Execute Python Script → this file.
#
# Next: DefaultEngine.ini → GameDefaultMap + EditorStartupMap =
#   /Game/FEL/Maps/L_FEL_Playtest.L_FEL_Playtest
#   See UnrealStarter/BasketballGame/PACKAGE_AND_TEST.md §10.

import unreal

MAP_PACKAGE = "/Game/FEL/Maps"
MAP_NAME = "L_FEL_Playtest"
MAP_PATH = f"{MAP_PACKAGE}/{MAP_NAME}"


def _ensure_dir(path: str) -> None:
    if not unreal.EditorAssetLibrary.does_directory_exist(path):
        unreal.EditorAssetLibrary.make_directory(path)


def _ensure_world_asset() -> str:
    asset_full = f"{MAP_PATH}.{MAP_NAME}"
    if unreal.EditorAssetLibrary.does_asset_exist(asset_full):
        unreal.log(f"FEL: Map asset already exists: {asset_full}")
        return asset_full

    _ensure_dir(MAP_PACKAGE)
    factory = unreal.WorldFactory()
    asset_tools = unreal.AssetToolsHelpers.get_asset_tools()
    asset_tools.create_asset(MAP_NAME, MAP_PACKAGE, unreal.World, factory)
    unreal.log(f"FEL: Created world asset {asset_full}")
    return asset_full


def _load_map(asset_full: str) -> bool:
    # asset_full like /Game/FEL/Maps/L_FEL_Playtest.L_FEL_Playtest
    pkg = asset_full.rsplit(".", 1)[0]
    ok = unreal.EditorLoadingAndSavingUtils.load_map(pkg)
    if not ok:
        unreal.log_error(f"FEL: load_map failed for {pkg}")
    return ok


def _spawn_floor():
    mesh = unreal.EditorAssetLibrary.load_asset("/Engine/BasicShapes/Cube.Cube")
    if not mesh:
        unreal.log_error("FEL: Could not load /Engine/BasicShapes/Cube.Cube")
        return
    loc = unreal.Vector(0.0, 0.0, 0.0)
    rot = unreal.Rotator(0.0, 0.0, 0.0)
    actor = unreal.EditorLevelLibrary.spawn_actor_from_class(unreal.StaticMeshActor, loc, rot)
    if actor:
        actor.set_actor_label("FEL_PlaytestFloor")
        actor.static_mesh_component.set_static_mesh(mesh)
        actor.set_actor_scale3d(unreal.Vector(40.0, 40.0, 0.15))
        actor.set_actor_location(unreal.Vector(0.0, 0.0, -15.0), False, False)
        unreal.log("FEL: Spawned scaled cube as floor.")


def _spawn_player_start():
    loc = unreal.Vector(0.0, 0.0, 120.0)
    rot = unreal.Rotator(0.0, 0.0, 0.0)
    actor = unreal.EditorLevelLibrary.spawn_actor_from_class(unreal.PlayerStart, loc, rot)
    if actor:
        actor.set_actor_label("PlayerStart")
        unreal.log("FEL: Spawned PlayerStart.")


def _spawn_hoop_volumes():
    hoop_cls = unreal.load_class(None, "/Script/MyProjec.FELHoopScoreVolume")
    if not hoop_cls:
        unreal.log_error("FEL: Could not load class /Script/MyProjec.FELHoopScoreVolume — is C++ compiled?")
        return

    # Box volumes ~2.5 m above floor, spaced along X (adjust to your court later).
    placements = [
        ("FEL_HoopVolume_A", unreal.Vector(-350.0, 0.0, 250.0)),
        ("FEL_HoopVolume_B", unreal.Vector(350.0, 0.0, 250.0)),
    ]
    for label, loc in placements:
        actor = unreal.EditorLevelLibrary.spawn_actor_from_class(hoop_cls, loc, unreal.Rotator(0.0, 0.0, 0.0))
        if actor:
            actor.set_actor_label(label)
            unreal.log(f"FEL: Spawned {label} at {loc.x},{loc.y},{loc.z}")


def run():
    unreal.log("FEL: Building quick playtest level (floor + PlayerStart + hoop volumes)…")
    asset_full = _ensure_world_asset()
    if not _load_map(asset_full):
        return

    _spawn_floor()
    _spawn_player_start()
    _spawn_hoop_volumes()

    asset_long = f"{MAP_PATH}.{MAP_NAME}"
    unreal.EditorAssetLibrary.save_asset(asset_long)
    unreal.log(
        "FEL: Saved. In DefaultEngine.ini set GameDefaultMap + EditorStartupMap to "
        f"{asset_long} then package per UnrealStarter/BasketballGame/PACKAGE_AND_TEST.md"
    )


if __name__ == "__main__":
    run()
