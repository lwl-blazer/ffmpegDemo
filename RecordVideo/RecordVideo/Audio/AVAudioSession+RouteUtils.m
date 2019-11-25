//
//  AVAudioSession+RouteUtils.m
//  RecordVideo
//
//  Created by luowailin on 2019/11/14.
//  Copyright © 2019 luowailin. All rights reserved.
//

#import "AVAudioSession+RouteUtils.h"

@implementation AVAudioSession (RouteUtils)
//蓝牙设备
- (BOOL)usingBlueTooth{
    //输入
    NSArray *inputs = self.currentRoute.inputs;
    NSArray *blueToothInputRoutes = @[AVAudioSessionPortBluetoothHFP];
    for (AVAudioSessionPortDescription *desc in inputs) {
        if ([blueToothInputRoutes containsObject:desc.portType]) {
            return YES;
        }
    }
    
    //输出
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
    NSArray *headSetoutputRoutes = @[AVAudioSessionPortHeadphones, AVAudioSessionPortUSBAudio];
    for (AVAudioSessionPortDescription *desc in outputs) {
        if ([headSetoutputRoutes containsObject:desc.portType]) {
            return YES;
        }
    }
    
    return NO;
}

- (BOOL)shouldShowEarphoneAlert{
    NSArray *outputs = self.currentRoute.outputs;
    NSArray *headsetOutputRoutes = @[AVAudioSessionPortBuiltInReceiver,
                                     AVAudioSessionPortBuiltInSpeaker];
    for (AVAudioSessionPortDescription *desc in outputs) {
        if ([headsetOutputRoutes containsObject:desc.portType]) {
            return YES;
        }
    }
    return NO;
}

@end
