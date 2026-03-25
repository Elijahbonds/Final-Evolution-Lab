#import "FELNativeCallProxy.h"
#import <Foundation/Foundation.h>

void FEL_OnExerciseComplete(const char *jsonUtf8) {
    NSString *payload = jsonUtf8 ? [NSString stringWithUTF8String:jsonUtf8] : @"";
    [[NSNotificationCenter defaultCenter] postNotificationName:@"FEL_OnExerciseComplete"
                                                          object:nil
                                                        userInfo:@{ @"json": payload }];
}

void FEL_UpdateUserXP(int32_t xp) {
    [[NSNotificationCenter defaultCenter] postNotificationName:@"FEL_UpdateUserXP"
                                                      object:nil
                                                    userInfo:@{ @"xp": @(xp) }];
}

void FEL_OnRepCompleted(int32_t shards) {
    [[NSNotificationCenter defaultCenter] postNotificationName:@"FEL_OnRepCompleted"
                                                        object:nil
                                                      userInfo:@{ @"shards": @(shards) }];
}
