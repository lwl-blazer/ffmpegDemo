//
//  AudioUnitMixer.m
//  MultichannelMixerTest
//
//  Created by luowailin on 2019/10/23.
//  Copyright © 2019 luowailin. All rights reserved.
//

#import "AudioUnitMixer.h"
#import <AudioUnit/AudioUnit.h>
#import <AVFoundation/AVFoundation.h>
#import "ELAudioSession.h"

#define MAXBUFS 2
#define NUMFILES 2

typedef struct {
    AudioStreamBasicDescription asbd;
    Float32 *data;
    UInt32 numFrames;
    UInt32 sampleNum;
} SoundBuffer, *SoundBufferPtr;

static void CheckStatus(OSStatus status, NSString *message, BOOL fatal) {
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

/**
 * AURenderCallback
 * 当Audio Unit需要input samples的时候由系统调用，可能发生在渲染操作之前或者之后
 * 参数:
 * inRefCon
 *     在向Audio Unit 注册回调时提供的自定义数据
 *
 * ioActionFlags
 *    Audio Unit渲染的标志
 *
 * inTimeStamp
 *   Audio Unit渲染调用相关的时间戳
 *
 * inBusNumber
 *   bus
 *
 * inNumberFrames
 *   ioData需要多少样本帧数
 *
 * ioData
 *   提供的数据
 */

static OSStatus renderInput(void *inRefCon,
                            AudioUnitRenderActionFlags *ioActionFlags,
                            const AudioTimeStamp *inTimeStamp,
                            UInt32 inBusNumber,
                            UInt32 inNumberFrames,
                            AudioBufferList *ioData){
    
    SoundBufferPtr sndbuf = (SoundBufferPtr)inRefCon;
    
    UInt32 sample = sndbuf[inBusNumber].sampleNum;
    UInt32 bufSamples = sndbuf[inBusNumber].numFrames;
    
    //引用
    Float32 *in = sndbuf[inBusNumber].data;
    Float32 *outA = (Float32 *)ioData->mBuffers[0].mData;
    Float32 *outB = (Float32 *)ioData->mBuffers[1].mData;
    
    
    for (UInt32 i = 0; i < inNumberFrames; ++i) {
        if (inBusNumber == 1) {
            outA[i] = 0;
            outB[i] = in[sample++];
        } else {
            outA[i] = in[sample++];
            outB[i] = 0;
        }
        if (sample > bufSamples) {
            NSLog(@"looping data for bus %d after %ld source frames rendered", (unsigned int)inBusNumber, (long)sample-1);
            sample = 0; //置于0 就是要进行重新播放
        }
    }
    
    //记录下一次开始的位置
    sndbuf[inBusNumber].sampleNum = sample;
    return noErr;
}


@interface AudioUnitMixer (){
    CFURLRef sourceURL[2];
    SoundBuffer mSoundBuffer[MAXBUFS];
}

@property(nonatomic, strong) AVAudioFormat *mAudioFormat;
@property(nonatomic, assign) AUGraph auGraph;
@property(nonatomic, assign) AudioUnit mMixer;
@property(nonatomic, assign) AUNode mixerNode;
@property(nonatomic, assign) AudioUnit outputUnit;
@property(nonatomic, assign) AUNode outputNode;

@property(nonatomic, assign, readwrite) BOOL isPlaying;
@property(nonatomic, assign) Float64 sampleRate;

@end


@implementation AudioUnitMixer

- (void)createAudioUnitGraph{
    self.mAudioFormat = [[AVAudioFormat alloc] initWithCommonFormat:AVAudioPCMFormatFloat32
                                                         sampleRate:self.sampleRate
                                                           channels:2
                                                        interleaved:NO];
    /**performSelectorInBackground 在后台创建一个新线程，把调用方法放进去 */
    [self performSelectorInBackground:@selector(loadFiles) withObject:nil];
    
    OSStatus result = NewAUGraph(&_auGraph);
    CheckStatus(result, @"create a new AUGraph faile", YES);
    
    [self addAudioUnitNodes];
    result = AUGraphOpen(_auGraph);
    CheckStatus(result, @"Could not open AUGraph", YES);
    
    [self getUnitsFromNodes];
    [self setAudioUnitProperties];
    [self makeNodeConnections];
    
    CAShow(_auGraph);
    result = AUGraphInitialize(_auGraph);
    CheckStatus(result, @"Could not initialize AUGraph", YES);
}

- (void)addAudioUnitNodes{
    OSStatus result = noErr;
    AudioComponentDescription ioDescription;
    bzero(&ioDescription, sizeof(ioDescription));
    ioDescription.componentType = kAudioUnitType_Output;
    ioDescription.componentSubType = kAudioUnitSubType_RemoteIO;
    ioDescription.componentManufacturer = kAudioUnitManufacturer_Apple;
    result = AUGraphAddNode(_auGraph,
                            &ioDescription,
                            &_outputNode);
    CheckStatus(result, @"create io node faile", YES);
    
    AudioComponentDescription mixerDescription;
    bzero(&mixerDescription, sizeof(mixerDescription));
    mixerDescription.componentType = kAudioUnitType_Mixer;
    mixerDescription.componentSubType = kAudioUnitSubType_MultiChannelMixer;
    mixerDescription.componentManufacturer = kAudioUnitManufacturer_Apple;
    result = AUGraphAddNode(_auGraph,
                            &mixerDescription,
                            &_mixerNode);
    CheckStatus(result, @"create mixer node faile", YES);
}

- (void)getUnitsFromNodes{
    OSStatus result = noErr;
    result = AUGraphNodeInfo(_auGraph,
                             _mixerNode,
                             NULL,
                             &_mMixer);
    CheckStatus(result, @"AUGraphNodeInfo_mMixer", YES);
    
    result = AUGraphNodeInfo(_auGraph,
                             _outputNode,
                             NULL,
                             &_outputUnit);
    CheckStatus(result, @"AUGraphNodeInfo_outputUnit", YES);
}

- (void)setAudioUnitProperties{
    OSStatus result = noErr;
    UInt32 numbuses = 2;
    result = AudioUnitSetProperty(_mMixer,
                                  kAudioUnitProperty_ElementCount,
                                  kAudioUnitScope_Input,
                                  0,
                                  &numbuses,
                                  sizeof(numbuses));
    CheckStatus(result, @"AudioUnitSetProperty_mixer_kAudioUnitProperty_ElementCount", YES);
    
    for (int i = 0; i < numbuses; i ++) {
        AURenderCallbackStruct rcbs;
        rcbs.inputProc = &renderInput;
        rcbs.inputProcRefCon = mSoundBuffer;
        /** AUGraphSetNodeInputCallback 是set input
         *
         * 可能出现的问题:
         *   AUGraphSetNodeInputCallback 给Remote I/O Unit设置回调失效问题
         *   给Remote I/O 设置回调可以用AudioUnitSetProperty方法修改 kAudioOutputUnitProperty_SetInputCallback设置回调，但尝试用AuGraphSetNodeInputCallback对Remote I/O Unit节点添加回调的时候，发现没有办法正常调用回调函数
         *   AUGraphSetNodeInputCallback(auGraph, outputNode, 1, &rcbs)
         *  原因:
         *     AUGraphSetNodeInputCallback 默认是inputScope,如果在input bus的inputScope修改属性会造成异常现象
         *
         *
         * kAudioOutputUnitProperty_SetInputCallback和kAudioUnitProperty_SetRenderCallback混淆:
         *   kAudioOutputUnitProperty_SetInputCallback 是Audio Unit需要数据，向host请求数据
         *   kAudioUnitProperty_SetRenderCallback 是Audio Unit通知Host数据已经就绪，可以通过Audio Unit Render拉取数据
         *
         *
         **/
        result = AUGraphSetNodeInputCallback(_auGraph,
                                             _mixerNode,
                                             i,
                                             &rcbs);
        CheckStatus(result, @"AUGraphSetNodeInputCallback", YES);
        
        result = AudioUnitSetProperty(_mMixer,
                                      kAudioUnitProperty_StreamFormat,
                                      kAudioUnitScope_Input,
                                      i,
                                      self.mAudioFormat.streamDescription,
                                      sizeof(AudioStreamBasicDescription));
        CheckStatus(result, @"AudioUnitSetProperty__kAudioUnitProperty_StreamFormat", YES);
    }
    
    
    result = AudioUnitSetProperty(_mMixer,
                                  kAudioUnitProperty_StreamFormat,
                                  kAudioUnitScope_Output,
                                  0,
                                  self.mAudioFormat.streamDescription,
                                  sizeof(AudioStreamBasicDescription));
    CheckStatus(result, @"AudioUnitSetProperty_bus0_kAudioUnitProperty_StreamFormat", YES);
    
    result = AudioUnitSetProperty(_outputUnit,
                                  kAudioUnitProperty_StreamFormat,
                                  kAudioUnitScope_Output,
                                  1,
                                  self.mAudioFormat.streamDescription,
                                  sizeof(AudioStreamBasicDescription));
    CheckStatus(result, @"AudioUnitSetProperty_bus1_kAudioUnitProperty_StreamFormat", YES);
}

- (void)makeNodeConnections{
    OSStatus result = noErr;
    
    /** AUGraphConnectNodeInput
     * 注意点:
     * 从字面看是看_mixerNoder的输出作为_outputNode的输入，但是在bus的参数设置上，为什么Remote I/O Unit的bus不是(inputBush)1呢
     * 原因:
     *   因为Remote I/O Unit有输入域有两个Bus,inputBus对应的是麦克风的输入，outputBus对应的是app发送给Remote I/O Unit的数据
     *   这里Mixer Unit是把数据混合后，输出给Remote I/O Unit 相当于App发送数据给Remote I/O Unit 所以这里应该填outputBus
     */
    result = AUGraphConnectNodeInput(_auGraph,
                                     _mixerNode,
                                     0,
                                     _outputNode,
                                     0);
    CheckStatus(result, @"Could not connect mixerNode output to output output", YES);
}

- (void)loadFiles{
    AVAudioFormat *clientFormat = [[AVAudioFormat alloc] initWithCommonFormat:AVAudioPCMFormatFloat32
                                                                   sampleRate:self.sampleRate
                                                                     channels:1
                                                                  interleaved:YES];
    for (int i = 0; i < NUMFILES && i < MAXBUFS; i ++) {
        ExtAudioFileRef xafref = 0;
        OSStatus result;
        result = ExtAudioFileOpenURL(sourceURL[i],
                                     &xafref);
        CheckStatus(result, @"ExtAudioFileOpenURL", YES);
        
        AudioStreamBasicDescription fileFormat;
        UInt32 propSize = sizeof(fileFormat);
        result = ExtAudioFileGetProperty(xafref,
                                         kExtAudioFileProperty_FileDataFormat,
                                         &propSize,
                                         &fileFormat);
        CheckStatus(result, @"ExtAudioFileGetProperty__kExtAudioFileProperty_FileDataFormat", YES);
        
        double rateRatio = self.sampleRate / fileFormat.mSampleRate;
        propSize = sizeof(AudioStreamBasicDescription);
        result = ExtAudioFileSetProperty(xafref,
                                         kExtAudioFileProperty_ClientDataFormat,
                                         propSize,
                                         clientFormat.streamDescription);
        CheckStatus(result, @"ExtAudioFileSetProperty__kExtAudioFileProperty_ClientDataFormat", YES);
        
        UInt64 numFrames = 0;
        propSize = sizeof(numFrames);
        result = ExtAudioFileGetProperty(xafref,
                                         kExtAudioFileProperty_FileLengthFrames,
                                         &propSize,
                                         &numFrames);
        CheckStatus(result, @"ExtAudioFileGetProperty__kExtAudioFileProperty_FileLengthFrames", YES);
        printf("File %d, Number of sample Frames:%u\n", i, (unsigned int)numFrames);
        
        numFrames = (numFrames * rateRatio);
        printf("File %d Number of Sample Frames after rate conversion (if any):%u\n", i, (unsigned int)numFrames);
        
        mSoundBuffer[i].numFrames = (UInt32)numFrames;
        mSoundBuffer[i].asbd = *(clientFormat.streamDescription);
        
        UInt32 samples = (UInt32)numFrames * mSoundBuffer[i].asbd.mChannelsPerFrame;
        mSoundBuffer[i].data = (Float32 *)calloc(samples, sizeof(Float32));
        mSoundBuffer[i].sampleNum = 0;
        
        AudioBufferList bufList;
        bufList.mNumberBuffers = 1;
        bufList.mBuffers[0].mNumberChannels = 1;
        bufList.mBuffers[0].mData = mSoundBuffer[i].data;
        bufList.mBuffers[0].mDataByteSize = samples * sizeof(Float32);
        
        UInt32 numPackets = (UInt32)numFrames;
        result = ExtAudioFileRead(xafref,
                                  &numPackets,
                                  &bufList);
        CheckStatus(result, @"ExtAudioFileRead", NO);
        if (result) {
            free(mSoundBuffer[i].data);
            mSoundBuffer[i].data = 0;
        }
        ExtAudioFileDispose(xafref);
     }
}

- (void)addAudioSessionInterruptedObserver{
    [self removeAudioSessionInterruptedObserver];
    [[NSNotificationCenter defaultCenter] addObserver:self
                                             selector:@selector(onNotificationAudioInterrupted:)
                                                 name:AVAudioSessionInterruptionNotification
                                               object:[AVAudioSession sharedInstance]];
}

- (void)onNotificationAudioInterrupted:(NSNotification *)sender{
    AVAudioSessionInterruptionType interruption = [[[sender userInfo] objectForKey:AVAudioSessionInterruptionTypeKey] unsignedIntValue];
    switch (interruption) {
        case AVAudioSessionInterruptionTypeBegan:{
            if (self.isPlaying) {
                [self stop];
            }
        }
            break;
        case AVAudioSessionInterruptionTypeEnded:
            [self start];
            break;
        default:
            break;
    }
}

- (void)removeAudioSessionInterruptedObserver{
    [[NSNotificationCenter defaultCenter] removeObserver:self
                                                    name:AVAudioSessionInterruptionNotification
                                                  object:nil];
 }

#pragma mark -- public method
- (instancetype)initWithPath1:(NSString *)path1
                        path2:(NSString *)path2{
    self = [super init];
    if (self) {
        memset(&mSoundBuffer, 0, sizeof(mSoundBuffer));
        
        sourceURL[0] = CFURLCreateWithFileSystemPath(kCFAllocatorDefault,
                                                     (CFStringRef)path1,
                                                     kCFURLPOSIXPathStyle,
                                                     false);
        sourceURL[1] = CFURLCreateWithFileSystemPath(kCFAllocatorDefault,
                                                     (CFStringRef)path2,
                                                     kCFURLPOSIXPathStyle,
                                                     false);
        
        self.isPlaying = NO;
        
        _sampleRate = 44100.0;
        [[ELAudioSession sharedInstance] setCategory:AVAudioSessionCategoryPlayback];
        [[ELAudioSession sharedInstance] setPreferredLatency:0.0005];
        [[ELAudioSession sharedInstance] setPreferredSampleRate:self.sampleRate];
        [[ELAudioSession sharedInstance] addRouteChangeListener];
        [[ELAudioSession sharedInstance] setActive:YES];
        
        [self addAudioSessionInterruptedObserver];
        [self createAudioUnitGraph];
    }
    return self;
}

- (void)enableInput:(UInt32)inputNum isOn:(AudioUnitParameterValue)value{
    printf("BUS %d isOn %f\n", (unsigned int)inputNum, value);
    
    OSStatus status = AudioUnitSetParameter(_mMixer,
                                            kMultiChannelMixerParam_Enable,
                                            kAudioUnitScope_Input,
                                            inputNum,
                                            value,
                                            0);
    CheckStatus(status, @"AudioUnitSetParameter__kMultiChannelMixerParam_Enable", YES);
}

- (void)setInputVolume:(UInt32)inputNum value:(AudioUnitParameterValue)value{
    
    OSStatus status = AudioUnitSetParameter(_mMixer,
                                            kMultiChannelMixerParam_Volume,
                                            kAudioUnitScope_Input,
                                            inputNum,
                                            value,
                                            0);
    CheckStatus(status, @"AudioUnitSetParameter__kMultiChannelMixerParam_Volume", YES);
}

- (void)setOutputVolume:(AudioUnitParameterValue)value{
    OSStatus status = AudioUnitSetParameter(_mMixer,
                                            kMultiChannelMixerParam_Volume,
                                            kAudioUnitScope_Output,
                                            0,
                                            value,
                                            0);
    CheckStatus(status, @"AudioUnitSetParameter__kMultiChannelMixerParam_Volume", YES);
}

- (void)start{
    OSStatus status = AUGraphStart(_auGraph);
    CheckStatus(status, @"graph start", YES);
    self.isPlaying = YES;
}

- (void)stop{
    Boolean isRunning = false;
    OSStatus status = AUGraphIsRunning(_auGraph,
                                       &isRunning);
    CheckStatus(status, @"AUGraphIsRunning", YES);
    if (isRunning) {
        status = AUGraphStop(_auGraph);
        CheckStatus(status, @"augraph stop", YES);
        self.isPlaying = NO;
    }
}


- (void)destoryAudioUnitGraph{
    AUGraphStop(_auGraph);
    AUGraphUninitialize(_auGraph);
    AUGraphRemoveNode(_auGraph, _mixerNode);
    AUGraphRemoveNode(_auGraph, _outputNode);
    
    DisposeAUGraph(_auGraph);
    
    _mMixer = NULL;
    _outputUnit = NULL;
    _mixerNode = 0;
    _outputNode = 0;
    _auGraph = NULL;
}


- (void)dealloc{
    [self destoryAudioUnitGraph];
    free(mSoundBuffer[0].data);
    free(mSoundBuffer[1].data);
    
    CFRelease(sourceURL[0]);
    CFRelease(sourceURL[1]);
}

@end
