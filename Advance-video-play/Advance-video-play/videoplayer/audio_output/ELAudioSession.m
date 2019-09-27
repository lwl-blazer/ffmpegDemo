//
//  ELAudioSession.m
//  Advance-video-play
//
//  Created by luowailin on 2019/9/11.
//  Copyright © 2019 luowailin. All rights reserved.
//

#import "ELAudioSession.h"
#import "AVAudioSession+RouteUtils.h"

const NSTimeInterval AUSAudioSessionLatency_Background = 0.0929;
const NSTimeInterval AUSAudioSessionLatency_Default = 0.0232;
const NSTimeInterval AUSAudioSessionLatency_LowLatency = 0.0058;

@implementation ELAudioSession

+ (ELAudioSession *)sharedInstance{
    static ELAudioSession *instance = NULL;
    static dispatch_once_t onceToken;
    dispatch_once(&onceToken, ^{
        instance = [[ELAudioSession alloc] init];
    });
    return instance;
}

- (instancetype)init{
    self = [super init];
    if (self) {
        _preferredSampleRate = _currentSampleRate = 44100.0;
        _audioSession = [AVAudioSession sharedInstance];
    }
    return self;
}

- (void)setCategory:(NSString *)category{
    _category = category;
    NSError *error = nil;
    if (![self.audioSession setCategory:category error:&error]) {
        NSLog(@"Could note set category on audio session: %@", error.localizedDescription);
    }
}

- (void)setActive:(BOOL)active{
    _active = active;
    NSError *error = nil;
    
    if (![self.audioSession setPreferredSampleRate:self.preferredSampleRate error:&error]) {
        NSLog(@"Error when setting sample rate on audio session:%@", error.localizedDescription);
    }
    
    /** actvie 为YES 激活Session   active为NO 解除Session的激活状态
     * 因为AVAudioSession会影响其他APP的表现，当自己APP的Session被激活，其它APP的就会被解除激活
     *
     * 如何要让自己的Session解除激活后恢复其他App Session的激活状态呢
         可以使用-(BOOL)setActive:(BOOL)active withOptions:(AVAudioSessionSetActiveOptions)options error:(NSError **)outError;
         options 传入 AVAudioSessionSetActiveOptionNotifyOthersOnDeactivation即可
     *
     * 当然也可以通过otherAudioPlaying变量来提前判断当前是否有其他APP在播放音频
     */
    if (![self.audioSession setActive:active error:&error]) {
        NSLog(@"Error when setting active state of audio session:%@", error.localizedDescription);
    }
    
    _currentSampleRate = [self.audioSession sampleRate];
}

- (void)setPreferredLatency:(NSTimeInterval)preferredLatency{
    _preferredLatency = preferredLatency;
    
    NSError *error = nil;
    if (![self.audioSession setPreferredIOBufferDuration:_preferredLatency error:&error]) {
        NSLog(@"Error when setting preferred I/O buffer duration");
    }
}

/**
 * 中断
 * 1.系统中断响应  (电话，闹钟，其它启动其他APP影响的)
       正常的表现是先暂停 待恢复的时候再继续
     通知:
      AVAudioSessionInterruptionNotification  一般性中断(电话、闹钟等)，userinfo主要包含两个主键:
           AVAudioSessionInterruptionTypeKey 取值为AVAudioSessionInterruptionTypeBegan 表示中断开始 取值为AVAudioSessionInterruptionTypeEnd表示中断结束，我们可以继续采集和播放
           AVAudioSessionInterruptionOptionKey : 当前只有一种值AVAudioSessionInterruptionOptionShouldResum 表示此时也应该恢复播放和采集
 
      AVAudioSessionSilenceSecondaryAudioHintNotification 中断(其他APP占据AudioSession的时候用) userinfo键包括:
         AVAudioSessionSilenceSecondaryAudioHintTypeKey:
           AVAudioSessionSilenceSecondaryAudioHintTypeBegin 表示其他App开始占据Session
           AVAudioSessionSilenceSecondaryAudioHintTypeEnd  表示其他App开始释放Session
 
      AVAudioSessionRouteChangeNotification  外设改变中断(插拔耳机) userinfo键包括:
           AVAudioSessionRouteChangeReasonKey  表示改变的原因
           AVAudioSessionSilenceSecondaryAudioHintTypeKey:
                 AVAudioSessionRouteChangeReasonUnkown 未知原因
                 AVAudioSessionRouteChangeReasonNewDeviceAvailable     有新设备可用
                 AVAudioSessionRouteChangeReasonOldDeviceUnavailable   老设备不可用
                 AVAudioSessionRouteChangeReasonCategoryChange       类别改变了
                 AVAudioSessionRouteChangeReasonOverride        App重置了输出设置
                 AVAudioSessionRouteChnageReasonWakeFromSleep    从睡眠状态呼醒
                 AVAudioSessionRouteChangeReasonNoSuitableRouteForCategory   当前Category下没有合适的设备
                 AVAudioSessionRouteChangeReasonRouteConfigurationChange Router的配置改变了
 
 
       在iOS13中这一块可能还有改变，因为有一个共用音频
 */
- (void)addRouteChangeListener{
    [[NSNotificationCenter defaultCenter] addObserver:self
                                             selector:@selector(onNotificationAudioRouteChange:) name:AVAudioSessionRouteChangeNotification
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
            if (![[AVAudioSession sharedInstance] usingBlueTooth]) {
                [[AVAudioSession sharedInstance] overrideOutputAudioPort:AVAudioSessionPortOverrideSpeaker
                                                                   error:nil];
            }
        }
    }
}


@end
