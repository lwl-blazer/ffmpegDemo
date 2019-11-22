//
//  AudioInput.m
//  RecordVideo
//
//  Created by luowailin on 2019/11/14.
//  Copyright © 2019 luowailin. All rights reserved.
//

#import "AudioUnitInput.h"
#import "BLAudioSession.h"
#import <AudioToolbox/AudioToolbox.h>
#import <AVFoundation/AVFoundation.h>
#include "BlockingQueue.hpp"

static void CheckStatus(OSStatus status, NSString *message, BOOL fatal) {
    if (status != noErr) {
        char fourCC[16];
        *(UInt32 *)fourCC = CFSwapInt32HostToBig(status);
        fourCC[4] = '\0';
        
        if (isprint(fourCC[0]) && isprint(fourCC[1]) && isprint(fourCC[2]) && isprint(fourCC[3])) {
            NSLog(@"%@:%s", message, fourCC);
        } else {
            NSLog(@"%@:%d", message, (int)status);
        }
        
        if (fatal) {
            exit(-1);
        }
    }
}

static const AudioUnitElement inputElement = 1;

@interface AudioUnitInput ()

@property(nonatomic, assign) AUGraph auGraph;
@property(nonatomic, assign) AUNode ioNode;
@property(nonatomic, assign) AudioUnit ioUnit;

@property(nonatomic, assign) AUNode mPlayerNode;
@property(nonatomic, assign) AudioUnit mPlayerUnit;

@property(nonatomic, assign) AUNode mixerNode;
@property(nonatomic, assign) AudioUnit mixerUnit;

@property(nonatomic, assign) AUNode convertNode;
@property(nonatomic, assign) AudioUnit convertUnit;

@property(nonatomic, assign) AUNode c32fTo16iNode;
@property(nonatomic, assign) AudioUnit c32fTo16iUnit;
@property(nonatomic, assign) AUNode c16iTo32fNode;
@property(nonatomic, assign) AudioUnit c16iTo32fUnit;

@property(nonatomic, assign) Float64 sampleRate;

@end


@implementation AudioUnitInput
{
    NSString *_destinationFilePath;
    ExtAudioFileRef finalAudioFile;
    BlockingQueue *packetPool;
}

- (instancetype)initWithpath:(NSString *)path accompanyPath:(NSString *)accompanyPath{
    self = [super init];
    if (self) {
        _sampleRate = 44100.0;
        _destinationFilePath = path;
        
        NSLog(@"%@", path);
        [[BLAudioSession sharedInstance] setCategory:AVAudioSessionCategoryPlayAndRecord];
        [[BLAudioSession sharedInstance] setPerferredSampleRate:_sampleRate];
        [[BLAudioSession sharedInstance] setActive:YES];
        [[BLAudioSession sharedInstance] addRouteChangeListener];
        
        packetPool = new BlockingQueue();
        
        [self addAudioSessionInterruptedObserver];
        [self createAudioUnitGraph];
        [self prepareWriteAccompanyFile:accompanyPath];
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
    CheckStatus(status, @"Create convert node faile", YES);
    
    AudioComponentDescription mixerDescription;
    bzero(&mixerDescription, sizeof(mixerDescription));
    mixerDescription.componentType = kAudioUnitType_Mixer;
    mixerDescription.componentSubType = kAudioUnitSubType_MultiChannelMixer;
    mixerDescription.componentManufacturer = kAudioUnitManufacturer_Apple;
    status = AUGraphAddNode(_auGraph,
                            &mixerDescription,
                            &_mixerNode);
    CheckStatus(status, @"Create mixer node faile", YES);
    
    AudioComponentDescription playerDescription;
    bzero(&playerDescription, sizeof(playerDescription));
    playerDescription.componentManufacturer = kAudioUnitManufacturer_Apple;
    playerDescription.componentType = kAudioUnitType_Generator;
    playerDescription.componentSubType = kAudioUnitSubType_AudioFilePlayer;
    status = AUGraphAddNode(_auGraph,
                   &playerDescription,
                   &_mPlayerNode);
    CheckStatus(status, @"Create file Player node faile", YES);
    
    AudioComponentDescription convert2Description;
    bzero(&convertDescription, sizeof(convert2Description));
    convert2Description.componentManufacturer = kAudioUnitManufacturer_Apple;
    convert2Description.componentType = kAudioUnitType_FormatConverter;
    convert2Description.componentSubType = kAudioUnitSubType_AUConverter;
    status = AUGraphAddNode(_auGraph,
                   &convert2Description,
                   &_c32fTo16iNode);
    CheckStatus(status, @"create c32to16 convert node faile", YES);
    
    
    AudioComponentDescription convert3Description;
    bzero(&convert3Description, sizeof(convert3Description));
    convert3Description.componentManufacturer = kAudioUnitManufacturer_Apple;
    convert3Description.componentType = kAudioUnitType_FormatConverter;
    convert3Description.componentSubType = kAudioUnitSubType_AUConverter;
    status = AUGraphAddNode(_auGraph,
                            &convert3Description,
                            &_c16iTo32fNode);
    CheckStatus(status, @"create c16To32 convert node faile", YES);
    
}

- (void)getUnitsFromNodes{
    OSStatus status = noErr;
    status = AUGraphNodeInfo(_auGraph,
                             _ioNode,
                             NULL,
                             &_ioUnit);
    CheckStatus(status, @"could not retrieve node info I/O node", YES);
    
    status = AUGraphNodeInfo(_auGraph,
                             _convertNode,
                             NULL,
                             &_convertUnit);
    CheckStatus(status, @"Could not retrieve node info convert node", YES);
    
    status = AUGraphNodeInfo(_auGraph,
                             _mixerNode,
                             NULL,
                             &_mixerUnit);
    CheckStatus(status, @"Could not retrieve node info mixer node", YES);
    
    status = AUGraphNodeInfo(_auGraph,
                             _mPlayerNode,
                             NULL,
                             &_mPlayerUnit);
    CheckStatus(status, @"Could not retrieve node info file player node", YES);
    
    
    status = AUGraphNodeInfo(_auGraph,
                             _c32fTo16iNode,
                             NULL,
                             &_c32fTo16iUnit);
    CheckStatus(status, @"Could not retrieve node info c32to16 convert node", YES);
    
    
    status = AUGraphNodeInfo(_auGraph,
                             _c16iTo32fNode,
                             NULL,
                             &_c16iTo32fUnit);
    CheckStatus(status, @"Could not retrieve node info c16to32 convert node ", YES);
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
    
    CheckStatus(status, @"could not set stream format on I/O unit output scope", YES);
    
    UInt32 enableIO = 1;
    status = AudioUnitSetProperty(_ioUnit,
                                  kAudioOutputUnitProperty_EnableIO,
                                  kAudioUnitScope_Input,
                                  inputElement,
                                  &enableIO,
                                  sizeof(enableIO));
    CheckStatus( status, @"Could not enable I/O on I/O unit input scope", YES);
    
    UInt32 mixerElementCount = 2;
    status = AudioUnitSetProperty(_mixerUnit,
                                  kAudioUnitProperty_ElementCount,
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
    
    //设置AudioUnitRender()函数在处理输入数据时，最大的输入吞吐量
    UInt32 maximumFramesPerSlice = 4096;
    AudioUnitSetProperty(_ioUnit,
                         kAudioUnitProperty_MaximumFramesPerSlice,
                         kAudioUnitScope_Global,
                         0,
                         &maximumFramesPerSlice,
                         sizeof(maximumFramesPerSlice));
    
    /**设置各路混合后的音量*/
    AudioUnitSetParameter(_mixerUnit,
                          kMultiChannelMixerParam_Volume,
                          kAudioUnitScope_Input,
                          0,
                          0.5,
                          0);
    AudioUnitSetParameter(_mixerUnit,
                          kMultiChannelMixerParam_Volume,
                          kAudioUnitScope_Input,
                          1,
                          1.0,
                          0);

    //设置Float32转SInt16
    UInt32 bytesPerSample1 = sizeof(Float32);
    AudioStreamBasicDescription c16iFmt;
    bzero(&c16iFmt, sizeof(c16iFmt));
    
    c16iFmt.mSampleRate = _sampleRate;
    c16iFmt.mFormatID = kAudioFormatLinearPCM;
    c16iFmt.mFormatFlags = kAudioFormatFlagIsSignedInteger | kAudioFormatFlagsNativeEndian | kAudioFormatFlagIsPacked | kAudioFormatFlagIsNonInterleaved;
    c16iFmt.mBitsPerChannel = 8 * bytesPerSample1;
    c16iFmt.mBytesPerFrame = bytesPerSample1;
    c16iFmt.mBytesPerPacket = bytesPerSample1;
    c16iFmt.mFramesPerPacket = 1;
    c16iFmt.mChannelsPerFrame = 2;
    AudioUnitSetProperty(_c32fTo16iUnit,
                         kAudioUnitProperty_StreamFormat,
                         kAudioUnitScope_Output,
                         0,
                         &c16iFmt,
                         sizeof(c16iFmt));
    AudioUnitSetProperty(_c16iTo32fUnit,
                         kAudioUnitProperty_StreamFormat,
                         kAudioUnitScope_Input,
                         0,
                         &c16iFmt,
                         sizeof(c16iFmt));
    
    
    UInt32 bytesPerSample2 = sizeof(SInt16);
    AudioStreamBasicDescription c32fFmt;
    c32fFmt.mSampleRate = _sampleRate;
    c32fFmt.mFormatID = kAudioFormatLinearPCM;
    
    c32fFmt.mFormatFlags = kAudioFormatFlagIsSignedInteger | kAudioFormatFlagsNativeEndian | kAudioFormatFlagIsPacked | kAudioFormatFlagIsNonInterleaved;
    c32fFmt.mBitsPerChannel = 8 * bytesPerSample2;
    c32fFmt.mBytesPerFrame = bytesPerSample2;
    c32fFmt.mBytesPerPacket = bytesPerSample2;
    c32fFmt.mFramesPerPacket = 1;
    c32fFmt.mChannelsPerFrame = 2;
    AudioUnitSetProperty(_c32fTo16iUnit,
                         kAudioUnitProperty_StreamFormat,
                         kAudioUnitScope_Input,
                         0,
                         &c32fFmt,
                         sizeof(c32fFmt));
    
    AudioUnitSetProperty(_c16iTo32fUnit,
                         kAudioUnitProperty_StreamFormat,
                         kAudioUnitScope_Output,
                         0,
                         &c32fFmt,
                         sizeof(c32fFmt));
    
    //ASBD
    UInt32 bytesPerSample = sizeof(SInt32);
    AudioStreamBasicDescription _clientFormat32float;
    _clientFormat32float.mFormatID = kAudioFormatLinearPCM;
    
    _clientFormat32float.mFormatFlags = kAudioFormatFlagsNativeFloatPacked | kAudioFormatFlagIsNonInterleaved;
    _clientFormat32float.mBytesPerPacket = bytesPerSample;
    _clientFormat32float.mFramesPerPacket= 1;
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
    
    AudioUnitSetProperty(_mPlayerUnit,
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
                               UInt32 inNumberFrames,
                               AudioBufferList *ioData) {
    OSStatus result = noErr;
    __unsafe_unretained AudioUnitInput *recorder = (__bridge AudioUnitInput *)inRefCon;
    
    AudioUnitRender(recorder->_mixerUnit,
                    ioActionFlags,
                    inTimeStamp,
                    0,
                    inNumberFrames,
                    ioData);
    

    //写文件操作
    result = ExtAudioFileWriteAsync(recorder->finalAudioFile,
                                    inNumberFrames,
                                    ioData);
    
    return result;
}

//在这个里面拿到数据就是SInt16格式 把数据封装成AudioPacket并放入到音频队列中
static OSStatus mixerRenderNotify(void *inRefCon,
                                  AudioUnitRenderActionFlags *ioActionFlags,
                                  const AudioTimeStamp *inTimeStamp,
                                  UInt32 inBusNumber,
                                  UInt32 inNumberFrames,
                                  AudioBufferList * __nullable ioData){
    OSStatus status = noErr;
    AudioUnitInput *recorder = (__bridge AudioUnitInput *)inRefCon;
    AudioUnitRender(recorder->_mixerUnit,
                    ioActionFlags,
                    inTimeStamp,
                    0,
                    inNumberFrames,
                    ioData);
    
    /*
    
    
    
    
    AudioBuffer buffer = ioData->mBuffers[0];
    int sampleCount = buffer.mDataByteSize/2;
    short *packetBuffer = new short[sampleCount];
    memcpy(packetBuffer, buffer.mData, buffer.mDataByteSize);
    
    AudioPacket *audioPacket = new AudioPacket();
    audioPacket->buffer = packetBuffer;
    audioPacket->size = buffer.mDataByteSize / 2;
    input->packetPool->put(audioPacket);*/
    return status;
} 

- (AudioStreamBasicDescription )noninterleavedPCMFormatWithChannels:(UInt32)channels{
    UInt32 bytesPerSample = sizeof(SInt32);
    
    AudioStreamBasicDescription asbd;
    bzero(&asbd, sizeof(asbd));
    
    asbd.mSampleRate = _sampleRate;
    asbd.mFormatID = kAudioFormatLinearPCM;
    
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
    
    status = AUGraphConnectNodeInput(_auGraph,
                                     _mPlayerNode,
                                     0,
                                     _mixerNode,
                                     1);
    CheckStatus(status, @"Could not connect file node input to mixer node input", YES);
    
    /*
    AURenderCallbackStruct finalRenderCallback;
    finalRenderCallback.inputProc = &renderCallback;
    finalRenderCallback.inputProcRefCon = (__bridge void *)self;
    
    status = AUGraphSetNodeInputCallback(_auGraph,
                                         _ioNode,
                                         0,
                                         &finalRenderCallback);
    CheckStatus(status, @"Could not set InputCallback For IONode", YES);
    */
    
//    status = AUGraphConnectNodeInput(_auGraph,
//                                     _mixerNode,
//                                     0,
//                                     _c32fTo16iNode,
//                                     1);
//    CheckStatus(status, @"could not set mixernode to c32fto16iNode", YES);
    
    status = AUGraphConnectNodeInput(_auGraph,
                                     _c32fTo16iNode,
                                     0,
                                     _c16iTo32fNode,
                                     0);
    CheckStatus(status, @"Could not set _c32fto16iNode", YES);
    
    status = AUGraphConnectNodeInput(_auGraph,
                                     _c16iTo32fNode,
                                     0,
                                     _ioNode,
                                     0);
    CheckStatus(status, @"could not set _c16iTo32fNode", YES);
    
    /**
     * RenderNotify 和 InputCallback 是不一样的
     * InputCallback是当下一级节点需要数据的时候将会调用的方法，让配置的这个方法来填充数据
     *
     * RenderNotify是不同的调用机制，RenderNotify是在这个节点从它的上一级节点获取到数据之后才会调用该函数，可以让开发者做一些额外的操作(比如音频处理或者编码文件等)
     */
    status = AudioUnitAddRenderNotify(_c32fTo16iUnit,
                             &mixerRenderNotify,
                             (__bridge void *)self);
    CheckStatus(status, @"Could not set _c32fto16iUnit renderNotify", YES);
}

//下面的代码一定是要在AUGraphInitialize之后设置，否则不生效
- (void)prepareWriteAccompanyFile:(NSString *)path{
    OSStatus status = noErr;
    //1.打开文件 并生成一个文件句柄AudioFileID
    AudioFileID musicFile;
    CFURLRef songURL = (__bridge CFURLRef)[NSURL URLWithString:path];
    status = AudioFileOpenURL(songURL,
                              kAudioFileReadPermission,
                              0, //表示文件的封装格式后缀，如果为0 表示自动检测
                              &musicFile);
    CheckStatus(status, @"open accompany file url faile", YES);
    
    //2.获取文件本身的数据格式(根据文件的信息头解析，未解压的，根据文件属性获取)
    AudioStreamBasicDescription fileASBD;
    UInt32 propSize = sizeof(fileASBD);
    status = AudioFileGetProperty(musicFile,
                                  kAudioFilePropertyDataFormat,
                                  &propSize,
                                  &fileASBD);
    CheckStatus(status, @"setup AUFilePlayer couldn't get file's data format", YES);
    
    //3.获取文件的音频packets数目
    /**遇到的问题:获取音频文件中packet数目时返回kAudioFileBadPropertySizeError错误
      解决方案:kAudioFilePropertyAudioDataPacketCount的必须是UInt64类型*/
    UInt64 nPackets;
    propSize = sizeof(nPackets);
    status = AudioFileGetProperty(musicFile,
                         kAudioFilePropertyAudioDataPacketCount,
                         &propSize,
                         &nPackets);
    CheckStatus(status, @"get AUFile packet count", YES);
    
    //4.指定要播放的文件句柄 要把该文件加入指定的AudioUnit中
    status = AudioUnitSetProperty(_mPlayerUnit,
                         kAudioUnitProperty_ScheduledFileIDs,
                         kAudioUnitScope_Global,
                         0,
                         &musicFile,
                         sizeof(musicFile));
    CheckStatus(status, @"set up scheduled file ids", YES);
    
    //Scheduled Audio File Region 是对于AudioFile进行访问计划的区域，其实该结构就是用来控制AudioFilePlayer的
    //5.指定从音频中读取数据的方式   （这里是指定要播放的范围比如是播放整个文件还是播放部分文件） 播放方式等
    ScheduledAudioFileRegion rgn;
    memset(&rgn.mTimeStamp, 0, sizeof(rgn.mTimeStamp));
    rgn.mTimeStamp.mFlags = kAudioTimeStampSampleTimeValid; //播放整个文件必须设置此值
    rgn.mTimeStamp.mSampleTime = 0;   //播放整个文件必须设置此值
    rgn.mCompletionProc = NULL;     //数据读取完毕之后的回调函数
    rgn.mCompletionProcUserData = NULL; //传给回调函数的对象
    rgn.mAudioFile = musicFile;  //要读取的文件句柄
    rgn.mLoopCount = -1 ; //是否循环播放  0不循环 -1 一直循环   其它值循环的次数
    rgn.mStartFrame = 0; //读取f的起始的frame索引
    //mStartTime  用来设置开始播放的时间，拖动(Seek)操作就是通过这个参数来设置的
    rgn.mFramesToPlay = (UInt32)nPackets * fileASBD.mFramesPerPacket; //从读取的起始frame 索引开始，总共要读取的frames数目
    
    //必须要调用完AUGraphInitialize 否则报错-10867
    status = AudioUnitSetProperty(_mPlayerUnit,
                                  kAudioUnitProperty_ScheduledFileRegion,
                                  kAudioUnitScope_Global,
                                  0,
                                  &rgn,
                                  sizeof(rgn));
    CheckStatus(status, @"set audio file play fileRegion", YES);
    
    //指定从音频文件中读取音频数据的行为，必须读取指定的frames数(也就是defaultVal设置的值，如果为0表示采用系统默认的值)才返回，否则就等待
    //这一步一定要在上一步之后设定
    UInt32 defaultVal = 0;
   status = AudioUnitSetProperty(_mPlayerUnit,
                         kAudioUnitProperty_ScheduledFilePrime,
                         kAudioUnitScope_Global,
                         0,
                         &defaultVal,
                         sizeof(defaultVal));
    CheckStatus(status, @"kAudioUnitProperty_ScheduledFilePrime faile", YES);
    
    
    AudioTimeStamp startTime;
    memset(&startTime,
           0, sizeof(startTime));
    startTime.mFlags = kAudioTimeStampSampleTimeValid; //要想mSampleTime有效，要这样设定
    startTime.mSampleTime = -1; //表示means next render cycle 否则按这个指定的数值
    status = AudioUnitSetProperty(_mPlayerUnit,
                                  kAudioUnitProperty_ScheduleStartTimeStamp,
                                  kAudioUnitScope_Global,
                                  0,
                                  &startTime,
                                  sizeof(startTime));
    CheckStatus(status, @"kAudioUnitProperty_ScheduleStartTimeStamp ", YES);
    
    //在播放的过程中，可以通过获取kAudioUnitProperty_CurrentPlayTime来得到相对于所设置的开始时间的播放时长，从而计算出当前播放到的位置
}

- (void)prepareFinalWriteFile{
    AudioStreamBasicDescription destinationFormat;
    memset(&destinationFormat,
           0,
           sizeof(destinationFormat));
    
    destinationFormat.mFormatID = kAudioFormatLinearPCM;
    destinationFormat.mSampleRate = _sampleRate;
    destinationFormat.mFormatFlags = kLinearPCMFormatFlagIsSignedInteger | kLinearPCMFormatFlagIsPacked;
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
        printf("AudioFormatGetProperty %d\n", (int)result);
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
    memset(&clientFormat,
           0, sizeof(clientFormat));
    
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
                @"ExtAudioFileSetProperty faile", YES);
    
    UInt32 codec = kAppleHardwareAudioCodecManufacturer;
    CheckStatus(ExtAudioFileSetProperty(finalAudioFile,
                                        kExtAudioFileProperty_CodecManufacturer,
                                        sizeof(codec),
                                        &codec),
                @"ExtAudioFileSetProperty on extAudioFile failed", YES);
    
    
    CheckStatus(ExtAudioFileWriteAsync(finalAudioFile,
                                       0,
                                       NULL),
                @"ExtAudioFileWriteAsync Failed", YES);
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
   NSString *info = [[sender userInfo] objectForKey:AVAudioSessionInterruptionTypeKey];
    AVAudioSessionInterruptionType interruption;
//    switch (interruption) {
//        case AVAudioSessionInterruptionTypeBegan:
//            [self stop];
//            break;
//        case AVAudioSessionInterruptionTypeEnded:
//            [self start];
//            break;
//        default:
//            break;
//    }
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

- (void)dealloc{
    [self destoryAudioUnitGraph];
}

#pragma mark -- public method

- (void)start{
    //[self prepareFinalWriteFile];
    OSStatus status = AUGraphStart(_auGraph);
    CheckStatus(status, @"Could not start AUGraph", YES);
}

- (void)stop{
    OSStatus status = AUGraphStop(_auGraph);
    CheckStatus(status, @"Could not stop AUGraph", YES);
    
    ExtAudioFileDispose(finalAudioFile);
}


@end
