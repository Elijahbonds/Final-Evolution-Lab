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

/// Handles a fel.* command JSON payload: {"command","params","id"} (caller frees returned JSON).
char *_Nullable nexus_gameplay_session_handle_command(NexusGameplayHandle _Nullable handle,
                                                      const char *_Nullable commandJson);

void nexus_gameplay_session_free_string(char *_Nullable value);

#ifdef __cplusplus
}
#endif
