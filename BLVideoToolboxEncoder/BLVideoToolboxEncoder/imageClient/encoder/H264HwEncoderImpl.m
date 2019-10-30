
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
    VTCompressionSessionRef EncodingSession;
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
                             kVTCompressionPropertyKey_RealTime,
                             kCFBooleanTrue);
        VTSessionSetProperty(EncodingSession,
                             kVTCompressionPropertyKey_ProfileLevel,
                             kVTProfileLevel_H264_High_AutoLevel);
        VTSessionSetProperty(EncodingSession,
                             kVTCompressionPropertyKey_AllowFrameReordering,
                             kCFBooleanFalse);
        [self settingMaxBitRate:maxBitRate
                     avgBitRate:avgBitRate
                            fps:fps];
        
        VTCompressionSessionPrepareToEncodeFrames(EncodingSession);
        
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
                         kVTCompressionPropertyKey_MaxKeyFrameInterval,
                         (__bridge CFTypeRef)(@(fps)));
    
    VTSessionSetProperty(EncodingSession,
                         kVTCompressionPropertyKey_ExpectedFrameRate,
                         (__bridge CFTypeRef)(@(fps)));
    
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
        
        int64_t currentTimeMills = CFAbsoluteTimeGetCurrent() * 1000;
        if (-1 == self->encodingTimeMills) {
            self->encodingTimeMills = currentTimeMills;
        }
        
        int64_t encodingDuration = currentTimeMills - self->encodingTimeMills;
        CVImageBufferRef imageBuffer = (CVImageBufferRef)CMSampleBufferGetImageBuffer(sampleBuffer);
        
        CMTime pts = CMTimeMake(encodingDuration, 1000);
        CMTime dur = CMTimeMake(1, m_fps);
        
        VTEncodeInfoFlags flags;
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
    if (status != noErr) {
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
    
    bool keyframe = !CFDictionaryContainsKey((CFDictionaryRef)(CFArrayGetValueAtIndex(CMSampleBufferGetSampleAttachmentsArray(sampleBuffer, true), 0)),
                                             (const void *)kCMSampleAttachmentKey_NotSync);
    if (keyframe) {
        if (encoder) {
            CMFormatDescriptionRef format = CMSampleBufferGetFormatDescription(sampleBuffer);
            
            size_t sparameterSetSize, sparameterSetCount;
            const uint8_t *sparameterSet;
            OSStatus statusCode = CMVideoFormatDescriptionGetH264ParameterSetAtIndex(format,
                                                                                     0,
                                                                                     &sparameterSet,
                                                                                     &sparameterSetSize,
                                                                                     &sparameterSetCount,
                                                                                     0);
            if (statusCode == noErr) {
                size_t pparameterSetSize, pparameterSetCount;
                const uint8_t *pparameterSet;
                OSStatus statusCode = CMVideoFormatDescriptionGetH264ParameterSetAtIndex(format,
                                                                                         1,
                                                                                         &pparameterSet,
                                                                                         &pparameterSetSize,
                                                                                         &pparameterSetCount,
                                                                                         0);
                if (statusCode == noErr) {
                    encoder->sps = [NSData dataWithBytes:sparameterSet length:sparameterSetSize];
                    encoder->pps = [NSData dataWithBytes:pparameterSet length:pparameterSetSize];
                    
                    if (encoder->_delegate) {
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
    
    CMBlockBufferRef dataBuffer = CMSampleBufferGetDataBuffer(sampleBuffer);
    size_t length,totalLength;
    char *dataPointer;
    OSStatus statusCodeRet = CMBlockBufferGetDataPointer(dataBuffer,
                                                         0,
                                                         &length,
                                                         &totalLength,
                                                         &dataPointer);
    
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
