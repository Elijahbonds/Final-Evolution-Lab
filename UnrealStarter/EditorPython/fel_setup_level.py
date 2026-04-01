import unreal

# Spawns ONE Luma import + hoop props + Elijah. For Venice Beach shipping map, also import:
# - SM_VeniceCourt (Meshy) + optional SM_LumaCapture03/04/05 from UnrealStarter/LumaExports/* — see
#   BasketballGame/VENICE_LUMA_LEVEL.md (audit §0–1b). Add extra StaticMeshActors in-editor; optional
# ASSET_PATHS entries must use Copy Reference from Content Browser after import.

# Modified to match the default names Unreal generates when you drag and drop the files!
ASSET_PATHS = {
    "luma_environment": "/Game/FEL/Environment/Luma/mesh.mesh",
    "basketball_prop": "/Game/FEL/Props/Meshy_AI_HoopBus_Basketball_0319064117_texture.Meshy_AI_HoopBus_Basketball_0319064117_texture",
    "elijah_mesh": "/Game/FEL/Characters/ElijahBonds/Meshy_AI_Elijah_Bonds_biped_Animation_Running_withSkin.Meshy_AI_Elijah_Bonds_biped_Animation_Running_withSkin",
}

HOOP_OFFSET_CM = 165.0
BALL_Z_ABOVE_FLOOR_CM = 50.0
CHARACTER_Z_ABOVE_FLOOR_CM = 92.0

def _load_static(path: str):
    obj = unreal.load_asset(path)
    if obj is None:
        unreal.log_warning("FEL: Missing asset (did you drag and drop it?): " + path)
    return obj

def _load_skeletal(path: str):
    obj = unreal.load_asset(path)
    if obj is None:
        unreal.log_warning("FEL: Missing asset (did you drag and drop it?): " + path)
    return obj

def _spawn_static_mesh(name: str, mesh, location: unreal.Vector, rotation: unreal.Rotator):
    if mesh is None:
        return None
    actor = unreal.EditorLevelLibrary.spawn_actor_from_class(unreal.StaticMeshActor, location, rotation)
    if actor:
        actor.set_actor_label(name)
        comp = actor.static_mesh_component
        comp.set_static_mesh(mesh)
        comp.set_collision_enabled(unreal.CollisionEnabledType.QUERY_AND_PHYSICS)
    return actor

def _spawn_skeletal(name: str, sk_mesh, location: unreal.Vector, rotation: unreal.Rotator):
    if sk_mesh is None:
        return None
    actor = unreal.EditorLevelLibrary.spawn_actor_from_class(unreal.SkeletalMeshActor, location, rotation)
    if actor:
        actor.set_actor_label(name)
        actor.skeletal_mesh_component.set_skeletal_mesh(sk_mesh)
    return actor

def run():
    unreal.log("FEL: Setting up Luma environment + hoop props + Elijah Bonds test character...")

    sm_luma = _load_static(ASSET_PATHS["luma_environment"])
    sm_ball = _load_static(ASSET_PATHS["basketball_prop"])
    sk_elijah = _load_skeletal(ASSET_PATHS["elijah_mesh"])

    origin = unreal.Vector(0.0, 0.0, 0.0)
    rot_identity = unreal.Rotator(0.0, 0.0, 0.0)

    env = _spawn_static_mesh("ENV_LumaCourt", sm_luma, origin, rot_identity)
    loc_a = unreal.Vector(-HOOP_OFFSET_CM, 0.0, BALL_Z_ABOVE_FLOOR_CM)
    loc_b = unreal.Vector(HOOP_OFFSET_CM, 0.0, BALL_Z_ABOVE_FLOOR_CM)
    _spawn_static_mesh("PROP_Basketball_HoopEnd_A", sm_ball, loc_a, rot_identity)
    _spawn_static_mesh("PROP_Basketball_HoopEnd_B", sm_ball, loc_b, rot_identity)

    char_loc = unreal.Vector(0.0, 0.0, CHARACTER_Z_ABOVE_FLOOR_CM)
    _spawn_skeletal("CHAR_ElijahBonds_Test", sk_elijah, char_loc, rot_identity)

    unreal.log("FEL: Done! Assets placed.")

if __name__ == "__main__":
    run()
