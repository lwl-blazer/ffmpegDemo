
//
//  H264HwEncoderImpl.m
//  BLVideoToolboxEncoder
//
//  Created by luowailin on 2019/10/30.
//  Copyright © 2019 luowailin. All rights reserved.
//

#import "H264HwEncoderImpl.h"
#include <sys/sysctl.h>
#import <UIKit/UIKit.h>

@interface H264HwEncoderImpl ()
{
    VTCompressionSessionRef EncodingSession; //VTCompressionSession 硬件编码器  VTDecompressionRef 硬件解码器
    dispatch_queue_t aQueue;
    CMFormatDescriptionRef format;
    CMSampleTimingInfo *timingInfo;
    int64_t encodingTimeMills;
    int m_fps;
    int m_maxBitRate;
    int m_avgBitRate;
    
    NSData *sps;
    NSData *pps;
    
    CFBooleanRef has_b_frames_cfbool;
    int64_t last_dts;
}
@property(nonatomic, assign) BOOL initialized;

@end

@implementation H264HwEncoderImpl

static int continuousEncodeFailureTimes;
static bool encodingSessionValid = false;

- (void)initWithConfiguration{
    EncodingSession = nil;
    aQueue = dispatch_get_global_queue(DISPATCH_QUEUE_PRIORITY_DEFAULT, 0);
    encodingTimeMills = -1;
    sps = NULL;
    pps = NULL;
    continuousEncodeFailureTimes = 0;
}

- (void)initEncode:(int)width
            height:(int)height
               fps:(int)fps
        maxBitRate:(int)maxBitRate
        avgBitRate:(int)avgBitRate{
    dispatch_sync(aQueue, ^{
        //创建编码器会话(编码的视频宽、高、编码器类型、回调函数、回调函数上下文)
        OSStatus status = VTCompressionSessionCreate(NULL,
                                                     width,
                                                     height,
                                                     kCMVideoCodecType_H264,
                                                     NULL,
                                                     NULL,
                                                     NULL,
                                                     didCompressH264,
                                                     (__bridge void *)(self),
                                                     &EncodingSession);
        if (status != 0) {
            NSLog(@"H264:Unable to create a H264 session status is %d", (int)status);
            [_encoderStatusDelegate onEncoderInitialFailed];
            self.error = @"H264:Unable to create a H264 session";
            return;
        }
        
        
        //set the properties
        VTSessionSetProperty(EncodingSession,
                             kVTCompressionPropertyKey_RealTime, //是否需要实时编码
                             kCFBooleanTrue);
        VTSessionSetProperty(EncodingSession,
                             kVTCompressionPropertyKey_ProfileLevel, //使用H264的profile是High的AutoLevel规格
                             kVTProfileLevel_H264_High_AutoLevel);
        VTSessionSetProperty(EncodingSession,
                             kVTCompressionPropertyKey_AllowFrameReordering,   //是否产生B帧
                             kCFBooleanFalse);
        [self settingMaxBitRate:maxBitRate
                     avgBitRate:avgBitRate
                            fps:fps];
        
        //告诉编码器开始编码
        VTCompressionSessionPrepareToEncodeFrames(EncodingSession);
        
        //重新拿到是否产生B帧的属性设置
        status = VTSessionCopyProperty(EncodingSession,
                                       kVTCompressionPropertyKey_AllowFrameReordering,
                                       kCFAllocatorDefault,
                                       &has_b_frames_cfbool);
        self.initialized = YES;
        encodingSessionValid = true;
    });
    
}

- (void)settingMaxBitRate:(int)maxBitRate avgBitRate:(int)avgBitRate fps:(int)fps{
    NSLog(@"设置avgBitRate %dKb", avgBitRate / 1024);
    m_fps = fps;
    VTSessionSetProperty(EncodingSession,
                         kVTCompressionPropertyKey_MaxKeyFrameInterval,  //设置关键帧的间隔，通常是指gop size
                         (__bridge CFTypeRef)(@(fps)));
    
    VTSessionSetProperty(EncodingSession,
                         kVTCompressionPropertyKey_ExpectedFrameRate,   //设置帧率
                         (__bridge CFTypeRef)(@(fps)));
    
    //kVTCompressionPropertyKey_DataRateLimits  kVTCompressionPropertyKey_AverageBitRate  共同用于控制编码器输出的码率
    if (![self isInSettingDataRateLimitsBlackList]) {
        VTSessionSetProperty(EncodingSession,
                             kVTCompressionPropertyKey_DataRateLimits,
                             (__bridge CFArrayRef)@[@(maxBitRate / 8), @1.0]);
    }
    
    VTSessionSetProperty(EncodingSession,
                         kVTCompressionPropertyKey_AverageBitRate,
                         (__bridge CFTypeRef)@(avgBitRate));
}

- (BOOL)isInSettingDataRateLimitsBlackList{
    BOOL ret = false;
    
    NSString *systemVersion = [[UIDevice currentDevice] systemVersion];
    NSArray *prefixBlackList = [NSArray arrayWithObjects:@"8.2", @"8.1", nil];
    for (NSString *prefix in prefixBlackList) {
        if ([systemVersion hasPrefix:prefix]) {
            ret = true;
            break;
        }
    }
    
    if (ret) {
        //如果满足黑名单 就判断低于iPhone6的设备 返回false 否则花屏
        if (![self isIphoneOnlyAnd6Upper]) {
            ret = false;
        }
    }
    return ret;
}

- (void)encode:(CMSampleBufferRef)sampleBuffer{
    if (continuousEncodeFailureTimes > CONTINUOUS_ENCODE_FAILURE_TIMES_TRESHOLD) {
        [_encoderStatusDelegate onEncoderEncodedFailed];
    }
    
    dispatch_sync(aQueue, ^{
        if (!self.initialized) {
            return;
        }
        //说明编码器具体是如何使用的
        //输入CVPixelBuffer  构造当前编码视频帧的时间戳以及时长，最后调用编码会话对这个三个参数进行编码
        int64_t currentTimeMills = CFAbsoluteTimeGetCurrent() * 1000;
        if (-1 == self->encodingTimeMills) { //第一帧的时间
            self->encodingTimeMills = currentTimeMills;
        }
        
        int64_t encodingDuration = currentTimeMills - self->encodingTimeMills;
        CVImageBufferRef imageBuffer = (CVImageBufferRef)CMSampleBufferGetImageBuffer(sampleBuffer);
        //pts,显示时间戳  dur时长  dts编码时间戳
        CMTime pts = CMTimeMake(encodingDuration, 1000); //timestamp is in ms
        CMTime dur = CMTimeMake(1, m_fps);  //此帧的时长
        
        VTEncodeInfoFlags flags;
        //待编码器编码成功之后，就会回调最开始初始化编码器会话时传入的回调函数，
        OSStatus statusCode = VTCompressionSessionEncodeFrame(EncodingSession,
                                                              imageBuffer,
                                                              pts,
                                                              dur,
                                                              NULL,
                                                              NULL,
                                                              &flags);
        
        if (statusCode != noErr) {
            self.error = @"H264:VTCompressionSessionEncodeFrame failed";
            return;
        }
    });
}

void didCompressH264(void *outputCallbackRefCon,
                     void *sourceFrameRefCon,
                     OSStatus status,
                     VTEncodeInfoFlags infoFlags,
                     CMSampleBufferRef sampleBuffer){
    if (status != noErr) { //首先判断status 如果为0 表示成功，如果不成功不处理
        continuousEncodeFailureTimes++;
        return;
    }
    
    continuousEncodeFailureTimes = 0;
    if (!CMSampleBufferDataIsReady(sampleBuffer)) {
        return;
    }
    
    if (!encodingSessionValid) {
        return;
    }
    
    H264HwEncoderImpl *encoder = (__bridge H264HwEncoderImpl *)outputCallbackRefCon;
    
    //判断是否为关键帧
    bool keyframe = !CFDictionaryContainsKey((CFDictionaryRef)(CFArrayGetValueAtIndex(CMSampleBufferGetSampleAttachmentsArray(sampleBuffer, true), 0)),
                                             (const void *)kCMSampleAttachmentKey_NotSync);
    
    /**
     * 为什么要判断关键帧，因为VideoToolbox编码器在每一个关键帧前面都会输出SPS和PPS信息,如果是关键帧，则取出对应的SPS和PPS信息。
     * CMSampleBuffer中有一个CMVideoFormatDesc 而SPS和PPS信息就存在于这个对于视频格式的描述里面
     */
    if (keyframe) {
        if (encoder) {
            CMFormatDescriptionRef format = CMSampleBufferGetFormatDescription(sampleBuffer);
            
            size_t sparameterSetSize, sparameterSetCount;
            const uint8_t *sparameterSet;
            OSStatus statusCode = CMVideoFormatDescriptionGetH264ParameterSetAtIndex(format,
                                                                                     0, //代表sps
                                                                                     &sparameterSet,
                                                                                     &sparameterSetSize,
                                                                                     &sparameterSetCount,
                                                                                     0);
            if (statusCode == noErr) {
                size_t pparameterSetSize, pparameterSetCount;
                const uint8_t *pparameterSet;
                OSStatus statusCode = CMVideoFormatDescriptionGetH264ParameterSetAtIndex(format,
                                                                                         1,  //代表pps
                                                                                         &pparameterSet,
                                                                                         &pparameterSetSize,
                                                                                         &pparameterSetCount,
                                                                                         0);
                if (statusCode == noErr) {
                    encoder->sps = [NSData dataWithBytes:sparameterSet length:sparameterSetSize];
                    encoder->pps = [NSData dataWithBytes:pparameterSet length:pparameterSetSize];
                    
                    if (encoder->_delegate) {
                        //取出此帧的时间戳 CMSampleBufferGetPresentationTimeStamp()  取出PTS
                        double timeMills = CMTimeGetSeconds(CMSampleBufferGetPresentationTimeStamp(sampleBuffer)) * 1000;
                        [encoder->_delegate gotSpsPps:encoder->sps
                                                  pps:encoder->pps
                                           timestramp:timeMills
                                          fromEncoder:encoder];
                    }
                }
            }
        }
    }
    
    //提出此帧的压缩内容 CMBlockBufferRef
    CMBlockBufferRef dataBuffer = CMSampleBufferGetDataBuffer(sampleBuffer);
    size_t length,totalLength;
    char *dataPointer;
    //访问CMBlockBufferRef的这块内，
    OSStatus statusCodeRet = CMBlockBufferGetDataPointer(dataBuffer,
                                                         0,
                                                         &length,
                                                         &totalLength,
                                                         &dataPointer);
    //取出具体的数据，就可以做后续操作了
    if (statusCodeRet == noErr) {
        size_t bufferOffset = 0;
        static const int AVCCHeaderLength = 4;
        while (bufferOffset < totalLength - AVCCHeaderLength) {
            uint32_t NALUnitLength = 0;
            memcpy(&NALUnitLength, dataPointer + bufferOffset, AVCCHeaderLength);
            NALUnitLength = CFSwapInt32BigToHost(NALUnitLength);
            NSData *data = [[NSData alloc] initWithBytes:(dataPointer + bufferOffset + AVCCHeaderLength) length:NALUnitLength];
            CMTime presentationTimeStamp = CMSampleBufferGetPresentationTimeStamp(sampleBuffer);
            double presentationTimeMills = CMTimeGetSeconds(presentationTimeStamp) * 1000;
            int64_t pts = presentationTimeMills / 1000.0 * 1000;
            int64_t dts = pts;
            
            [encoder->_delegate gotEncodedData:data
                                    isKeyFrame:keyframe
                                    timestramp:presentationTimeMills
                                           pts:pts
                                           dts:dts
                                   fromEncoder:encoder];
            bufferOffset += AVCCHeaderLength + NALUnitLength;
        }
    }
}

- (void)endCompresseion{
    NSLog(@"begin endCompression");
    self.initialized = NO;
    encodingSessionValid = false;
    
    VTCompressionSessionCompleteFrames(EncodingSession, kCMTimeInvalid);
    
    VTCompressionSessionInvalidate(EncodingSession);
    
    CFRelease(EncodingSession);
    
    NSLog(@"endCompression success");
    
    EncodingSession = NULL;
    self.error = NULL;
}


- (BOOL)isIphoneOnlyAnd6Upper{
    
    NSString *platform = [self platform];
    if (([platform rangeOfString:@"iPhone"].location != NSNotFound) && ([platform compare:@"iPhone7,0"] == NSOrderedDescending)) {
        return YES;
    }
    return NO;
}

- (NSString *)platform{
    return [self getSysInfoByName:"hw.machine"];
}

- (NSString *)getSysInfoByName:(char *)typeSpecifier{
    size_t size;
    sysctlbyname(typeSpecifier,
                 NULL,
                 &size,
                 NULL,
                 0);
    
    char *answer = (char *)malloc(size);
    sysctlbyname(typeSpecifier,
                 answer,
                 &size,
                 NULL,
                 0);
    
    NSString *results = @(answer);
    
    free(answer);
    
    return results;
}

@end
