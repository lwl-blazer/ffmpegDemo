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

@property(nonatomic, assign) AUNode mixerNode;
@property(nonatomic, assign) AudioUnit mixerUnit;

@property(nonatomic, assign) AUNode convertNode;
@property(nonatomic, assign) AudioUnit convertUnit;

@property(nonatomic, assign) Float64 sampleRate;

@end


@implementation AudioUnitInput
{
    NSString *_destinationFilePath;
    ExtAudioFileRef finalAudioFile;
}

- (instancetype)initWithAccompanyPath:(NSString *)path{
    self = [super init];
    if (self) {
        _sampleRate = 44100.0;
        _destinationFilePath = path;
        
        NSLog(@"%@", path);
        [[BLAudioSession sharedInstance] setCategory:AVAudioSessionCategoryPlayAndRecord];
        [[BLAudioSession sharedInstance] setPerferredSampleRate:_sampleRate];
        [[BLAudioSession sharedInstance] setActive:YES];
        [[BLAudioSession sharedInstance] addRouteChangeListener];
        
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
    CheckStatus(status, @"Could not retrieve nod info mixer node", YES);
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
    
    UInt32 mixerElementCount = 1;
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
    
    UInt32 maximumFramesPerSlice = 4096;
    AudioUnitSetProperty(_ioUnit,
                         kAudioUnitProperty_MaximumFramesPerSlice,
                         kAudioUnitScope_Global,
                         0,
                         &maximumFramesPerSlice,
                         sizeof(maximumFramesPerSlice));
    
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
    
    result = ExtAudioFileWriteAsync(recorder->finalAudioFile,
                                    inNumberFrames,
                                    ioData);
    
    return result;
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
    
    AURenderCallbackStruct finalRenderCallback;
    finalRenderCallback.inputProc = &renderCallback;
    finalRenderCallback.inputProcRefCon = (__bridge void *)self;
    
    status = AUGraphSetNodeInputCallback(_auGraph,
                                         _ioNode,
                                         0,
                                         &finalRenderCallback);
    CheckStatus(status, @"Could not set InputCallback For IONode", YES);
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
    [self prepareFinalWriteFile];
    OSStatus status = AUGraphStart(_auGraph);
    CheckStatus(status, @"Could not start AUGraph", YES);
}

- (void)stop{
    OSStatus status = AUGraphStop(_auGraph);
    CheckStatus(status, @"Could not stop AUGraph", YES);
    
    ExtAudioFileDispose(finalAudioFile);
}


@end
