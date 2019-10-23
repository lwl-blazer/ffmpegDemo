//
//  AudioUnitMixer.h
//  MultichannelMixerTest
//
//  Created by luowailin on 2019/10/23.
//  Copyright © 2019 luowailin. All rights reserved.
//

#import <Foundation/Foundation.h>
#import <AudioToolbox/AudioToolbox.h>

NS_ASSUME_NONNULL_BEGIN

@interface AudioUnitMixer : NSObject

@property(nonatomic, assign, readonly) BOOL isPlaying;

- (instancetype)initWithPath1:(NSString *)path1
                        path2:(NSString *)path2;

- (void)enableInput:(UInt32)inputNum isOn:(AudioUnitParameterValue)value;
- (void)setInputVolume:(UInt32)inputNum value:(AudioUnitParameterValue)value;
- (void)setOutputVolume:(AudioUnitParameterValue)value;
- (void)start;
- (void)stop;

@end

NS_ASSUME_NONNULL_END
