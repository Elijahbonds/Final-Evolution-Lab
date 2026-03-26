#import "NativeCallProxy.h"

static id<NativeCallsProtocol> api = NULL;

@implementation FrameworkLibAPI
+(void) registerAPIforNativeCalls:(id<NativeCallsProtocol>) aApi
{
    api = aApi;
}
@end

extern "C" {
    void UnityOnExerciseComplete(const char* exerciseId, int score) {
        if (api == NULL) return;
        NSString *exerciseIdString = [NSString stringWithUTF8String:exerciseId];
        [api onExerciseComplete:exerciseIdString score:score];
    }
    
    void UnityUpdateUserXP(int addedXP) {
        if (api == NULL) return;
        [api updateUserXP:addedXP];
    }

    void UnityOnRepCompleted(int shards) {
        if (api == NULL) return;
        [api onRepCompleted:shards];
    }

    void UnityOnWorkoutSummary(const char* summaryJson) {
        if (api == NULL) return;
        NSString *summaryString = [NSString stringWithUTF8String:summaryJson];
        [api onWorkoutSummary:summaryString];
    }
}
