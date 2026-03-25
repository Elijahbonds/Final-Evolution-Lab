#ifndef FELNativeCallProxy_h
#define FELNativeCallProxy_h

#include <stdint.h>

#if defined(__cplusplus)
extern "C" {
#endif

void FEL_OnExerciseComplete(const char *jsonUtf8);
void FEL_UpdateUserXP(int32_t xp);

/// Skill rep completed in Unity — Evolution Shard payout (calls Swift host).
void FEL_OnRepCompleted(int32_t shards);

#if defined(__cplusplus)
}
#endif

#endif /* FELNativeCallProxy_h */
