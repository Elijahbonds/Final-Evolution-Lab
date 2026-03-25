# Gold Master — run from Unreal Editor: Python console (Editor-only).
# Before iOS cook: stamp ASTC on textures under /Game/FEL/Venues/Luma_Venice_Shop
# Android (Vulkan / ETC2): TC_ETC2 when available
# PS5 (GNM high): BC7 (engine maps GNM high-quality cooks to BC7-class paths in many projects)
# Mac / generic desktop: BC7
#
# Full automation via FEditorDelegates::PreSaveAssetWithContext requires an Editor module; this script is the portable hook.


def fel_pick_compression(platform: str):
    try:
        import unreal  # type: ignore
    except ImportError:
        return None
    p = platform.lower()
    # Android — Vulkan_ETC2 / ETC2 class
    if p in ("android", "android_vulkan", "vulkan", "vulkan_etc2", "etc2"):
        return getattr(unreal.TextureCompressionSettings, "TC_ETC2", unreal.TextureCompressionSettings.TC_ASTC)
    # PS5 — GNM_High (project-dependent enum name; fall back to BC7)
    if p in ("ps5", "playstation", "gnm", "gnm_high"):
        return getattr(unreal.TextureCompressionSettings, "TC_BC7", unreal.TextureCompressionSettings.TC_BC7)
    if p in ("ios", "iphone", "ipad"):
        return unreal.TextureCompressionSettings.TC_ASTC
    return unreal.TextureCompressionSettings.TC_BC7


def fel_luma_stamp_for_platform(platform: str) -> None:
    try:
        import unreal  # type: ignore
    except ImportError:
        print("[FEL] unreal module not available (run inside Unreal Editor Python).")
        return

    use = fel_pick_compression(platform)
    if use is None:
        return

    ar = unreal.AssetRegistryHelpers.get_asset_registry()
    ar.search_all_assets(True)
    filt = unreal.ARFilter(
        class_names=["Texture2D"],
        package_paths=["/Game/FEL/Venues/Luma_Venice_Shop"],
        recursive_paths=True,
    )
    assets = list(ar.get_assets(filt))

    for a in assets:
        t = a.get_asset()
        if not t:
            continue
        try:
            t.set_editor_property("compression_settings", use)
            t.modify(True)
        except Exception as ex:  # noqa: BLE001 — editor script resilience
            print(f"[FEL] skip {a.package_name}: {ex}")

    print(f"[FEL] Luma_Venice_Shop textures stamped ({platform}): {len(assets)} assets")


# When launched via UnrealEditor -run=pythonscript -script=... set FEL_RUN_STAMP=1 (see scripts/package_gold_master.sh).
import os as _os

if _os.environ.get("FEL_RUN_STAMP") == "1":
    fel_luma_stamp_for_platform(_os.environ.get("FEL_STAMP_PLATFORM", "ios"))
