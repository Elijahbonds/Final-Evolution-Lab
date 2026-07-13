#if TARGET_IPHONE_SIMULATOR

extern "C" {
    void _nexus_gameplay_session_create() {}
    void _nexus_gameplay_session_tick() {}
    void _nexus_gameplay_session_destroy() {}
    void _nexus_metal_bridge_bundled_mesh_loadable() {}
    void _nexus_metal_bridge_resolve_bundled_mesh_path() {}
    void _nexus_metal_bridge_create_scene() {}
    void _nexus_metal_bridge_destroy_scene() {}
    void _nexus_metal_renderer_create() {}
    void _nexus_metal_renderer_destroy() {}
    void _nexus_metal_renderer_frame() {}
    void _nexus_metal_renderer_shutdown() {}
    void _nexus_perf_set_tier() {}
    void _nexus_perf_clear_platform_tier() {}
    void _nexus_perf_get_tier() {}
    void _nexus_perf_get_engine_suggested_tier() {}
    void _nexus_perf_get_fps() {}
    void _nexus_perf_get_frame_time_ms() {}
    void _nexus_perf_get_collision_check_factor() {}
    void _nexus_perf_get_physics_substep_factor() {}
}

#endif
