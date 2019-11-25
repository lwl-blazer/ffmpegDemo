//
//  BLAudioSession.m
//  RecordVideo
//
//  Created by luowailin on 2019/11/14.
//  Copyright © 2019 luowailin. All rights reserved.
//

#import "BLAudioSession.h"
#import "AVAudioSession+RouteUtils.h"

const NSTimeInterval AUSAudioSessionLatency_Backgroud = 0.0929;
const NSTimeInterval AUSAudioSessionLatency_Default = 0.0232;
const NSTimeInterval AUSAudioSessionLatency_LowLatency = 0.0058;

@implementation BLAudioSession

+ (BLAudioSession *)sharedInstance{
    static BLAudioSession *instance = NULL;
    static dispatch_once_t onceToken;
    dispatch_once(&onceToken, ^{
        instance = [[BLAudioSession alloc] init];
    });
    return instance;
}

- (instancetype)init
{
    self = [super init];
    if (self) {
        self.perferredSampleRate = 44100.0;
        self.audioSession = [AVAudioSession sharedInstance];
    }
    return self;
}

//设置以何种方式使用音频硬件做哪些处理
- (void)setCategory:(NSString *)category{
    _category = category;
    NSError *error = nil;
    
    [self.audioSession setCategory:category
                             error:&error];
    
    if (error) {
        NSLog(@"Could note set category on audio session:%@", error.localizedDescription);
    }
}

- (void)setActive:(BOOL)active{
    _active = active;
 
    //设置采样频率、让硬件设置按照设置的采样频率来采集或者播放音频
    NSError *error = nil;
    [self.audioSession setPreferredSampleRate:self.perferredSampleRate
                                        error:&error];
    if (error) {
        NSLog(@"Error when setting sample rate on audio session:%@", error.localizedDescription);
    }
    
    //当设置完毕所有的参数之后就可以激活AudioSession
    [self.audioSession setActive:active
                           error:&error];
    if (error) {
        NSLog(@"Error when setting active state of audio session:%@", error.localizedDescription);
    }
    _currentSampleRate = [self.audioSession sampleRate];
}

- (void)setPreferredLatency:(NSTimeInterval)preferredLatency{
    _preferredLatency = preferredLatency;
    NSError *error = nil;
    [self.audioSession setPreferredIOBufferDuration:preferredLatency
                                              error:&error];
    if (error) {
        NSLog(@"Error when setting preferred I/O buffer duration");
    }
}

- (void)addRouteChangeListener{
    /**
     * AVAudioSessionRouteChangeNotification 播放声音的设备改变
     *
     * AVAudioSessionInterruptionNotification 监听系统中断音频播放 (来电暂停  QQ微信语音暂停 其他音乐软件占用)
     */
    [[NSNotificationCenter defaultCenter] addObserver:self
                                             selector:@selector(onNotificationAudioRouteChange:)
                                                 name:AVAudioSessionRouteChangeNotification
                                               object:nil];
    [self adjustOnRouteChange];
}

- (void)onNotificationAudioRouteChange:(NSNotification *)sender{
    [self adjustOnRouteChange];
}

- (void)adjustOnRouteChange{
    AVAudioSessionRouteDescription *currentRoute = [[AVAudioSession sharedInstance] currentRoute];
    if (currentRoute) {
        if ([[AVAudioSession sharedInstance] usingWiredMicrophone]) {
            
        } else {
            if ([[AVAudioSession sharedInstance] usingBlueTooth]) {
                
            } else {
                [[AVAudioSession sharedInstance] overrideOutputAudioPort:AVAudioSessionPortOverrideSpeaker
                                                                   error:nil];
            }
        }
    }
}

@end
