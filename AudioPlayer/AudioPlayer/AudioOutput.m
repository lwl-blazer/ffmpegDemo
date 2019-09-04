//
//  AudioOutput.m
//  AudioPlayer
//
//  Created by luowailin on 2019/8/5.
//  Copyright © 2019 luowailin. All rights reserved.
//

#import "AudioOutput.h"
#import <AudioToolbox/AudioToolbox.h>
#import <Accelerate/Accelerate.h>
#import <AVFoundation/AVFoundation.h>

#import "CommonUtil.h"
#import "ELAudioSession.h"

static const AudioUnitElement inputElement = 1;
static OSStatus InputRenderCallBack(void *inRefCon,
                                    AudioUnitRenderActionFlags *ioActionFlags,
                                    const AudioTimeStamp *inTimeStamp,
                                    UInt32 inBusNumber,
                                    UInt32 inNumberFrames,
                                    AudioBufferList *ioData);
static void CheckStatus(OSStatus status, NSString *message, BOOL fatal);

@interface AudioOutput (){
    SInt16 *_outData;
}

//播放 AUGraph
@property(nonatomic, assign) AUGraph   auGraph;
@property(nonatomic, assign) AUNode    ioNode;
@property(nonatomic, assign) AudioUnit ioUnit;

//格式转换AUGraph
@property(nonatomic, assign) AUNode    convertNoder;
@property(nonatomic, assign) AudioUnit convertUnit;

@property(nonatomic, assign) id<FillDataDelegate>fillAudioDataDelegate;

@end

const float SMAudioIOBufferDurationSmall = 0.0058f;

@implementation AudioOutput

- (instancetype)initWithChannels:(NSInteger)channels
                      sampleRate:(NSInteger)sampleRate
                  bytesPerSample:(NSInteger)bytesPerSample
               filleDataDelegate:(id<FillDataDelegate>)fillAudioDataDelegate{
    self = [super init];
    if (self) {
        [[ELAudioSession sharedInstance] setCategory:AVAudioSessionCategoryPlayback];
        [[ELAudioSession sharedInstance] setPerferredSampleRate:sampleRate];
        [[ELAudioSession sharedInstance] setActive:YES];
        [[ELAudioSession sharedInstance] setPreferredLatency:SMAudioIOBufferDurationSmall  * 4];
    
        [self addAudioSessionInterruptedObserver];
        
        _outData = (SInt16 *)calloc(8192, sizeof(SInt16));
        _fillAudioDataDelegate = fillAudioDataDelegate;
        _sampleRate = sampleRate;
        _channels = channels;
        
        [self createAudioUnitGraph];
    }
    return self;
}


/** 构建AudioUnit
 * 1.指定类型(type)
 * 2.子类型(subtype)
 * 3.厂商(manufacture) 比较固定 kAudioUnitManufacture_Apple
 *
 * Audio Unit主要涉及到三个常用概念:
 * 1. AUGraph  包含和管理Audio Unit的组织者
 * 2. AUNode / AudioComponent 是AUGraph音频处理环节中的一个节点
 * 3. AudioUnit 音频处理组件，是对音频处理节点的实例描述者和操控者
 */
- (void)createAudioUnitGraph{
    OSStatus status = noErr;
    
    status = NewAUGraph(&_auGraph); //创建AUGraph
    CheckStatus(status, @"Could not create a new AUGraph", YES);

    [self addAudioUnitNodes]; //配置AUNode
    
    status = AUGraphOpen(_auGraph); //打开AUGraph
    CheckStatus(status, @"Could not open AUGraph", YES);
    
    [self getUnitsFromNodes]; //获取AudioUnit
    
    [self setAudioUnitProperties]; //设置AudioUnit的属性
    
    [self makeNodeConnections];  //串联Audio Node   并设置回调函数
    
    
    CAShow(_auGraph);   //这是一个打印的作用
    status = AUGraphInitialize(_auGraph);   //初始化 一定要全部配置完成以后
    CheckStatus(status, @"Could not initialize AUGraph", YES);
}

//创建AUNode 并添加到AUGraph
- (void)addAudioUnitNodes{
    OSStatus status = noErr;
    
    //I/O AudioUnit
    AudioComponentDescription ioDescription;
    bzero(&ioDescription, sizeof(ioDescription));  //extern void bzero(void *s, int n) 置字节字符串前n个字节为零且包括'\0'
    ioDescription.componentManufacturer = kAudioUnitManufacturer_Apple;
    ioDescription.componentType = kAudioUnitType_Output;
    ioDescription.componentSubType = kAudioUnitSubType_RemoteIO;
    //最终创建AUGraph
    status = AUGraphAddNode(_auGraph,
                            &ioDescription,
                            &_ioNode);   //参数1:创建的AUGraph 参数2:描术信息 参数3:输出的AUNode
    CheckStatus(status, @"Could not add I/O node to AUGraph", YES);
    
    //Convert AudioUnit
    AudioComponentDescription convertDescription;
    bzero(&convertDescription, sizeof(convertDescription));
    ioDescription.componentManufacturer = kAudioUnitManufacturer_Apple;
    ioDescription.componentType = kAudioUnitType_FormatConverter;
    ioDescription.componentSubType = kAudioUnitSubType_AUConverter;
    status = AUGraphAddNode(_auGraph,
                            &ioDescription,
                            &_convertNoder);
    CheckStatus(status, @"Could not add Convert node to AUGraph", YES);
}

- (void)getUnitsFromNodes{
    OSStatus status = noErr;
    status = AUGraphNodeInfo(_auGraph,
                             _ioNode,
                             NULL,
                             &_ioUnit);   //最终输出_ioUnit
    
    status = AUGraphNodeInfo(_auGraph, _convertNoder, NULL, &_convertUnit); //最终输出_convertUnit
    CheckStatus(status, @"Could not retrieve node info for Convert node", YES);
}

/** 设置AudioUnit的属性
 * AudioUnit实际上就是一个AudioComponentInstance实例对象，一个AudioUnit由scope(范围)和element(元素)组成，
 * scope 主要使用到的输入kAudioUnitScope_Input 和 输出 kAudioUnitScope_Output
 * element   Input用“1”表示   Output用“0”表示
 */
- (void)setAudioUnitProperties{
    OSStatus status = noErr;
    AudioStreamBasicDescription streamFormat = [self nonInterleavedPCMFormatWithChannels:_channels];
    status = AudioUnitSetProperty(_ioUnit,
                                  kAudioUnitProperty_StreamFormat,     //属性名称
                                  kAudioUnitScope_Output,      //scope 输入输出范围
                                  inputElement,         //element  1表示输入总线 0输出总线
                                  &streamFormat,     //输入值
                                  sizeof(streamFormat));     //输入值长度
    CheckStatus(status, @"Could not set stream format on I/O unit output scope", YES);
    
    AudioStreamBasicDescription _clientFormat16int;
    UInt32 bytesPerSample = sizeof(SInt16);
    bzero(&_clientFormat16int, sizeof(_clientFormat16int));
    _clientFormat16int.mFormatID = kAudioFormatLinearPCM;
    _clientFormat16int.mFormatFlags = kLinearPCMFormatFlagIsSignedInteger|kLinearPCMFormatFlagIsPacked;
    _clientFormat16int.mBytesPerPacket = bytesPerSample * _channels;
    _clientFormat16int.mFramesPerPacket = 1;
    _clientFormat16int.mBytesPerFrame = bytesPerSample * _channels;
    _clientFormat16int.mChannelsPerFrame = _channels;
    _clientFormat16int.mBitsPerChannel = 8 * bytesPerSample;
    _clientFormat16int.mSampleRate = _sampleRate;
    
    status = AudioUnitSetProperty(_convertUnit,
                                  kAudioUnitProperty_StreamFormat,
                                  kAudioUnitScope_Output,
                                  0,
                                  &streamFormat,
                                  sizeof(streamFormat));
    CheckStatus(status, @"augraph recorder normal unit set client format error", YES);
    
    status = AudioUnitSetProperty(_convertUnit,
                                  kAudioUnitProperty_StreamFormat,
                                  kAudioUnitScope_Input,
                                  0,
                                  &_clientFormat16int,
                                  sizeof(_clientFormat16int));
    CheckStatus(status, @"augraph recorder normal unit set client format error", YES);
}

- (AudioStreamBasicDescription)nonInterleavedPCMFormatWithChannels:(UInt32)channels{
    UInt32 bytesPerSample = sizeof(Float32);
    
    AudioStreamBasicDescription asbd;
    bzero(&asbd, sizeof(asbd));
    asbd.mSampleRate = _sampleRate;    //采样率
    asbd.mFormatID = kAudioFormatLinearPCM;  //PCM采样率
    asbd.mFormatFlags = kAudioFormatFlagsNativeFloatPacked|kAudioFormatFlagIsNonInterleaved;
    asbd.mBitsPerChannel = 8 * bytesPerSample;    //语音每采样点占用位数
    asbd.mBytesPerFrame = bytesPerSample;     //每帧的bytes数
    asbd.mBytesPerPacket = bytesPerSample;   //每个数据包的bytes总数，每帧的bytes数 * 每个数据包的帧数
    asbd.mFramesPerPacket = 1;   //每个数据包多少帧
    asbd.mChannelsPerFrame = channels;    //1单声道 2立体声
    return asbd;
}

- (void)makeNodeConnections{
    OSStatus status = noErr;
    status = AUGraphConnectNodeInput(_auGraph,
                                     _convertNoder,
                                     0,
                                     _ioNode,
                                     0); //串联
    CheckStatus(status,
                @"Could not connect I/O node input to mixer node input",
                YES);
    
    AURenderCallbackStruct callbacStruct;
    callbacStruct.inputProc = &InputRenderCallBack;
    callbacStruct.inputProcRefCon = (__bridge void *)self;
    
    status = AudioUnitSetProperty(_convertUnit,
                                  kAudioUnitProperty_SetRenderCallback,     //回调函数的类型
                                  kAudioUnitScope_Input,
                                  0,
                                  &callbacStruct,
                                  sizeof(callbacStruct));
    CheckStatus(status, @"Could not set reander callback no mixer input scope, element 1", YES);
}

- (void)destroyAudioUnitGraph{
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
    OSStatus status = AUGraphStart(_auGraph);    //开始播放
    CheckStatus(status,
                @"Could not start AUGraph", YES);
    return YES;
}

- (void)stop{
    OSStatus status = AUGraphStop(_auGraph);   //停止播放
    CheckStatus(status, @"Could not stop AUGraph", YES);
}

- (void)addAudioSessionInterruptedObserver{
    [self removeAudioSessionInterruptedObserver];
    [[NSNotificationCenter defaultCenter] addObserver:self
                                             selector:@selector(onNotificationAudioInterrupted:)
                                                 name:AVAudioSessionInterruptionNotification
                                               object:[AVAudioSession sharedInstance]];
}

- (void)removeAudioSessionInterruptedObserver{
    [[NSNotificationCenter defaultCenter] removeObserver:self
                                                    name:AVAudioSessionInterruptionNotification
                                                  object:nil];
}

- (void)onNotificationAudioInterrupted:(NSNotification *)sender{
    AVAudioSessionInterruptionType type = [[[sender userInfo] objectForKey:AVAudioSessionInterruptionTypeKey] unsignedIntegerValue];
    switch (type) {
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
    
    [self destroyAudioUnitGraph];
    [self removeAudioSessionInterruptedObserver];
}

- (OSStatus)renderData:(AudioBufferList *)ioData
           atTimeStamp:(const AudioTimeStamp *)timeStamp
            forElement:(UInt32)element
          numberFrames:(UInt32)numFrames
                 flags:(AudioUnitRenderActionFlags *)flags{
    for (int iBuffer = 0; iBuffer < ioData->mNumberBuffers; ++iBuffer) {
        memset(ioData->mBuffers[iBuffer].mData,
               0,
               ioData->mBuffers[iBuffer].mDataByteSize);   //重置
    }
    
    if (_fillAudioDataDelegate) {
        [_fillAudioDataDelegate fillAudioData:_outData
                                    numFrames:numFrames
                                  numChannels:_channels];
        
        for (int iBuffer = 0; iBuffer < ioData->mNumberBuffers; ++iBuffer) {
            memcpy((SInt16 *)ioData->mBuffers[iBuffer].mData,
                   _outData,
                   ioData->mBuffers[iBuffer].mDataByteSize);
        }
    }
    return noErr;
}

@end

OSStatus InputRenderCallBack(void *inRefCon,
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
