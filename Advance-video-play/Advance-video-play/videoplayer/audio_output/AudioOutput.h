//
//  AudioOutput.h
//  Advance-video-play
//
//  Created by luowailin on 2019/9/11.
//  Copyright © 2019 luowailin. All rights reserved.
//

#import <Foundation/Foundation.h>

NS_ASSUME_NONNULL_BEGIN

@protocol FillDataDelegate <NSObject>

/**
 填充音频数据

 @param sampleBuffer 填充的缓冲区
 @param frameNum 该缓冲区有多少个音频帧
 @param channels 音频数
 @return 0-faile 1-success
 */
- (NSInteger)fillAudioData:(SInt16 *)sampleBuffer
                 numFrames:(NSInteger)frameNum
               numChannels:(NSInteger)channels;

@end

/** 音频输出模块
 * 不同的平台有不同的实现，所以这里真正的声音渲染API为void类型，但是音频的渲染要放在一个单独的线程(不论平台API自动提供的线程，还是我们主动建立的线程)中进行，所以这里有一个线程的变量，在运行过程中会调用注册过来的回调函数来获取音频数据。
 * 所谓的回调函数在OC中就是协议来实现
 *
 * iOS平台
 *  AudioUnit(AUGraph封装的实际上就是AudioUnit)来渲染音频
 */
@interface AudioOutput : NSObject

@property(nonatomic, assign) Float64 sampleRate;
@property(nonatomic, assign) Float64 channels;

- (instancetype)initWithChannels:(NSInteger)channels
            sampleRate:(NSInteger)sampleRate
        bytesPerSample:(NSInteger)bytePerSample filleDataDelegate:(id<FillDataDelegate>)fillAudioDataDelegate;

- (BOOL)play;
- (void)stop;

@end

NS_ASSUME_NONNULL_END
