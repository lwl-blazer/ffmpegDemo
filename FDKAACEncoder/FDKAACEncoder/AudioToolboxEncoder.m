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
    //每个Packet的bytes
    inAudioStreamBasicDescription.mBytesPerPacket = bytesPerSample *channels;
    inAudioStreamBasicDescription.mBytesPerFrame = bytesPerSample * channels;
    inAudioStreamBasicDescription.mChannelsPerFrame = channels;

    inAudioStreamBasicDescription.mFramesPerPacket = 1;
    inAudioStreamBasicDescription.mBitsPerChannel = 8 * channels;
    inAudioStreamBasicDescription.mSampleRate = inputSampleRate;
    inAudioStreamBasicDescription.mReserved = 0;      //必须设置为0  填充结构以强制进行均匀的8字节对齐
    /**
     * 上面配置的inAudioStreamBasicDescription的mFormatID是PCM格式的，表示格式是整数并且是交错存储的，这一点十分关键，因为需要按照设置的格式填充PCM数据，或者反过来说，客户端代码填充的PCM数据的格式是什么样的，这里配置给input描述的mFormatFlags就应该是什么样的，因为我们提供的数据就是交错存放，所以填充后续几个关键值都得乘以channels
     *
     * 在iOS的音频流描述的配置中，最重要的就是存储格式和表示格式的配置，表示格式是指用整数或者浮点数表示一个sample;存储格式是指交错存储或非交错存储，输出或输入数据都存储于AudioBufferList中的属性ioData中。假设声道是双声道的，对于非交错存储(isPacked)来讲，对应的数据格式如下：
     *    ioData->mBuffers[0]; LRLRLR.....
     * 而对于非交错的存储(NonInterleaved)来讲，对应的数据格式如下:
     *    ioData->mBuffers[0]：LLLLLL...
     *    ioData->mBuffers[1]: RRRRR....
     *
     *  这要求客户端代码需要按照配置的格式描述来填充或者获取数据，否则就会出现不可预知的问题
     */
    
    /**mFormatID需要配置成AAC的编码格式，profile(mFormatFLags)需要配置为低运算复杂度的规格(LC),最后需要注意一点是，配置一帧数据时，其大小为1024，这是AAC编码格式要求的帧大小*/
    AudioStreamBasicDescription outAudioStreamBasicDescription = {0};
    outAudioStreamBasicDescription.mSampleRate = inAudioStreamBasicDescription.mSampleRate;
    outAudioStreamBasicDescription.mFormatID = kAudioFormatMPEG4AAC;
    outAudioStreamBasicDescription.mFormatFlags = kMPEG4Object_AAC_LC;
    outAudioStreamBasicDescription.mBytesPerPacket = 0;
    //每个Packet的帧数量 设置一个较大的固定值
    outAudioStreamBasicDescription.mFramesPerPacket = 1024;
    outAudioStreamBasicDescription.mBytesPerFrame = 0;
    outAudioStreamBasicDescription.mChannelsPerFrame = inAudioStreamBasicDescription.mChannelsPerFrame;
    outAudioStreamBasicDescription.mBitsPerChannel = 0;
    outAudioStreamBasicDescription.mReserved = 0;
    
    //step 4:找到对应的编码器
    AudioClassDescription *description = [self getAudioClassDescriptionWithType:kAudioFormatMPEG4AAC
                                                               fromManufacturer:kAppleSoftwareAudioCodecManufacturer];
    
    //创建编码转换器
    OSStatus status = AudioConverterNewSpecific(&inAudioStreamBasicDescription,   //源音频格式
                                                &outAudioStreamBasicDescription,  //目标音频格式
                                                1,  //音频编码器个数
                                                description,    //音频编码器的描述
                                                &_audioConverter);
    if (status != 0) {
        NSLog(@"setup converter:%d", (int)status);
    }
    
    //给转换器设置bitrate参数
    UInt32 ulSize = sizeof(bitRate);
    status = AudioConverterSetProperty(_audioConverter,
                                       kAudioConverterEncodeBitRate,
                                       ulSize,
                                       &bitRate);
    UInt32 size = sizeof(_aacBufferSize);
    //从转换器获取参数
    AudioConverterGetProperty(_audioConverter,
                              kAudioConverterPropertyMaximumOutputPacketSize,  //编码之后输出的AAC其Packet size最大值是多少。因为需要按照该值来分配编码后数据的存储空间
                              &size,
                              &_aacBufferSize);
    NSLog(@"Expected BitRate is %@, Output PacketSize is %d", @(bitRate), _aacBufferSize);
    
    //初始化初始空间
    _aacBuffer = malloc(_aacBufferSize * sizeof(uint8_t));
    memset(_aacBuffer, 0, _aacBufferSize);
}

/**
 * 构造一个编码器类的描述--用于提供编码器的类型以及编码器的实现方式
 * 因为是编码AAC,所以其所使用编码器类型是kAudioFormatMPEG4AAC,编码的实现方式是使用兼容性更好的软件编码方式(虽然是软件编码方式，但是也是有硬件加速的)：kAppleSoftwareAudioCodecManufacturer。
 *
 * 通过这两个输入可构造出一个编码器类的描述，它将告诉iOS系统开发者想要使用的到底是哪一个编码器
 */
- (AudioClassDescription *)getAudioClassDescriptionWithType:(UInt32)type
                                           fromManufacturer:(UInt32)manufacturer{
    //编解码器类型
    static AudioClassDescription desc;
    
    UInt32 encoderSpecifier = type; //type是kAudioFormatMPEG4AAC   ‘aac’
    OSStatus st = noErr;
    UInt32 size;
    //获取Audio Format Property的information
    st = AudioFormatGetPropertyInfo(kAudioFormatProperty_Encoders,   //kAudioFormatProperty_Encoders 编码ID， 编码说明大小，属性当前值的大小
                                    sizeof(encoderSpecifier),
                                    &encoderSpecifier,   //inSpecifier 所需要的格式
                                    &size);
    if (st) {
        NSLog(@"error getting audio format property info:%d", (int)(st));
        return nil;
    }
    
    //计算编码器的个数
    unsigned int count = size / sizeof(AudioClassDescription);
    AudioClassDescription descriptions[count];
    //获取Audio Format Property的value
    st = AudioFormatGetProperty(kAudioFormatProperty_Encoders,
                                sizeof(encoderSpecifier),
                                &encoderSpecifier,
                                &size,
                                descriptions);
    if (st) {
        NSLog(@"error getting audio format format property:%d", (int)st);
        return nil;
    }
    
    //筛选出
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
            //step 4:设置缓冲列表AudioBufferList   作为编码器输出AAC数据的存储容器
            AudioBufferList outAudioBufferList = {0};
            outAudioBufferList.mNumberBuffers = 1;
            outAudioBufferList.mBuffers[0].mNumberChannels = _channels;
            outAudioBufferList.mBuffers[0].mDataByteSize = (int)_aacBufferSize;
            outAudioBufferList.mBuffers[0].mData = _aacBuffer;
            
            //step 5:开始编码，在编码回调函数中处理
            AudioStreamPacketDescription *outPacketDescription = NULL;
            
            /** AudioConverter 提供了三个函数用于编解码
             * 1.
             *   OSStatus AudioConverterConvertBuffer(AudioConverterRef inAudioConverter,
             *                                                    UInt32 inInputDataSize,
             *                                                  const void * inInputData,
             *                                                  UInt32 *ioOutputDataSize,
             *                                                        void *outOutputData);
             *
             * 2.
             *  OSStatus AudioConverterConvertComplexBuffer(AudioConverterRef inAudioConverter,
             *                                                        UInt32 inNumberPCMFrames,
             *                                               const AudioBufferList *inInputData,
             *                                               AudioBufferList *outOutputData);
             *
             *  这两个函数功能类似，都只支持PCM之间的转换，并且两种PCM的采样率必须一致。无法从PCM转换成其他压缩格式或者从压缩格式转换成PCM
             *
             * 3.
             *  OSStatus AudioConverterFillComplexBuffer(AudioConverterRef inAudioConverter
             *                                           AudioConverterComplexInputDataProc inInputDataProc,
             *                                           void * inInputDataProcUserData,
             *                                           UInt32 * ioOutputDataPacketSize,
             *                                           AudioBufferList *outOutputData,
             *                                           AudioStreamPacketDescription * outPacketDescription);
             */
            UInt32 ioOutputDataPacketSize = 1;
            OSStatus status = AudioConverterFillComplexBuffer(_audioConverter,
                                                              inInputDataProc,    //提供音频数据进行转换的回调函数  当AudioConverter准备好新的输入数据时，这个回调被重复使用
                                                              (__bridge void *)(self),
                                                              &ioOutputDataPacketSize,  //在输入时代表另一个参数outOutputData的大小(以音频包表示)，在输出时会写入已经转换了的数据包数。如果调用完毕ioOutputDataPacketSize == 0 说明EOF (end of file)
                                                              &outAudioBufferList, //转换后的数据输出
                                                              outPacketDescription); //outPacketDescription 在输入时，必须指向能够保存ioOutputDataPacketSize * sizeof(AudioStreamPacketDescription)内存块。在输出时如果为空，并且AudioConverter的AudioStreamPacketDescription数组
            
            
            if (status == 0) { //先执行inInputDataProc回调，然后再到这里
                //step 7: 编码完成，获取缓冲区的数据，添加ADTS头信息
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
            
            //step 8: 将数据写入文件
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
                         UInt32 *ioNumberDataPackets, //ioNumberDataPackets在输入时，代表AudioConverter可以完成本次转换所需要的最小数据包数，在输出时，代表实际转换的音频数据包数
                         AudioBufferList *ioData,  //ioData在输出时，将此结构体的字段指向要提供的要转换的音频数据
                         AudioStreamPacketDescription **outDataPacketDescription,   //在输入时，如果不为NULL，则需要在输出时提供一组AudioStreamPacketDescription结构，用于给ioData参数中提供AudioStreamPacketDescription描述信息
                         void *inUserData){
    AudioToolboxEncoder *encoder = (__bridge AudioToolboxEncoder *)(inUserData);
    //step 6:将数据填充到缓冲区
    return [encoder fillAudioRawData:ioData
                 ioNumberDataPackets:ioNumberDataPackets];
}

- (OSStatus)fillAudioRawData:(AudioBufferList *)ioData
         ioNumberDataPackets:(UInt32 *)ioNumberDataPackets{
    
    UInt32 requestedPackets = *ioNumberDataPackets;
    //根据需要填充的帧的数目、当前声道数以及表示格式计算出需要填充的uint8_t类型的buffer的大小
    uint32_t bufferLength = requestedPackets * _channels * 2;
    uint32_t bufferRead = 0;
    
    if (NULL == _pcmBuffer) {
        _pcmBuffer = malloc(bufferLength);
    }
    //从源文件读取数据
    if (self.fillAudioDataDelegate && [self.fillAudioDataDelegate respondsToSelector:@selector(fillAudioData:bufferSize:)]) {
            bufferRead = [self.fillAudioDataDelegate fillAudioData:_pcmBuffer
                                                        bufferSize:bufferLength];
    }
    
    //如果读取完成后，把isCompletion 设为YES
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
