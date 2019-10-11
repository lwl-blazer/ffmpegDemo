//
//  ELAudioSession.h
//  AudioUnit-EarFoldback
//
//  Created by luowailin on 2019/10/11.
//  Copyright © 2019 luowailin. All rights reserved.
//

#import <Foundation/Foundation.h>
#import <AVFoundation/AVFoundation.h>

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
