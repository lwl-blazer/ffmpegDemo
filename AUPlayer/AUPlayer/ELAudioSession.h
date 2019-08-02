//
//  ELAudioSession.h
//  AUPlayer
//
//  Created by luowailin on 2019/8/2.
//  Copyright © 2019 luowailin. All rights reserved.
//

#import <Foundation/Foundation.h>

@class AVAudioSession;
NS_ASSUME_NONNULL_BEGIN
extern const NSTimeInterval AUSAudioSessionLatency_Backgroud;
extern const NSTimeInterval AUSAudioSessionLatency_Default;
extern const NSTimeInterval AUSAudioSessionLatency_LowLatency;

@interface ELAudioSession : NSObject

@property(nonatomic, strong) AVAudioSession *audioSession;
@property(nonatomic, assign) Float64 perferredSampleRate;

@property(nonatomic, assign) NSTimeInterval preferredLatency;
@property(nonatomic, assign) BOOL active;
@property(nonatomic, copy) NSString *category;

@property(nonatomic, assign, readonly) Float64 currentSampleRate;

+ (ELAudioSession *)sharedInstance;
- (void)addRouteChangeListener;

@end

NS_ASSUME_NONNULL_END
