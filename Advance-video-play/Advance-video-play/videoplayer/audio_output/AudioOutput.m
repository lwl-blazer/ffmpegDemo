//
//  AudioOutput.m
//  Advance-video-play
//
//  Created by luowailin on 2019/9/11.
//  Copyright © 2019 luowailin. All rights reserved.
//

#import "AudioOutput.h"
#import <AudioToolbox/AudioToolbox.h>
#import <Accelerate/Accelerate.h>
#import "ELAudioSession.h"

static const AudioUnitElement inputElement = 1;

static OSStatus InputRenderCallback(void *inRefCon,
                                    AudioUnitRenderActionFlags *ioActionFlags,
                                    const AudioTimeStamp *inTimeStamp,
                                    UInt32 inBusNumber,
                                    UInt32 inNumberFrames,
                                    AudioBufferList *ioData);
static void CheckStatus(OSStatus status, NSString *message, BOOL fatal);

@interface AudioOutput ()
{
    SInt16 *_outData;
}

@property(nonatomic, assign) AUGraph auGraph;
@property(nonatomic, assign) AUNode ioNode;
@property(nonatomic, assign) AudioUnit ioUnit;
@property(nonatomic, assign) AUNode convertNode;
@property(nonatomic, assign) AudioUnit convertUnit;

@property(readwrite, copy) id<FillDataDelegate>fillAudioDataDelegate;

@end


@implementation AudioOutput

- (instancetype)initWithChannels:(NSInteger)channels
            sampleRate:(NSInteger)sampleRate
        bytesPerSample:(NSInteger)bytePerSample filleDataDelegate:(id<FillDataDelegate>)fillAudioDataDelegate{
    self = [super init];
    if (self) {
        //给AVAudioSession设置基本的参数
        [[ELAudioSession sharedInstance] setCategory:AVAudioSessionCategorySoloAmbient]; //AVAudioSessionCategoryPlayAndRecord
        [[ELAudioSession sharedInstance] setPreferredSampleRate:sampleRate];
        [[ELAudioSession sharedInstance] setActive:YES];
        [[ELAudioSession sharedInstance] addRouteChangeListener];
        
        //设置音频被中断的监听器
        [self addAudioSessionInterruptedObserver];
        
        //构建AUGraph
        _outData = (SInt16 *)calloc(8192, sizeof(SInt16));
        _fillAudioDataDelegate = fillAudioDataDelegate;
        _sampleRate = sampleRate;
        _channels = channels;
        [self createAudioUnitGraph];
    }
    return self;
}

/** 构造AUGraph
 *
 * 注意点:
 *  应配置一个ConvertNode将客户端代码填充的SInt16格式的音频数据转换为RemoteIONode可以播放的Float32格式的音频数据(采样率，声道数以及表示格式应对应上)，这一点非常关键
 */
- (void)createAudioUnitGraph{
    OSStatus status = noErr;
    
    status = NewAUGraph(&_auGraph);
    CheckStatus(status, @"Could not create a new AUGraph", YES);
    
    [self addAudioUnitNodes];
    
    status = AUGraphOpen(_auGraph);
    CheckStatus(status, @"Could not open AUGraph", YES);
    
    [self getUnitsFromNodes];
    
    [self setAudioUnitProperties];
    
    [self makeNodeConnections];
    
    CAShow(_auGraph);
    status = AUGraphInitialize(_auGraph);
    CheckStatus(status, @"Could not initialize AUGraph", YES);
}

- (void)addAudioUnitNodes{
    OSStatus status = noErr;
    
    AudioComponentDescription ioDescription;
    bzero(&ioDescription, sizeof(ioDescription));
    ioDescription.componentManufacturer = kAudioUnitManufacturer_Apple;
    ioDescription.componentType = kAudioUnitType_Output;
    ioDescription.componentSubType = kAudioUnitSubType_RemoteIO;
    
    status = AUGraphAddNode(_auGraph, &ioDescription, &_ioNode);
    CheckStatus(status, @"Could not add I/O node to AUGraph", YES);
    
    //注意点--1:初始化convertNode  addNode上
    AudioComponentDescription convertDescription;
    bzero(&convertDescription, sizeof(convertDescription));
    ioDescription.componentManufacturer = kAudioUnitManufacturer_Apple;
    ioDescription.componentType = kAudioUnitType_FormatConverter;
    ioDescription.componentSubType = kAudioUnitSubType_AUConverter;
    
    status = AUGraphAddNode(_auGraph, &ioDescription, &_convertNode);
    CheckStatus(status, @"Could not add Convert node to AUGraph", YES);
}

- (void)getUnitsFromNodes{
    OSStatus status = noErr;
    
    status = AUGraphNodeInfo(_auGraph, _ioNode, NULL, &_ioUnit);
    CheckStatus(status, @"Could not retrieve node info for I/O node", YES);
    
    //注意点--2:附加在_convertUnit上
    status = AUGraphNodeInfo(_auGraph, _convertNode, NULL, &_convertUnit);
    CheckStatus(status, @"Could not retrieve node info for Convert node", YES);
}

//注意点--3:让音频数据(采样率，声道数以及表示格式)对应上
- (void)setAudioUnitProperties{
    OSStatus status = noErr;
    AudioStreamBasicDescription streamFormat = [self nonInterleavedPCMFormatWithChannels:_channels];
    
    status = AudioUnitSetProperty(_ioUnit,
                                  kAudioUnitProperty_StreamFormat,
                                  kAudioUnitScope_Output, //输出
                                  inputElement,
                                  &streamFormat,   //输出的格式
                                  sizeof(streamFormat));
    CheckStatus(status, @"Could not set stream format on I/O unit output scope", YES);
    
    AudioStreamBasicDescription _clientFormat16int;
    UInt32 bytesPerSample = sizeof(SInt16);
    _clientFormat16int.mFormatID = kAudioFormatLinearPCM;
    _clientFormat16int.mFormatFlags = kLinearPCMFormatFlagIsSignedInteger | kLinearPCMFormatFlagIsPacked;
    _clientFormat16int.mBytesPerPacket = bytesPerSample * _channels;
    _clientFormat16int.mFramesPerPacket = 1;
    _clientFormat16int.mBytesPerFrame = bytesPerSample *_channels;
    _clientFormat16int.mChannelsPerFrame = _channels;
    _clientFormat16int.mBitsPerChannel = 8 * bytesPerSample;
    _clientFormat16int.mSampleRate = _sampleRate;
    
    //设置_convertUnit需要转换的输出的格式
    status = AudioUnitSetProperty(_convertUnit,
                                  kAudioUnitProperty_StreamFormat,
                                  kAudioUnitScope_Output, //输出
                                  0,
                                  &streamFormat,
                                  sizeof(streamFormat));
    CheckStatus(status, @"augraph recorder normal unit set client format error", YES);
    
    //设置_convertUnit输入的格式
    status = AudioUnitSetProperty(_convertUnit,
                                  kAudioUnitProperty_StreamFormat,
                                  kAudioUnitScope_Input, //输入
                                  0,
                                  &_clientFormat16int,
                                  sizeof(_clientFormat16int));
    CheckStatus(status, @"augraph recorder normal unit set client format error", YES);
    
    /**
     * 使用属性配置Audio Units
     * kAudioOutputUnitProperty_EnableIO
         用于在I/O Unit上启用或禁用输入或输出。 默认情况下，输出已启用但输入已禁用
     * kAudioUnitProperty_ElementCount
         配置mixer unit上的输入elemnts的数量
     * kAudioUnitProperty_MaximumFramesPerSlice
         为了指定音频数据的最大帧数，audio unit应该准备好响应于回调函数调用而产生。对于大多数音频设备，在大多数情况下，你必须按照参考文档中的说明设置此属性。如果不这样做，屏幕锁定时你的音频将停止
     * kAudioUnitProperty_StreamFormat
         指定特定Audio unit输入或输出总线的音频流数据格式
     */
}

- (AudioStreamBasicDescription)nonInterleavedPCMFormatWithChannels:(UInt32)channels {
    UInt32 bytesPerSample = sizeof(Float32);
    
    AudioStreamBasicDescription asbd;
    bzero(&asbd, sizeof(asbd));
    asbd.mFormatID = kAudioFormatLinearPCM; //格式
    asbd.mFormatFlags = kAudioFormatFlagsNativeFloatPacked | kAudioFormatFlagIsNonInterleaved; //标签格式
    asbd.mBytesPerPacket = bytesPerSample;  //每个Packet的Bytes数量
    asbd.mFramesPerPacket = 1;   //每个Packet的帧数
    asbd.mBytesPerFrame = bytesPerSample;    //每帧的Byte数
    asbd.mChannelsPerFrame = channels;      //声道数
    asbd.mBitsPerChannel = 8 * bytesPerSample;  //每采样点占用位数
    asbd.mSampleRate = _sampleRate;
    return asbd;
}

- (void)makeNodeConnections{
    OSStatus status = noErr;
    
    //将_convertNode 连接 _ioNode   为什么AUGraph知道_ioNode是输出呢，因为在初始化_ioNode的时候componentType为kAudioUnitType_Output
    status = AUGraphConnectNodeInput(_auGraph, _convertNode, 0, _ioNode, 0);
    CheckStatus(status, @"Could not connect I/O node input to mixer node input", YES);
    
    //注意点--5:为ConvertNode配置上InputCallback,
    AURenderCallbackStruct callbackStruct;
    callbackStruct.inputProc = &InputRenderCallback;
    callbackStruct.inputProcRefCon = (__bridge void *)self;
    status = AudioUnitSetProperty(_convertUnit, kAudioUnitProperty_SetRenderCallback, kAudioUnitScope_Input, 0, &callbackStruct, sizeof(callbackStruct));
    CheckStatus(status, @"Could not set render callback on mixer input scope, element 1", YES);
}

//销毁
- (void)destoryAudioUnitGraph{
    AUGraphStop(_auGraph);
    AUGraphUninitialize(_auGraph);
    AUGraphClose(_auGraph);
    AUGraphRemoveNode(_auGraph, _ioNode);
    DisposeAUGraph(_auGraph);
    
    _ioUnit = NULL;
    _ioNode = 0;
    _auGraph = NULL;
}

- (BOOL)play{
    OSStatus status = AUGraphStart(_auGraph);
    CheckStatus(status, @"Could not start AUGraph", YES);
    return YES;
}

- (void)stop{
    OSStatus status = AUGraphStop(_auGraph);
    CheckStatus(status, @"Could not stop AUGraph", YES);
}

- (void)addAudioSessionInterruptedObserver{
    [self removeAudioSessionInterruptedObserver];
    [[NSNotificationCenter defaultCenter] addObserver:self
                                             selector:@selector(onNotificationAudioInterrupted:) name:AVAudioSessionInterruptionNotification object:[AVAudioSession sharedInstance]];
}

- (void)removeAudioSessionInterruptedObserver{
    [[NSNotificationCenter defaultCenter] removeObserver:self
                                                    name:AVAudioSessionInterruptionNotification object:nil];
}

- (void)onNotificationAudioInterrupted:(NSNotification *)sender{
    AVAudioSessionInterruptionType interruptionType = [[[sender userInfo] objectForKey:AVAudioSessionInterruptionTypeKey] unsignedIntegerValue];
    switch (interruptionType) {
        case AVAudioSessionInterruptionTypeBegan:
            [self stop];
            break;
            case AVAudioSessionInterruptionTypeEnded:
            [self play];
            break;
        default:
            break;
    }
}


- (void)dealloc{
    if (_outData) {
        free(_outData);
        _outData = NULL;
    }
    
    [self destoryAudioUnitGraph];
    [self removeAudioSessionInterruptedObserver];
}

- (OSStatus)renderData:(AudioBufferList *)ioData
           atTimeStamp:(const AudioTimeStamp *)timeStmap
            forElement:(UInt32)element
          numberFrames:(UInt32)numFrames
                 flags:(AudioUnitRenderActionFlags *)flags{
    @autoreleasepool {
        for (int iBuffer = 0; iBuffer < ioData->mNumberBuffers; ++iBuffer) {
            memset(ioData->mBuffers[iBuffer].mData, 0, ioData->mBuffers[iBuffer].mDataByteSize); //把ioData中的AudioBuffer的mData按size置成0
        }
        
        if (_fillAudioDataDelegate) {
            [_fillAudioDataDelegate fillAudioData:_outData
                                        numFrames:numFrames
                                      numChannels:_channels];
            for (int iBuffer = 0; iBuffer < ioData->mNumberBuffers; ++iBuffer) {
                memcpy((SInt16 *)ioData->mBuffers[iBuffer].mData, _outData, ioData->mBuffers[iBuffer].mDataByteSize);
            }
        }
        return noErr;
    }
}


@end

static OSStatus InputRenderCallback(void *inRefCon,
                                    AudioUnitRenderActionFlags *ioActionFlags,
                                    const AudioTimeStamp *inTimeStamp,
                                    UInt32 inBusNumber,
                                    UInt32 inNumberFrames,
                                    AudioBufferList *ioData){
    AudioOutput *audioOutput = (__bridge id)inRefCon;
    return [audioOutput renderData:ioData
                       atTimeStamp:inTimeStamp
                        forElement:inBusNumber
                      numberFrames:inNumberFrames
                             flags:ioActionFlags];
}

static void CheckStatus(OSStatus status, NSString *message, BOOL fatal)
{
    if(status != noErr)
    {
        char fourCC[16];
        *(UInt32 *)fourCC = CFSwapInt32HostToBig(status);
        fourCC[4] = '\0';
        
        if(isprint(fourCC[0]) && isprint(fourCC[1]) && isprint(fourCC[2]) && isprint(fourCC[3]))
            NSLog(@"%@: %s", message, fourCC);
        else
            NSLog(@"%@: %d", message, (int)status);
        
        if(fatal)
            exit(-1);
    }
}


/** 整个音频输出模块的工作流程
 * 1.启动播放(AUGraph Start方法)，启动了之后，就会从RemoteIO这个AudioUnit开始播放音频数据
 *
 * 2.如果RemoteIO需要音频数据，就向它的前一级AudioUnit即ConvertNode去获取数据
 *
 * 3. 而ConvertNode则会寻找自己的InputCallback，在InputCallback的实现中其将从delegate(即VideoPlayerController)处获取数据
 */
