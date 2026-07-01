#pragma once

#include <stdbool.h>
#include <stdint.h>

#ifdef __cplusplus
extern "C" {
#endif

typedef void *NexusGameplayHandle;

/// Returns true when the NEXUS gameplay static libraries are linked into the app target.
bool nexus_gameplay_bridge_is_linked(void);

NexusGameplayHandle _Nullable nexus_gameplay_session_create(void);
void nexus_gameplay_session_destroy(NexusGameplayHandle _Nullable handle);

/// Advances throw-catch + fitness gameplay logic (fixed-step friendly delta in seconds).
void nexus_gameplay_session_tick(NexusGameplayHandle _Nullable handle, double deltaSeconds);

/// Maps session readiness (0–100) into fel.fitness.update for the C++ gameplay module.
void nexus_gameplay_session_sync_readiness(NexusGameplayHandle _Nullable handle, float readiness0to100);

/// Returns JSON for fel.query.get_session_state (caller must free with nexus_gameplay_session_free_string).
char *_Nullable nexus_gameplay_session_state_json(NexusGameplayHandle _Nullable handle);

/// Returns latest fel.hud.frame JSON (caller must free with nexus_gameplay_session_free_string).
char *_Nullable nexus_gameplay_session_hud_poll_json(NexusGameplayHandle _Nullable handle);

/// Handles a fel.* command JSON payload: {"command","params","id"} (caller frees returned JSON).
char *_Nullable nexus_gameplay_session_handle_command(NexusGameplayHandle _Nullable handle,
                                                      const char *_Nullable commandJson);

/// Ends the active arena session and returns the session result JSON.
char *_Nullable nexus_gameplay_session_end_arena(NexusGameplayHandle _Nullable handle,
                                                 float playerScore,
                                                 float opponentScore);

/// Flushes queued session receipts to ~/.fel/pending_receipts/ (caller frees returned JSON).
char *_Nullable nexus_gameplay_session_flush_receipts(NexusGameplayHandle _Nullable handle);

/// Returns arena state with final_scores after session end (caller frees returned JSON).
char *_Nullable nexus_gameplay_session_final_scores_json(NexusGameplayHandle _Nullable handle);

void nexus_gameplay_session_free_string(char *_Nullable value);

/// Sets the active performance tier in the C++ engine (0 = High, 1 = Balanced, 2 = LowPower).
/// Locks platform override so engine frame-time auto-degrade does not clobber iOS thermal tier.
void nexus_perf_set_tier(int32_t tier);

/// Clears the iOS platform tier lock; engine may resume frame-time tier suggestions.
void nexus_perf_clear_platform_tier(void);

/// Returns the active performance tier (0 = High, 1 = Balanced, 2 = LowPower).
int32_t nexus_perf_get_tier(void);

/// Returns the engine frame-time suggested tier (ignores platform lock).
int32_t nexus_perf_get_engine_suggested_tier(void);

/// Returns the current smoothed FPS from the C++ engine.
float nexus_perf_get_fps(void);

/// Returns the last frame time in milliseconds from the C++ engine.
float nexus_perf_get_frame_time_ms(void);

/// Returns true when the last engine frame exceeded the 60 FPS budget (~16.67 ms).
bool nexus_perf_is_budget_exceeded(void);

/// Returns physics substep scale factor for the active tier (0.25–1.0).
float nexus_perf_get_physics_substep_factor(void);

/// Returns collision check scale factor for the active tier (0.0–1.0).
float nexus_perf_get_collision_check_factor(void);

#ifdef __cplusplus
}
#endif
