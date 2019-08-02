//
//  AVAudioSession+RouteUtils.m
//  AUPlayer
//
//  Created by luowailin on 2019/8/2.
//  Copyright © 2019 luowailin. All rights reserved.
//

#import "AVAudioSession+RouteUtils.h"

@implementation AVAudioSession (RouteUtils)

- (BOOL)usingBlueTooth{
    NSArray *inputs = self.currentRoute.inputs;
    NSArray *blueToothInputRoutes = @[AVAudioSessionPortBluetoothHFP];
    for (AVAudioSessionPortDescription *desc in inputs) {
        if ([blueToothInputRoutes containsObject:desc.portType]) {
            return YES;
        }
    }
    
    NSArray *outputs = self.currentRoute.outputs;
    NSArray *blueToothOutputRoutes = @[AVAudioSessionPortBluetoothHFP,
                                       AVAudioSessionPortBluetoothA2DP,
                                       AVAudioSessionPortBluetoothLE];
    for (AVAudioSessionPortDescription *desc in outputs) {
        if ([blueToothOutputRoutes containsObject:desc.portType]) {
            return YES;
        }
    }
    
    return NO;
}

- (BOOL)usingWiredMicrophone{
    NSArray *inputs = self.currentRoute.inputs;
    NSArray *headSetInputRoutes = @[AVAudioSessionPortHeadsetMic];
    for (AVAudioSessionPortDescription *desc in inputs) {
        if ([headSetInputRoutes containsObject:desc.portType]) {
            return YES;
        }
    }
    
    NSArray *outputs = self.currentRoute.outputs;
    NSArray *headSetOutputRoutes = @[AVAudioSessionPortHeadphones, AVAudioSessionPortUSBAudio];
    for (AVAudioSessionPortDescription *desc in outputs) {
        if ([headSetOutputRoutes containsObject:desc.portType]) {
            return YES;
        }
    }
    
    return NO;
}

- (BOOL)shouldShowEarphoneAlert{
    // 用户如果没有带耳机，则应该提出提示，目前采用保守策略，即尽量减少alert弹出，所以，我们认为只要不是用手机内置的听筒或者喇叭作为声音外放的，都认为用户带了耳机
    NSArray *outputs = self.currentRoute.outputs;
    NSArray *headSetOutputRoutes = @[AVAudioSessionPortBuiltInReceiver, AVAudioSessionPortBuiltInSpeaker];
    for (AVAudioSessionPortDescription *desc in outputs) {
        if ([headSetOutputRoutes containsObject:desc.portType]) {
            return YES;
        }
    }
    return NO;
}

@end
