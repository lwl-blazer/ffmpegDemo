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

static OSStatus renderInput(void *inRefCon,
                            AudioUnitRenderActionFlags *ioActionFlags,
                            const AudioTimeStamp *inTimeStamp,
                            UInt32 inBusNumber,
                            UInt32 inNumberFrames,
                            AudioBufferList *ioData){
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
    
    result = AudioUnitSetProperty(_mMixer,
                                  kAudioUnitProperty_StreamFormat,
                                  kAudioUnitScope_Output,
                                  1,
                                  self.mAudioFormat.streamDescription,
                                  sizeof(AudioStreamBasicDescription));
    CheckStatus(result, @"AudioUnitSetProperty_bus1_kAudioUnitProperty_StreamFormat", YES);
}

- (void)makeNodeConnections{
    OSStatus result = noErr;
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

#pragma mark -- public method
- (instancetype)initWithPath1:(NSString *)path1
                        path2:(NSString *)path2{
    self = [super init];
    if (self) {
        memset(&mSoundBuffer, 0, sizeof(mSoundBuffer));
        
        sourceURL[0] = CFURLCreateWithFileSystemPath(kCFAllocatorNull,
                                                     (CFStringRef)path1,
                                                     kCFURLPOSIXPathStyle,
                                                     false);
        sourceURL[1] = CFURLCreateWithFileSystemPath(kCFAllocatorNull,
                                                     (CFStringRef)path2,
                                                     kCFURLPOSIXPathStyle,
                                                     false);
        
        self.isPlaying = NO;
        
        _sampleRate = 44100.0;
        [[ELAudioSession sharedInstance] setCategory:AVAudioSessionCategoryPlayback];
        [[ELAudioSession sharedInstance] setPreferredLatency:0.0005];
        [[ELAudioSession sharedInstance] setPreferredSampleRate:_sampleRate];
        [[ELAudioSession sharedInstance] setActive:YES];
        [[ELAudioSession sharedInstance] addRouteChangeListener];
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

- (void)dealloc{
    free(mSoundBuffer[0].data);
    free(mSoundBuffer[1].data);
    
    CFRelease(sourceURL[0]);
    CFRelease(sourceURL[1]);
}

@end
