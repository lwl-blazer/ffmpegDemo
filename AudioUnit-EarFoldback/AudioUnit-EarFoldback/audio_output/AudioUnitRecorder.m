//
//  AudioUnitRecorder.m
//  AudioUnit-EarFoldback
//
//  Created by luowailin on 2019/10/17.
//  Copyright © 2019 luowailin. All rights reserved.
//
/** Setup AudioSession
 * 1:Category
 * 2:Set Listener
 *    Interrupt Listener
 *    AudioRoute Change Listener
 *    Hardwate output Volume Listener
 * 4:Set IO BufferDuration
 * 5:Active AudioSession
 *
 * Setup AudioUnit
 * 1:Build AudioComponentDescription To Build AudioUnit Instance
 * 2:Build AudioStreamBasicDescription To Set AudioUnit Property
 * 3:Connect Node Or Set RenderCallback For AudioUnit
 * 4:Initialize AudioUnit
 * 5:Initialize AudioUnit
 * 6:AudioOutputUnitStart
 *
 */
#import "AudioUnitRecorder.h"
#import "ELAudioSession.h"

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


static const AudioUnitElement inputElement = 1;
@interface AudioUnitRecorder ()

@property(nonatomic, assign) AUGraph auGraph;
@property(nonatomic, assign) AUNode ioNode;
@property(nonatomic, assign) AudioUnit ioUnit;

@property(nonatomic, assign) AUNode mixerNode;
@property(nonatomic, assign) AudioUnit mixerUnit;

@property(nonatomic, assign) AUNode convertNode;
@property(nonatomic, assign) AudioUnit convertUnit;

@property(nonatomic, assign) Float64 sampleRate;

@end


@implementation AudioUnitRecorder
{
    NSString *_destinationFilePath;
    ExtAudioFileRef finalAudioFile;
}

- (instancetype)initWithPath:(NSString *)path{
    self = [super init];
    if (self) {
        _sampleRate = 44100.0;
        _destinationFilePath = path;
        
        NSLog(@"%@", path);
        [[ELAudioSession sharedInstance] setCategory:AVAudioSessionCategoryPlayAndRecord];
        [[ELAudioSession sharedInstance] setPreferredSampleRate:_sampleRate];
        [[ELAudioSession sharedInstance] setActive:YES];
        [[ELAudioSession sharedInstance] addRouteChangeListener];
        [self addAudioSessionInterruptedObserver];
        [self createAudioUnitGraph];
    }
    return self;
}

- (void)createAudioUnitGraph{
    OSStatus status = NewAUGraph(&_auGraph);
    CheckStatus(status, @"create a new AUGraph faile", YES);
    
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
    //bzero(void *s, int n) 将内存块(字符串)的前n个字节清零
    bzero(&ioDescription, sizeof(ioDescription));
    ioDescription.componentType = kAudioUnitType_Output;
    ioDescription.componentSubType = kAudioUnitSubType_RemoteIO;
    ioDescription.componentManufacturer = kAudioUnitManufacturer_Apple;
    status = AUGraphAddNode(_auGraph,
                            &ioDescription,
                            &_ioNode);
    CheckStatus(status, @"create io node faile", YES);
    
    AudioComponentDescription convertDescription;
    bzero(&convertDescription, sizeof(convertDescription));
    convertDescription.componentType = kAudioUnitType_FormatConverter;
    convertDescription.componentSubType = kAudioUnitSubType_AUConverter;
    convertDescription.componentManufacturer = kAudioUnitManufacturer_Apple;
    status = AUGraphAddNode(_auGraph,
                            &convertDescription,
                            &_convertNode);
    CheckStatus(status, @"create convert node faile", YES);
    
    /** kAudioUnitType_Mixer 主要提供Mix多路声音的功能。
     * 其子类型及用途如下:
     *  3D Mixer:  无法在移动设备上使用
     *
     * multiChannelMixer: kAudioUnitSubType_MultiChannelMixer 它是多路声音混音的效果器，可以接收多路音频的输入，还可以分别调整每一路音频的增益与开关，并将多路音频合并成一路，该效果器在处理音频的图状结构中非常有用
     *
     * 对于这个类型可以有多个输入，但是只有一个输出
     *
     * 属性有哪些:
     * kAudioUnitProperty_ElementCount给Mixer设置多个输入源
     * 还可以给每个输入源设置格式
     * kAudioUnitProperty_SampleRate 设置sampleRate
     *
     * 参考管方混音例子:https://developer.apple.com/library/archive/samplecode/iOSMultichannelMixerTest/Introduction/Intro.html
     *
     */
    AudioComponentDescription mixerDescription;
    bzero(&mixerDescription, sizeof(mixerDescription));
    mixerDescription.componentType = kAudioUnitType_Mixer;
    mixerDescription.componentSubType = kAudioUnitSubType_MultiChannelMixer;
    mixerDescription.componentManufacturer = kAudioUnitManufacturer_Apple;
    status = AUGraphAddNode(_auGraph,
                            &mixerDescription,
                            &_mixerNode);
    CheckStatus(status, @"create mixer node faile", YES);
}

//获取Audio Unit 从 AUNode中
- (void)getUnitsFromNodes{
    OSStatus status = noErr;
    status = AUGraphNodeInfo(_auGraph, _ioNode,
                             NULL,
                             &_ioUnit);
    CheckStatus(status, @"could not retrieve node info I/O node", YES);
    
    status = AUGraphNodeInfo(_auGraph,
                             _convertNode,
                             NULL,
                             &_convertUnit);
    CheckStatus(status, @"could not retrieve node info Convert Node", YES);
    
    status = AUGraphNodeInfo(_auGraph,
                             _mixerNode,
                             NULL,
                             &_mixerUnit);
    CheckStatus(status, @"could not retrieve node info Mixer Node", YES);
}

- (void)setAudioUnitProperties{
    OSStatus status = noErr;
    AudioStreamBasicDescription stereoStreamFormat = [self noninterleavedPCMFormatWithChannels:2];
    status = AudioUnitSetProperty(_ioUnit,
                                  kAudioUnitProperty_StreamFormat,
                                  kAudioUnitScope_Output,
                                  inputElement,
                                  &stereoStreamFormat,
                                  sizeof(stereoStreamFormat));
    CheckStatus(status, @"Could not set stream format on I/O unit output scope", YES);
    
    //这个就是启用麦克风
    UInt32 enableIO = 1;  //to enable input
    status = AudioUnitSetProperty(_ioUnit,
                                  kAudioOutputUnitProperty_EnableIO,    //kAudioOutputUnitProperty_EnableIO 启用或禁用
                                  kAudioUnitScope_Input,
                                  inputElement,
                                  &enableIO,
                                  sizeof(enableIO));
    CheckStatus(status, @"Could not enable I/O on I/O unit input scope", YES);
    
    /* 关掉输出
    UInt32 disableIO = 0; //to disable output
    AudioUnitElement outputElement = 0;
    status = AudioUnitSetProperty(_ioUnit,
                                  kAudioOutputUnitProperty_EnableIO,
                                  kAudioUnitScope_Output,
                                  outputElement,
                                  &disableIO,
                                  sizeof(disableIO));*/
    
    UInt32 mixerElementCount = 1;
    status = AudioUnitSetProperty(_mixerUnit,
                                  kAudioUnitProperty_ElementCount,  //kAudioUnitProperty_ElementCount
                                  kAudioUnitScope_Input,
                                  0,
                                  &mixerElementCount,
                                  sizeof(mixerElementCount));
    CheckStatus(status, @"Could not set element count on mixer unit input scope", YES);
    
    status = AudioUnitSetProperty(_mixerUnit,
                                  kAudioUnitProperty_SampleRate,
                                  kAudioUnitScope_Output,
                                  0,
                                  &_sampleRate,
                                  sizeof(_sampleRate));
    CheckStatus(status, @"Could not set sample rate on mixer unit output scope", YES);
    
    UInt32 maximumFramesPerSlice = 4096;
    AudioUnitSetProperty(_ioUnit,
                         kAudioUnitProperty_MaximumFramesPerSlice,    // kAudioUnitProperty_MaximumFramesPerSlice 每片最大的帧数  在调用AudioUnitRender回调的时候需要准备的大小, 官方文档建议设置成4096
                         kAudioUnitScope_Global,   //global scope 整应用于Audio Unit并且不会与特定音频流相关联。它只有一个element， 只适合于个别属性
                         0,
                         &maximumFramesPerSlice,
                         sizeof(maximumFramesPerSlice));
    
    
    /** AudioStreamBasicDescription(ASBD)
     * 音频值在您的应用程序以及你的应用程序和音频硬件之间移动的流是 AudioStreamBasicDescription
     */
    UInt32 bytesPerSample = sizeof(SInt32);
//    UInt32 bytesPerSample = sizeof(AudioUnitSampleType);
    AudioStreamBasicDescription _clientFormat32float; //设置ASBD
    _clientFormat32float.mFormatID = kAudioFormatLinearPCM;
    
    
    _clientFormat32float.mFormatFlags = kAudioFormatFlagsNativeFloatPacked | kAudioFormatFlagIsNonInterleaved;
    _clientFormat32float.mBytesPerPacket = bytesPerSample;
    _clientFormat32float.mFramesPerPacket = 1;
    _clientFormat32float.mBytesPerFrame = bytesPerSample;
    _clientFormat32float.mChannelsPerFrame = 2;
    _clientFormat32float.mBitsPerChannel = 8 * bytesPerSample;
    _clientFormat32float.mSampleRate = _sampleRate;
    
    AudioUnitSetProperty(_mixerUnit,
                         kAudioUnitProperty_StreamFormat,
                         kAudioUnitScope_Input,
                         0,
                         &_clientFormat32float,
                         sizeof(_clientFormat32float));
    AudioUnitSetProperty(_ioUnit,
                         kAudioUnitProperty_StreamFormat,
                         kAudioUnitScope_Input,
                         0,
                         &_clientFormat32float,
                         sizeof(_clientFormat32float));
    AudioUnitSetProperty(_convertUnit,
                         kAudioUnitProperty_StreamFormat,
                         kAudioUnitScope_Input,
                         0,
                         &_clientFormat32float,
                         sizeof(_clientFormat32float));
    AudioUnitSetProperty(_convertUnit,
                         kAudioUnitProperty_StreamFormat,
                         kAudioUnitScope_Output,
                         0,
                         &_clientFormat32float,
                         sizeof(_clientFormat32float));
}

static OSStatus renderCallback(void *inRefCon,
                               AudioUnitRenderActionFlags *ioActionFlags,
                               const AudioTimeStamp *inTimeStamp,
                               UInt32 inBusNumber,
                               UInt32 inNuberFrames,
                               AudioBufferList *ioData){
    OSStatus result = noErr;
    __unsafe_unretained AudioUnitRecorder *recorder = (__bridge AudioUnitRecorder *)inRefCon;
    
    //去Mixer Unit里面要数据，通过调用AudioUnitRender的方式来驱动Mixer Unit获取数据，得到数据之后放入ioData中,从而填充回调方法的中的参数
    AudioUnitRender(recorder->_mixerUnit,
                    ioActionFlags,
                    inTimeStamp,
                    0,
                    inNuberFrames,
                    ioData);
    
    //利用ExtAudioFile将这段声音编码并写入本地磁盘的一个文件中
    result = ExtAudioFileWriteAsync(recorder->finalAudioFile,
                                    inNuberFrames,
                                    ioData);
    return result;
}

- (AudioStreamBasicDescription )noninterleavedPCMFormatWithChannels:(UInt32)channels{
    
    UInt32 bytesPerSample = sizeof(SInt32);
    //UInt32 bytesPerSample = sizeof(AudioUnitSampleType);
    
    AudioStreamBasicDescription asbd;
    bzero(&asbd, sizeof(asbd));
    
    asbd.mSampleRate = _sampleRate;
    asbd.mFormatID = kAudioFormatLinearPCM;
    
    //asbd.mFormatFlags = kAudioFormatFlagsAudioUnitCanonical | kAudioFormatFlagIsNonInterleaved; 等于下面的一句
    asbd.mFormatFlags = kAudioFormatFlagIsSignedInteger | kAudioFormatFlagsNativeEndian | kAudioFormatFlagIsPacked | kAudioFormatFlagIsNonInterleaved;
    asbd.mBitsPerChannel = 8 * bytesPerSample;
    asbd.mBytesPerFrame = bytesPerSample;
    asbd.mBytesPerPacket = bytesPerSample;
    asbd.mFramesPerPacket = 1;
    asbd.mChannelsPerFrame = channels;
    return asbd;
}

- (void)makeNodeConnections{
    OSStatus status = noErr;
    status = AUGraphConnectNodeInput(_auGraph,
                                     _ioNode,
                                     1,
                                     _convertNode,
                                     0);
    CheckStatus(status, @"Could not connect I/O node input to convert node input", YES);
    
    status = AUGraphConnectNodeInput(_auGraph,
                                     _convertNode,
                                     0,
                                     _mixerNode,
                                     0);
    CheckStatus(status, @"Could not connect I/O node input to mixer node input", YES);
    
    AURenderCallbackStruct finalRenderCallback;
    finalRenderCallback.inputProc = &renderCallback;
    finalRenderCallback.inputProcRefCon = (__bridge void *)self;
    //AUGraphSetNodeInputCallback 连接Audio Unit Input Bus的回调函数
    status = AUGraphSetNodeInputCallback(_auGraph,
                                         _ioNode,
                                         0,
                                         &finalRenderCallback);
    CheckStatus(status, @"Could not set InputCallback For IONode", YES);
}



- (void)prepareFinalWriteFile{
    AudioStreamBasicDescription destinationFormat;
    memset(&destinationFormat, 0, sizeof(destinationFormat));
    
    destinationFormat.mFormatID = kAudioFormatLinearPCM;
    destinationFormat.mSampleRate = _sampleRate;
    destinationFormat.mFormatFlags = kLinearPCMFormatFlagIsSignedInteger|kLinearPCMFormatFlagIsPacked;
    destinationFormat.mBitsPerChannel = 16;
    destinationFormat.mChannelsPerFrame = 2;
    destinationFormat.mBytesPerPacket = (destinationFormat.mBitsPerChannel / 8) * destinationFormat.mChannelsPerFrame;
    destinationFormat.mBytesPerFrame = destinationFormat.mBytesPerPacket;
    destinationFormat.mFramesPerPacket = 1;
    
    UInt32 size = sizeof(destinationFormat);
    OSStatus result = AudioFormatGetProperty(kAudioFormatProperty_FormatInfo,
                                             0,
                                             NULL,
                                             &size,
                                             &destinationFormat);
    if (result) {
        printf("AudioFormatGetProperty %d \n", (int)result);
    }
    
    CFURLRef destinationURL = CFURLCreateWithFileSystemPath(kCFAllocatorDefault,
                                                            (CFStringRef)_destinationFilePath,
                                                            kCFURLPOSIXPathStyle,
                                                            false);
    result = ExtAudioFileCreateWithURL(destinationURL,
                                       kAudioFileCAFType,
                                       &destinationFormat,
                                       NULL,
                                       kAudioFileFlags_EraseFile,
                                       &finalAudioFile);
    if (result) {
        printf("ExtAudioFileCreateWithURL %d \n", (int)result);
    }
    CFRelease(destinationURL);
 
    AudioStreamBasicDescription clientFormat;
    UInt32 fSize = sizeof(clientFormat);
    memset(&clientFormat, 0, sizeof(clientFormat));
    
    CheckStatus(AudioUnitGetProperty(_mixerUnit,
                                     kAudioUnitProperty_StreamFormat,
                                     kAudioUnitScope_Output,
                                     0,
                                     &clientFormat,
                                     &fSize),
                @"AudioUnitGetProperty on failed", YES);
    
    CheckStatus(ExtAudioFileSetProperty(finalAudioFile,
                                        kExtAudioFileProperty_ClientDataFormat,
                                        sizeof(clientFormat),
                                        &clientFormat),
                @"ExtAudioFileSetProperty kExtAudioFileProperty_ClientDataFormat failed", YES);
    
    UInt32 codec = kAppleHardwareAudioCodecManufacturer;
    CheckStatus(ExtAudioFileSetProperty(finalAudioFile,
                                        kExtAudioFileProperty_CodecManufacturer,
                                        sizeof(codec),
                                        &codec),
                @"ExtAudioFileSetProperty on extAudioFile Faild",
                YES);
    
    CheckStatus(ExtAudioFileWriteAsync(finalAudioFile,
                                       0,
                                       NULL),
                @"ExtAudioFileWriteAsync Failed", YES);
    
}

- (void)destoryAudioUnitGraph{
    AUGraphStop(_auGraph);
    AUGraphUninitialize(_auGraph);
    AUGraphRemoveNode(_auGraph, _mixerNode);
    AUGraphRemoveNode(_auGraph, _ioNode);
    DisposeAUGraph(_auGraph);
    
    _ioUnit = NULL;
    _mixerUnit = NULL;
    _mixerNode = 0;
    _ioNode = 0;
    _auGraph = NULL;
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

- (void)removeAudioSessionInterruptedObserver{
    [[NSNotificationCenter defaultCenter] removeObserver:self
                                                    name:AVAudioSessionInterruptionNotification
                                                  object:nil];
 }

- (void)dealloc{
    [self destoryAudioUnitGraph];
}

#pragma mark -- public method
- (void)start{
    [self prepareFinalWriteFile];
    OSStatus status = AUGraphStart(_auGraph);
    CheckStatus(status, @"Could not start AUGraph", YES);
}

- (void)stop{
    OSStatus status = AUGraphStop( _auGraph);
    CheckStatus(status, @"Could not stop AUGraph", YES);
    ExtAudioFileDispose(finalAudioFile);
}

@end
