//
//  ELAudioSession.m
//  AudioUnit-EarFoldback
//
//  Created by luowailin on 2019/10/11.
//  Copyright © 2019 luowailin. All rights reserved.
//

#import "ELAudioSession.h"
#import "AVAudioSession+RouteUtils.h"

@implementation ELAudioSession

+ (ELAudioSession *)sharedInstance{
    static ELAudioSession *session = nil;
    static dispatch_once_t onceToken;
    dispatch_once(&onceToken, ^{
        session = [[ELAudioSession alloc] init];
    });
    return session;
}

- (instancetype)init{
    self = [super init];
    if (self) {
        _preferredSampleRate = 44100.0;
        _audioSession = [[AVAudioSession alloc] init];
    }
    return self;
}

- (void)setCategory:(NSString *)category{
    _category = category;
    NSError *error = nil;
    [self.audioSession setCategory:category error:&error];
    if (error) {
        NSLog(@"set category: %@", error.description);
    }
}

- (void)setPreferredLatency:(NSTimeInterval)preferredLatency{
    _preferredLatency = preferredLatency;
    NSError *error = nil;
    [self.audioSession setPreferredIOBufferDuration:preferredLatency error:&error];
    if (error) {
        NSLog(@"set preferred latency:%@", error.description);
    }
}

- (void)setActive:(BOOL)active{
    _active = active;
    NSError *error = nil;
    [self.audioSession setPreferredSampleRate:self.preferredSampleRate
                                        error:&error];
    if (error) {
        NSLog(@"set preferred sample rate:%@", error.description);
    }
    
    [self.audioSession setActive:active error:&error];
    if (error) {
        NSLog(@"set active:%@", error.description);
    }
    
    _currentSampleRate = [self.audioSession sampleRate];
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
