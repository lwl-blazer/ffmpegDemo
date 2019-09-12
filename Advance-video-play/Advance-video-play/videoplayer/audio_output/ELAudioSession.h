//
//  ELAudioSession.h
//  Advance-video-play
//
//  Created by luowailin on 2019/9/11.
//  Copyright © 2019 luowailin. All rights reserved.
//

#import <Foundation/Foundation.h>
#import <AVFoundation/AVFoundation.h>

extern const NSTimeInterval AUSAudioSessionLatency_Background;
extern const NSTimeInterval AUSAudioSessionLatency_Default;
extern const NSTimeInterval AUSAudioSessionLatency_LowLatency;

NS_ASSUME_NONNULL_BEGIN

@interface ELAudioSession : NSObject

@property(nonatomic, strong) AVAudioSession *audioSession;
@property(nonatomic, strong) NSString *category;

@property(nonatomic, assign) Float64 preferredSampleRate;
@property(nonatomic, assign, readonly) Float64 currentSampleRate;
@property(nonatomic, assign) NSTimeInterval preferredLatency;
@property(nonatomic, assign) BOOL active;

+ (ELAudioSession *)sharedInstance;
- (void)addRouteChangeListener;

@end

NS_ASSUME_NONNULL_END
