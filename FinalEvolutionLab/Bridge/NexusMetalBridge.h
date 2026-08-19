#pragma once

#include <stdbool.h>
#include <stddef.h>
#include <stdint.h>

#if defined(__OBJC__)
@class CAMetalLayer;
#else
struct CAMetalLayer;
#endif

#ifdef __cplusplus
extern "C" {
#endif

typedef void *NexusMetalRendererHandle;

/// Returns true when libnexus_renderer.a is linked into the app target.
bool nexus_metal_bridge_is_linked(void);

/// True when `nexus_asset_manifest.json` is present under the app bundle resource root.
bool nexus_metal_bridge_has_bundled_manifest(void);

/// True when bundled manifest resolves a non-empty venue mesh for `modeId` (e.g. `basketball_dunk`).
bool nexus_metal_bridge_bundled_venue_mesh_loadable(const char *_Nullable modeId);

/// True when bundled manifest resolves a loadable mobile mesh for `assetId` (e.g. `luma_venice_shop_environment_model_fbx`).
bool nexus_metal_bridge_bundled_mesh_loadable(const char *_Nullable assetId);

/// Writes absolute bundled mobile mesh path for `assetId` into `outPath` (UTF-8, NUL-terminated). Returns false when unresolved.
bool nexus_metal_bridge_resolve_bundled_mesh_path(const char *_Nullable assetId, char *_Nullable outPath,
                                                  size_t outPathLen);

NexusMetalRendererHandle _Nullable nexus_metal_renderer_create(void);
void nexus_metal_renderer_destroy(NexusMetalRendererHandle _Nullable handle);

/// Sets arena mode id (e.g. `basketball_dunk`) before initialize. Defaults to `basketball_dunk`.
void nexus_metal_renderer_set_mode_id(NexusMetalRendererHandle _Nullable handle,
                                      const char *_Nullable modeId);

/// Binds a CAMetalLayer (e.g. from MTKView) and configures the NEXUS Metal venue renderer.
bool nexus_metal_renderer_initialize(NexusMetalRendererHandle _Nullable handle,
                                     CAMetalLayer *_Nullable layer,
                                     uint32_t width,
                                     uint32_t height);

/// Draws one frame of the bundled venue mesh scene. Safe to call from MTKViewDelegate.
bool nexus_metal_renderer_render(NexusMetalRendererHandle _Nullable handle);

/// Orbit speed in radians per frame (default ~0.0035). Set 0 for static venue backdrop during hybrid gameplay.
void nexus_metal_renderer_set_orbit_rate(NexusMetalRendererHandle _Nullable handle, float radiansPerFrame);

void nexus_metal_renderer_shutdown(NexusMetalRendererHandle _Nullable handle);

/// Last C++ error string; valid until the next bridge call on this handle.
const char *_Nullable nexus_metal_renderer_last_error(NexusMetalRendererHandle _Nullable handle);

#ifdef __cplusplus
}
#endif
