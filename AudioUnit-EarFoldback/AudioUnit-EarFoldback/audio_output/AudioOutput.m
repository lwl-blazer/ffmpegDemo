//
//  AudioOutput.m
//  AudioUnit-EarFoldback
//
//  Created by luowailin on 2019/10/11.
//  Copyright © 2019 luowailin. All rights reserved.
//

#import "AudioOutput.h"
#import <AudioToolbox/AudioToolbox.h>
#import <Accelerate/Accelerate.h>
#import "ELAudioSession.h"

//缓冲区数量
static const NSUInteger bufferCount = 3;
//缓冲的大小字节
static const UInt32 inBufferByteSize = 2048;

static void CheckStatus(OSStatus status, NSString *message, BOOL fatal) {
    if (status != noErr) {
        char fourCC[16];
        *(UInt32 *)fourCC = CFSwapInt32HostToBig(status);
        fourCC[4] = '\0';
        if (isprint(fourCC[0]) && isprint(fourCC[1]) && isprint(fourCC[2]) && isprint(fourCC[4])) {
            NSLog(@"%@:%s", message, fourCC);
        } else {
            NSLog(@"%@:%d", message, (int)status);
        }
        
        if (fatal) {
            exit(-1);
        }
    }
};

static OSStatus handleInputBuffer(void *inRefCon,
                                  AudioUnitRenderActionFlags *ioActionFlags,
                                  const AudioTimeStamp *inTimeStamp,
                                  UInt32 inBusNumber,
                                  UInt32 inNumberFrames,
                                  AudioBufferList *ioData);

static void bufferCallback(void *inUserData,
                           AudioQueueRef inAQ,
                           AudioQueueBufferRef buffer){
    NSLog(@"BufferCallback is working");
};


@interface AudioOutput (){
    //音频缓存
    AudioQueueBufferRef audioQueueBuffers[3];
    AudioComponent _audioComponent;
    AudioComponentInstance _audioUnit;
    AudioStreamBasicDescription _asbd;
    //播放音频队列
    AudioQueueRef _audioQueue;
}

@property(nonatomic, assign) int index;

@end

@implementation AudioOutput

- (instancetype)init{
    self = [super init];
    if (self) {
        [[ELAudioSession sharedInstance] setCategory:AVAudioSessionCategoryPlayAndRecord];
        [[ELAudioSession sharedInstance] setActive:YES];
        [[ELAudioSession sharedInstance] addRouteChangeListener];

        [self addAudioSessionInterruptedObserver];
        [self configSession];
    }
    return self;
}

- (void)configSession{
    //创建AudioUnit的方式有两种:裸创建方式,AUGraph创建方式;这里使用的是第一种
    AudioComponentDescription acd = {0};
    acd.componentType = kAudioUnitType_Output;
    acd.componentSubType = kAudioUnitSubType_RemoteIO;
    acd.componentManufacturer = kAudioUnitManufacturer_Apple;
    acd.componentFlags = 0;
    acd.componentFlagsMask = 0;
    //1.创建AudioComponent(就是根据AudioUnit的描述，找出实际的AudioUnit类型)
    _audioComponent = AudioComponentFindNext(NULL, &acd);
    
    OSStatus status = noErr;
    //2.根据类型创建出这个AudioUnit实例
    status = AudioComponentInstanceNew(_audioComponent, &_audioUnit);
    CheckStatus(status, @"create failed", YES);
    
    //设置参数属性
    UInt32 flagOne = 1;
    AudioUnitSetProperty(_audioUnit,
                         kAudioOutputUnitProperty_EnableIO,    //kAudioOutputUnitProperty_EnableIO 用于在I/O unit上启用或禁用输入或输出，默认情况下，输出已启用但输入已禁用
                         kAudioUnitScope_Input,  //Input Scope
                         1, //Element1
                         &flagOne,
                         sizeof(flagOne));
    
    //设置格式
    AudioStreamBasicDescription asbd = {0};
    asbd.mSampleRate = 44100;
    asbd.mFormatID = kAudioFormatLinearPCM;
    asbd.mFormatFlags = (kAudioFormatFlagIsSignedInteger | kAudioFormatFlagIsPacked);
    asbd.mChannelsPerFrame = 1;
    asbd.mFramesPerPacket = 1;
    asbd.mBitsPerChannel = 16;
    asbd.mBytesPerFrame = asbd.mBitsPerChannel * asbd.mChannelsPerFrame / 8;
    asbd.mBytesPerPacket = asbd.mFramesPerPacket * asbd.mBytesPerFrame;
    asbd.mReserved = 0;
    
    //输出的格式
    AudioUnitSetProperty(_audioUnit,
                         kAudioUnitProperty_StreamFormat,  //kAudioUnitProperty_StreamFormat 指定特定audio unit输入或输出总线的音频流数据格式
                         kAudioUnitScope_Output, //Output Scope
                         1, //Element1
                         &asbd,
                         sizeof(asbd));
    
    //AudioUnit的回掉函数
    AURenderCallbackStruct cb = {0};
    cb.inputProcRefCon = (__bridge void *)(self);
    cb.inputProc = handleInputBuffer;
    AudioUnitSetProperty(_audioUnit,
                         kAudioOutputUnitProperty_SetInputCallback, //kAudioOutputUnitProperty_SetInputCallback 设置声音输出回调函数。当speaker需要数据时就会调用回调函数去获取数据。它是 "拉" 数据的概念。
                         kAudioUnitScope_Group,
                         1, //Element1
                         &cb,
                         sizeof(cb));
    /** kAudioOutputUnitProperty_SetInputCallback 与 kAudioUnitProperty_SetRenderCallback的区别
     *
     * kAudioUnitProperty_SetRenderCallback 是audio unit需要数据，向Host请求数据
     * kAudioOutputUnitProperty_SetInputCallback 是audio unit通知
     *
     * global scope: kAudioUnitScope_Group
     *  作为整体应用于audio unit 并且不与任何特定音频相关联，它只有一个element,该范围适用于个别属性，比如每片的最大帧数(kAudioUnitProperty_MaximumFramesPerSlices)
     */
    
    
    //初始化Audio Unit
    status = AudioUnitInitialize(_audioUnit);
    CheckStatus(status, @"initialize AudioUnit faile", YES);
    
    //启动AudioUnit Output
    AudioOutputUnitStart(_audioUnit);
    
    //使用AudioQueue播放
    _asbd.mSampleRate = 44100;
    _asbd.mFormatID = kAudioFormatLinearPCM;
    _asbd.mFormatFlags = kLinearPCMFormatFlagIsSignedInteger | kAudioFormatFlagIsPacked;
    _asbd.mChannelsPerFrame = 1;
    _asbd.mFramesPerPacket = 1;
    _asbd.mBitsPerChannel = 16;
    _asbd.mBytesPerFrame = asbd.mBytesPerFrame;
    _asbd.mBytesPerPacket = asbd.mBytesPerPacket;
    
    //创建AudioQueue
    AudioQueueNewOutput(&_asbd,
                        bufferCallback,
                        (__bridge void *)(self),
                        nil,
                        nil,
                        0,
                        &_audioQueue);
    
    //在Audio Queue启动之后，通过AudioQueueAllocateBuffer生成若干个AudioQueueBufferRef结构(初始化音频缓冲区)
    for (int i = 0; i < bufferCount; i++) {
        status = AudioQueueAllocateBuffer(_audioQueue,
                                          inBufferByteSize,
                                          &audioQueueBuffers[i]);
        CheckStatus(status, @"create AudioQueue faile", YES);
        memset(audioQueueBuffers[i]->mAudioData, 0, inBufferByteSize);
    }
    
    AudioQueueSetParameter(_audioQueue,
                           kAudioQueueParam_Volume,
                           0.8);
}


- (void)addAudioSessionInterruptedObserver{
    [self removeAudioSessionInterrutedObserver];
    [[NSNotificationCenter defaultCenter] addObserver:self
                                             selector:@selector(onNotificationAudioInterrupted:)
                                                 name:AVAudioSessionInterruptionNotification
                                               object:[AVAudioSession sharedInstance]];
}

- (void)removeAudioSessionInterrutedObserver{
    [[NSNotificationCenter defaultCenter] removeObserver:self
                                                    name:AVAudioSessionInterruptionNotification
                                                  object:nil];
}

- (void)onNotificationAudioInterrupted:(NSNotification *)sender{
    AVAudioSessionInterruptionType interruptionType = [[[sender userInfo] objectForKey:AVAudioSessionInterruptionTypeKey] unsignedIntegerValue];
    switch (interruptionType) {
        case AVAudioSessionInterruptionTypeBegan:
            [self stop];
            break;
        case AVAudioSessionInterruptionTypeEnded:
            [self start];
            break;
        default:
            break;
    }
}

//需要数据时候会调用
static OSStatus handleInputBuffer(void *inRefCon,
                                  AudioUnitRenderActionFlags *ioActionFlags,
                                  const AudioTimeStamp *inTimeStamp,
                                  UInt32 inBusNumber,
                                  UInt32 inNumberFrames,
                                  AudioBufferList *ioData){
    
    AudioOutput *output = (__bridge AudioOutput *)inRefCon;
    AudioBufferList bufferList;
    bufferList.mNumberBuffers = 1;
    bufferList.mBuffers[0].mData = NULL;
    bufferList.mBuffers[0].mDataByteSize = 0;
    
    /**注意这个函数
     * AudioUnitRender 获得录制的采样数据
     * 采样到数据后，直接使用AudioQueueEnqueueBuffer把buffer插入Audio Queue中*/
    AudioUnitRender(output->_audioUnit,
                    ioActionFlags,
                    inTimeStamp,
                    inBusNumber,
                    inNumberFrames,
                    &bufferList);
    
    
    void *data = malloc(bufferList.mBuffers[0].mDataByteSize);
    memcpy(data, bufferList.mBuffers[0].mData, bufferList.mBuffers[0].mDataByteSize);
    
    AudioQueueBufferRef audioBuffer = NULL;
    if (output.index == 2) {
        output.index = 0;
    }
    
    audioBuffer = output->audioQueueBuffers[output.index];
    output.index ++;
    audioBuffer->mAudioDataByteSize = bufferList.mBuffers[0].mDataByteSize;
    memset(audioBuffer->mAudioData, 0, bufferList.mBuffers[0].mDataByteSize);
    memcpy(audioBuffer->mAudioData, data, bufferList.mBuffers[0].mDataByteSize);
    
    
    AudioQueueEnqueueBuffer(output->_audioQueue,
                            audioBuffer,
                            0,
                            NULL);
    
    free(data);
    return noErr;
};



#pragma mark -- public method
- (BOOL)start{
    AudioQueueStart(_audioQueue,
                    NULL);
    return YES;
}

- (void)stop{
    AudioQueueStop(_audioQueue, YES);
}

- (void)changeVolume:(int)volume{
    AudioQueueSetParameter(_audioQueue, kAudioQueueParam_Volume, volume);
}

@end

/** Audio Queue
 *
 * 工作模式:
 *  Audio Queue在内部有一套缓冲队列(Buffer Queue)机制。
 *  在AudioQueue启动之后需要通过AudioQueueAllocateBuffer生成若干个AudioQueueBufferRef结构，这些Buffer将用来存储即将要播放的音频数据，并且这些Buffer是受生成他们的AudioQueue实例管理的，内存空间也已经被分配（按照Allocate方法的参数），当AudioQueue被Dispose时这些Buffer也会随之被销毁。
 * 当有音频数据需要被播放时首先需要被memcpy到AudioQueueBufferRef的mAudioData中（mAudioData所指向的内存已经被分配，之前AudioQueueAllocateBuffer所做的工作），并给mAudioDataByteSize字段赋值传入的数据大小。
 * 完成之后需要调用AudioQueueEnqueueBuffer把存有音频数据的Buffer插入到AudioQueue内置的Buffer队列中。
 *
 * 在Buffer队列中有buffer存在的情况下调用AudioQueueStart，此时AudioQueue就回按照Enqueue顺序逐个使用Buffer队列中的buffer进行播放，每当一个Buffer使用完毕之后就会从Buffer队列中被移除并且在使用者指定的RunLoop上触发一个回调来告诉使用者，某个AudioQueueBufferRef对象已经使用完成，你可以继续重用这个对象来存储后面的音频数据。如此循环往复音频数据就会被逐个播放直到结束
 *
 * 比较有价值的参数属性:
 *
 * kAudioQueueProperty_IsRunning监听它可以知道当前AudioQueue是否在运行
 * kAudioQueueProperty_MagicCookie部分音频格式需要设置magicCookie，这个cookie可以从AudioFileStream和AudioFile中获取。
 * kAudioQueueParam_Volume，它可以用来调节AudioQueue的播放音量，注意这个音量是AudioQueue的内部播放音量和系统音量相互独立设置并且最后叠加生效。
 * kAudioQueueParam_VolumeRampTime 参数和Volume参数配合使用可以实现音频播放淡入淡出的效果；
 * kAudioQueueParam_PlayRate参数可以调整播放速率；
 */
