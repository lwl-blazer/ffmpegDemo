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
    //创建AudioUnit
    AudioComponentDescription acd = {0};
    acd.componentType = kAudioUnitType_Output;
    acd.componentSubType = kAudioUnitSubType_RemoteIO;
    acd.componentManufacturer = kAudioUnitManufacturer_Apple;
    acd.componentFlags = 0;
    acd.componentFlagsMask = 0;
    _audioComponent = AudioComponentFindNext(NULL, &acd);
    
    OSStatus status = noErr;
    status = AudioComponentInstanceNew(_audioComponent, &_audioUnit);
    CheckStatus(status, @"create failed", YES);
    
    //设置参数属性
    UInt32 flagOne = 1;
    AudioUnitSetProperty(_audioUnit,
                         kAudioOutputUnitProperty_EnableIO,
                         kAudioUnitScope_Input,
                         1,
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
    
    AudioUnitSetProperty(_audioUnit,
                         kAudioUnitProperty_StreamFormat,
                         kAudioUnitScope_Output,
                         1,
                         &asbd,
                         sizeof(asbd));
    
    //AudioUnit的回掉函数
    AURenderCallbackStruct cb = {0};
    cb.inputProcRefCon = (__bridge void *)(self);
    cb.inputProc = handleInputBuffer;
    AudioUnitSetProperty(_audioUnit,
                         kAudioOutputUnitProperty_SetInputCallback,
                         kAudioUnitScope_Group,
                         1,
                         &cb,
                         sizeof(cb));
    
    //初始化
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
    
    AudioQueueNewOutput(&_asbd,
                        bufferCallback,
                        (__bridge void *)(self),
                        nil,
                        nil,
                        0,
                        &_audioQueue);
    
    //初始化音频缓冲区
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
