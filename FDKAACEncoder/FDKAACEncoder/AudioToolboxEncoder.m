//
//  AudioToolboxEncoder.m
//  FDKAACEncoder
//
//  Created by luowailin on 2019/10/25.
//  Copyright © 2019 luowailin. All rights reserved.
//

#import "AudioToolboxEncoder.h"
#import <AVFoundation/AVFoundation.h>
#import <AudioToolbox/AudioToolbox.h>

@interface AudioToolboxEncoder ()

@property(nonatomic, assign) AudioConverterRef audioConverter;
@property(nonatomic, assign) uint8_t *aacBuffer;
@property(nonatomic, assign) UInt32 aacBufferSize;
@property(nonatomic, assign) uint8_t *pcmBuffer;
@property(nonatomic, assign) size_t pcmBufferSize;

@property(nonatomic, assign) UInt32 channels;
@property(nonatomic, assign) NSInteger inputSampleRate;

@property(nonatomic, assign) BOOL isCompletion;
@property(nonatomic, assign) BOOL withADTSHeader;

@property(nonatomic, assign) int64_t presentationTimeMills;

@property(nonatomic, readwrite, weak) id<FillDataDelegate>fillAudioDataDelegate;

@end

@implementation AudioToolboxEncoder

- (instancetype)initWithSampleRate:(NSInteger)inputSampleRate
                          channels:(int)channels
                           bitRate:(int)bitRate
                    withADTSHeader:(BOOL)withADTSHeader
                 filleDataDelegate:(id<FillDataDelegate>)fillAudioDataDelegate{
    self = [super init];
    if (self) {
        _audioConverter = NULL;
        _inputSampleRate = inputSampleRate;
        _pcmBuffer = NULL;
        _pcmBufferSize = 0;
        _presentationTimeMills = 0;
        _isCompletion = NO;
        _aacBuffer = NULL;
        _aacBufferSize = 0;
        _channels = channels;
        _withADTSHeader = withADTSHeader;
        _fillAudioDataDelegate = fillAudioDataDelegate;
        
        [self setupEncoderWithSampleRate:inputSampleRate
                                channels:channels
                                 bitRate:bitRate];
        
        dispatch_queue_t encoderQueue = dispatch_queue_create("AAC Encoder Queue",
                                                              DISPATCH_QUEUE_SERIAL);
        dispatch_async(encoderQueue, ^{
            [self encoder];
        });
    }
    return self;
}

- (void)setupEncoderWithSampleRate:(NSInteger)inputSampleRate
                          channels:(int)channels
                           bitRate:(UInt32)bitRate{
    /**
     * AudioStreamBasicDescription (简称 ASBD) 音频流格式启用数据流
     * 音频值在您的应用程序以及您的应用程序和音频硬件之间移动的流是AudioStreamBasicDescription结构
     *
     * struct AudioStreamBasicDescription{
         Float64 mSampleRate;    //帧率
         UInt32 mFormatID;       //音频单元
         UInt32 mFormatFlags;   //音频单元标志集
         UInt32 mBytesPerPacket;
         UInt32 mFramePerPacket;
         UInt32 mBytesPerFrame;     //每帧的位数
         UInt32 mChannelsPerFrame;
         UInt32 mBitsPerChannel;    //音频样本的位数
         UInt32 mReserved;
       }
     *
     * AudioUnitSampleType 被定义为8.24定点整数
     *
     *  音频单元标志集: 对于大多数音频单元，mFormatFlags字段都指定kAudioFormatFlagsAudioUnitCanonical元标志
     *   kAudioFormatFlagsAudioUnitCanonical该标志的定义是:kAudioFormatFlagIsFloat | kAudioFormatFlagsNativeEndian | kAudioFormatFlagIsPacked | kAudioFormatFlagIsNonInterleaved   该元标记负责为类型为AudioUnitSampleType的线性PCM样本值中的bits指定所有布局细节
     *
     * 某些音频单元采用非典型音频数据格式，要求样本采用不同的数据类型，而mFormatFlags字段采用不同的标志集。exsample:3D混音器单元需要针对其音频采样值使用UInt16数据类型，并要求将ASBD的mFormatFlags字段设置为kAudioFormatFlagsCanonical.使用特定的音频设备时，请小心使用正确的数据格式和正确的格式标志 参阅：https://developer.apple.com/documentation/coreaudiotypes/1572096-audio_data_format_identifiers?language=objc
     *
     */
    
    //step 1: 确定数据类型以表示一个音频采样值  AudioUnitSampleType 是大多数音频单元的推荐数据类型
    UInt32 bytesPerSample = sizeof(SInt16);
    
    //step 2: 初始化
    AudioStreamBasicDescription inAudioStreamBasicDescription = {0};   //不要跳过这个步骤，不然有可能会造成不知道的问题
    
    //step 3: 音频单元   kAudioFormatLinearPCM 音频单元使用未压缩的音频数据，所以无论何时使用音频单元，这都是正确的格式标识符
    inAudioStreamBasicDescription.mFormatID = kAudioFormatLinearPCM;
    inAudioStreamBasicDescription.mFormatFlags = kAudioFormatFlagIsSignedInteger | kAudioFormatFlagIsPacked;
    
    inAudioStreamBasicDescription.mBytesPerPacket = bytesPerSample *channels;
    inAudioStreamBasicDescription.mBytesPerFrame = bytesPerSample * channels;
    inAudioStreamBasicDescription.mChannelsPerFrame = channels;
    inAudioStreamBasicDescription.mFramesPerPacket = 1;
    inAudioStreamBasicDescription.mBitsPerChannel = 8 * channels;
    inAudioStreamBasicDescription.mSampleRate = inputSampleRate;
    inAudioStreamBasicDescription.mReserved = 0;      //必须设置为0  填充结构以强制进行均匀的8字节对齐
    
    AudioStreamBasicDescription outAudioStreamBasicDescription = {0};
    outAudioStreamBasicDescription.mSampleRate = inAudioStreamBasicDescription.mSampleRate;
    outAudioStreamBasicDescription.mFormatID = kAudioFormatMPEG4AAC;
    outAudioStreamBasicDescription.mFormatFlags = kMPEG4Object_AAC_LC;
    outAudioStreamBasicDescription.mBytesPerPacket = 0;
    outAudioStreamBasicDescription.mFramesPerPacket = 1024;
    outAudioStreamBasicDescription.mBytesPerFrame = 0;
    outAudioStreamBasicDescription.mChannelsPerFrame = inAudioStreamBasicDescription.mChannelsPerFrame;
    outAudioStreamBasicDescription.mBitsPerChannel = 0;
    outAudioStreamBasicDescription.mReserved = 0;
    
    AudioClassDescription *description = [self getAudioClassDescriptionWithType:kAudioFormatMPEG4AAC
                                                               fromManufacturer:kAppleSoftwareAudioCodecManufacturer];
    
    OSStatus status = AudioConverterNewSpecific(&inAudioStreamBasicDescription,
                                                &outAudioStreamBasicDescription,
                                                1,
                                                description,
                                                &_audioConverter);
    if (status != 0) {
        NSLog(@"setup converter:%d", (int)status);
    }
    UInt32 ulSize = sizeof(bitRate);
    status = AudioConverterSetProperty(_audioConverter,
                                       kAudioConverterEncodeBitRate,
                                       ulSize,
                                       &bitRate);
    UInt32 size = sizeof(_aacBufferSize);
    AudioConverterGetProperty(_audioConverter,
                              kAudioConverterPropertyMaximumOutputPacketSize,
                              &size,
                              &_aacBufferSize);
    NSLog(@"Expected BitRate is %@, Output PacketSize is %d", @(bitRate), _aacBufferSize);
    
    _aacBuffer = malloc(_aacBufferSize * sizeof(uint8_t));
    memset(_aacBuffer, 0, _aacBufferSize);
}

- (AudioClassDescription *)getAudioClassDescriptionWithType:(UInt32)type
                                           fromManufacturer:(UInt32)manufacturer{
    static AudioClassDescription desc;
    
    UInt32 encoderSpecifier = type;
    OSStatus st;
    
    UInt32 size;
    st = AudioFormatGetPropertyInfo(kAudioFormatProperty_Encoders,
                                    sizeof(encoderSpecifier),
                                    &encoderSpecifier,
                                    &size);
    if (st) {
        NSLog(@"error getting audio format property info:%d", (int)(st));
        return nil;
    }
    
    unsigned int count = size / sizeof(AudioClassDescription);
    AudioClassDescription descriptions[count];
    st = AudioFormatGetProperty(kAudioFormatProperty_Encoders,
                                sizeof(encoderSpecifier),
                                &encoderSpecifier,
                                &size,
                                descriptions);
    if (st) {
        NSLog(@"error getting audio format format property:%d", (int)st);
        return nil;
    }
    
    for (unsigned int i = 0; i < count; i ++) {
        if ((type == descriptions[i].mSubType) && (manufacturer == descriptions[i].mManufacturer)) {
            memcpy(&desc,
                   &(descriptions[i]),
                   sizeof(desc));
            return &desc;
        }
    }
    
    return nil;
}

- (void)encoder{
    while (!_isCompletion) {
        NSData *outputData = nil;
        if (_audioConverter) {
            NSError *error = nil;
            AudioBufferList outAudioBufferList = {0};
            outAudioBufferList.mNumberBuffers = 1;
            outAudioBufferList.mBuffers[0].mNumberChannels = _channels;
            outAudioBufferList.mBuffers[0].mDataByteSize = (int)_aacBufferSize;
            outAudioBufferList.mBuffers[0].mData = _aacBuffer;
            
            AudioStreamPacketDescription *outPacketDescription = NULL;
            UInt32 ioOutputDataPacketSize = 1;
            
            OSStatus status = AudioConverterFillComplexBuffer(_audioConverter,
                                                              inInputDataProc,
                                                              (__bridge void *)(self),
                                                              &ioOutputDataPacketSize,
                                                              &outAudioBufferList,
                                                              outPacketDescription);
            if (status == 0) {
                NSData *rawAAC = [NSData dataWithBytes:outAudioBufferList.mBuffers[0].mData
                                                length:outAudioBufferList.mBuffers[0].mDataByteSize];
                if (_withADTSHeader) {
                    NSData *adtsHeader = [self adtsDataForPacketLength:rawAAC.length];
                    NSMutableData *fullData = [NSMutableData dataWithData:adtsHeader];
                    [fullData appendData:rawAAC];
                    outputData = fullData;
                } else {
                    outputData = rawAAC;
                }
            } else {
                error = [NSError errorWithDomain:NSOSStatusErrorDomain
                                            code:status
                                        userInfo:nil];
            }
            
            if (self.fillAudioDataDelegate && [self.fillAudioDataDelegate respondsToSelector:@selector(outputAACPacket:presentationTimeMills:error:)]) {
                [self.fillAudioDataDelegate outputAACPacket:outputData
                                  presentationTimeMills:_presentationTimeMills
                                                  error:error];
            }
        } else {
            NSLog(@"Audio Converter Init Failed...");
            break;
        }
    }
    
    if (self.fillAudioDataDelegate && [self.fillAudioDataDelegate respondsToSelector:@selector(onCompletion)]) {
        [self.fillAudioDataDelegate onCompletion];
    }
}

OSStatus inInputDataProc(AudioConverterRef inAudioCOnverter,
                         UInt32 *ioNumberDataPackets,
                         AudioBufferList *ioData,
                         AudioStreamPacketDescription **outDataPacketDescription,
                         void *inUserData){
    
    AudioToolboxEncoder *encoder = (__bridge AudioToolboxEncoder *)(inUserData);
    return [encoder fillAudioRawData:ioData
                 ioNumberDataPackets:ioNumberDataPackets];
}

- (OSStatus)fillAudioRawData:(AudioBufferList *)ioData
         ioNumberDataPackets:(UInt32 *)ioNumberDataPackets{
    
    UInt32 requestedPackets = *ioNumberDataPackets;
    uint32_t bufferLength = requestedPackets * _channels * 2;
    uint32_t bufferRead = 0;
    
    if (NULL == _pcmBuffer) {
        _pcmBuffer = malloc(bufferLength);
    }
    
    if (self.fillAudioDataDelegate && [self.fillAudioDataDelegate respondsToSelector:@selector(fillAudioData:bufferSize:)]) {
            bufferRead = [self.fillAudioDataDelegate fillAudioData:_pcmBuffer
                                                        bufferSize:bufferLength];
    }
    
    if(bufferRead <= 0) {
        *ioNumberDataPackets = 0;
        _isCompletion = YES;
        return -1;
    }
    
    _presentationTimeMills += (float)requestedPackets * 1000 / (float)_inputSampleRate;
    ioData->mBuffers[0].mData = _pcmBuffer;
    ioData->mBuffers[0].mDataByteSize = bufferRead;
    ioData->mNumberBuffers = 1;
    ioData->mBuffers[0].mNumberChannels = _channels;
    *ioNumberDataPackets = 1;
    return noErr;
}

- (NSData *)adtsDataForPacketLength:(NSUInteger)packetLength{
    int adtsLength = 7;
    char *packet = malloc(sizeof(char) * adtsLength);
    
    int profile = 2;
    int freqIdx = 4;
    int chanCfg = _channels;
    
    NSUInteger fullLength = adtsLength + packetLength;
    
    packet[0] = (char)0xFF;
    packet[1] = (char)0xF9;
    packet[2] = (char)(((profile - 1) << 6) + (freqIdx << 2) + (chanCfg >> 2));
    packet[3] = (char)(((chanCfg&3) << 6) + (fullLength>>11));
    packet[4] = (char)((fullLength & 0x7FF) >> 3);
    packet[5] = (char)(((fullLength & 7) << 5) + 0x1F);
    packet[6] = (char)0xFC;
    
    NSData *data = [NSData dataWithBytesNoCopy:packet
                                        length:adtsLength
                                freeWhenDone:YES];
    return data;
}

- (void)dealloc{
    if (_pcmBuffer) {
        free(_pcmBuffer);
        _pcmBuffer = NULL;
    }
    
    if (_aacBuffer) {
        free(_aacBuffer);
        _aacBuffer = NULL;
    }
    
    AudioConverterDispose(_audioConverter);
}
@end
