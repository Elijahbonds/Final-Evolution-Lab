#import <Foundation/Foundation.h>

@protocol NativeCallsProtocol
@required
- (void) onExerciseComplete:(NSString*)exerciseId score:(int)score;
- (void) updateUserXP:(int)addedXP;
- (void) onRepCompleted:(int)shards;
- (void) onWorkoutSummary:(NSString*)summaryJson;
@end

__attribute__ ((visibility("default")))
@interface FrameworkLibAPI : NSObject
+(void) registerAPIforNativeCalls:(id<NativeCallsProtocol>) aApi;
@end
