//
//  ELAudioSession.m
//  AUPlayer
//
//  Created by luowailin on 2019/8/2.
//  Copyright © 2019 luowailin. All rights reserved.
//

#import "ELAudioSession.h"
#import "AVAudioSession+RouteUtils.h"

const NSTimeInterval AUSAudioSessionLatency_Backgroud = 0.0929;
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
        self.perferredSampleRate = 44100;
        _currentSampleRate = 44100;
        self.audioSession = [AVAudioSession sharedInstance];
    }
    return self;
}

- (void)setCategory:(NSString *)category{
    _category = category;
    
    NSError *error = nil;
    if (![self.audioSession setCategory:category
                                  error:&error]) {
        NSLog(@"Could note set category on audio session: %@", error.localizedDescription);
    }
}

- (void)setActive:(BOOL)active{
    _active = active;
    
    NSError *error = nil;
    if (![self.audioSession setPreferredSampleRate:self.perferredSampleRate
                                             error:&error]) {
        NSLog(@"Error when setting sample rate on audio session: %@", error.localizedDescription);
    }
    
    if (![self.audioSession setActive:active
                                error:&error]) {
        NSLog(@"Error when setting active state of audio session:%@", error.localizedDescription);
    }
    
    _currentSampleRate = [self.audioSession sampleRate];
}

- (void)setPreferredLatency:(NSTimeInterval)preferredLatency{
    _preferredLatency = preferredLatency;
    NSError *error = nil;
    if (![self.audioSession setPreferredIOBufferDuration:preferredLatency
                                                   error:&error]) {
        NSLog(@"Error when setting preferred I/O buffer duration");
    }
}

- (void)addRouteChangeListener{
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
        if (![[AVAudioSession sharedInstance] usingWiredMicrophone]) {
            
        } else {
            if (![[AVAudioSession sharedInstance] usingBlueTooth]) {
                [[AVAudioSession sharedInstance] overrideOutputAudioPort:AVAudioSessionPortOverrideSpeaker
                                                                   error:nil];
            }
        }
    }
}

@end
