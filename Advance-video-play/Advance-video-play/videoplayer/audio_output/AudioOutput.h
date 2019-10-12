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


/** Audio Unit概念点
 * AUGraph:
 *    包含和管理Audio Unit的组织者
 *
 * AUNode/AudioComponent:
 *    是AUGraph音频处理环节中的一个节点
 * AudioUint:
 *    音频处理组件，是对音频处理节点的实例描述者和操控者
 *
 * 比如:
 *   一个演唱会的舞台上，有录制歌声与乐器的麦克风，从麦克风到输出音响之间，还串接了大大小小的效果器。在这个过程中，无论是麦克风、音响、效果器，都是不同的AUNode.AUNode是这些器材的实体。如果我们要操作或改变这些器材的属性(操控界面)，就是用AudioUnit.最后便构成整个舞台，便是AUGraph.
 *
 * AUNode和AudioComponent的区别:
 *   器材除了放在舞台(AUGraph)上使用，也可以单独拿来使用。当我们要在AUGraph中使用某个器材，我们就会使用AUNode.
 *   也可以单独使用，就是AudioComponent. 但无论是操作AUNode或AudioComponent，都还得透过AudioUnit这一层操作
 *
 * iOS提供了四大类别7种不同的AudioUnit
 *   AudioComponentDescription对象来描述一个具体的AudioUnit
 *   typedef struct AudioComponentDescription {
 *       OSType componentType;   --  AudioUnit主要四种大类型  均衡器/混音/输入输出/格式转换
 *
 *       OSType componentSubType; -- 四大类型对应的子类型
 *
 *       OSType componentManufacturer;   固定: kAudioUnitManufacturer_Apple
 *
 *       UInt32 componentFlags;   -- 一般设置为0
 *
 *       UInt32 componentFlagsMask;  -- 一般设置为0
 *
 * }AudioComponentDescription;
 *
 *
 * Audio Units的Scopes,Elements
 * 
 *
 *
 */
