//
//  VideoToolboxDecoder.m
//  Advance-video-play
//
//  Created by luowailin on 2019/9/11.
//  Copyright © 2019 luowailin. All rights reserved.
//

#import "VideoToolboxDecoder.h"

#define is_start_code(code) (((code) & 0x0ffffff) == 0x01)

@interface VideoToolboxDecoder ()
{
    VideoFrame * _videoFrame;
}
@property(nonatomic, strong) dispatch_semaphore_t decoderSemaphore;

@end

@implementation VideoToolboxDecoder

- (instancetype)init{
    self = [super init];
    if (self) {
        _decoderSemaphore = dispatch_semaphore_create(0);
    }
    return self;
}

- (BOOL)openVideoStream{
    if ([super openVideoStream]) {
        uint8_t *bufSPS = 0;
        uint8_t *bufPPS = 0;
        
        int sizeSPS = 0;
        int sizePPS = 0;
        
        [self parseH264SequenceHeader:(uint8_t *)_videoCodecCtx->extradata
                           bufferSize:_videoCodecCtx->extradata_size
                               bufSPS:&bufSPS sizeSPS:&sizeSPS
                               bufPPS:&bufPPS sizePPS:&sizePPS];
        
        uint8_t *parameterSetPointers[2] = {bufSPS, bufPPS};
        size_t parameterSetSizes[2] = {sizeSPS, sizePPS};
        
        OSStatus status = CMVideoFormatDescriptionCreateFromH264ParameterSets(kCFAllocatorDefault,
                                                                              2,
                                                                              (const uint8_t * const *)parameterSetPointers,
                                                                              parameterSetSizes,
                                                                              4,
                                                                              &_formatDesc);
        
        if ((status == noErr) && (_decompressionSession == NULL)) {
            [self createDecompSession];
            return YES;
        }
    }
    return NO;
}

- (VideoFrame *)decodeVideo:(AVPacket)packet packetSize:(int)pktSize decodeVideoErrorState:(int *)decodeVideoErrorState{
    uint8_t *data = packet.data;
    int blockLength = packet.size;
    OSStatus status;
    CMSampleBufferRef sampleBuffer = NULL;
    CMBlockBufferRef blockBuffer = NULL;
    
    int nalu_type = (data[4] & 0x1F);
    if (5 == nalu_type) {
        //IDR Frame
    } else if (1 == nalu_type) {
        //NON_IDR Frame
    } else {
        return nil;
    }
    
    status = CMBlockBufferCreateWithMemoryBlock(NULL,
                                                data,
                                                blockLength,
                                                kCFAllocatorNull,
                                                NULL,
                                                0,
                                                blockLength,
                                                0,
                                                &blockBuffer);
    if (status != kCMBlockBufferNoErr) {
        NSLog(@"\t\t BlockBufferCreation:\t failed...");
    }
    
    int64_t presentationTimeStamp = 0;
    int64_t decompressionTimeStamp = 0;
    int duration = 0;
    if (status == noErr) {
        if (packet.pts == AV_NOPTS_VALUE) {
            presentationTimeStamp = av_rescale_q(packet.dts, _formatCtx->streams[_videoStreamIndex]->time_base, AV_TIME_BASE_Q);
        } else {
            presentationTimeStamp = av_rescale_q(packet.pts, _formatCtx->streams[_videoStreamIndex]->time_base, AV_TIME_BASE_Q);
        }
        
        decompressionTimeStamp = av_rescale_q(packet.dts, _formatCtx->streams[_videoStreamIndex]->time_base, AV_TIME_BASE_Q);
        duration = (int)packet.duration;
        if (!duration) {
            duration = 1000 / [self getVideoFPS];
        }
        
        int32_t timeSpan = 1000;
        CMSampleTimingInfo timingInfo;
        timingInfo.presentationTimeStamp = CMTimeMake(presentationTimeStamp, timeSpan);
        timingInfo.decodeTimeStamp = CMTimeMake(decompressionTimeStamp, timeSpan);
        timingInfo.duration = CMTimeMake(duration, timeSpan);
        
        const size_t sampleSize = blockLength;
        status = CMSampleBufferCreate(kCFAllocatorDefault,
                                      blockBuffer,
                                      true,
                                      NULL,
                                      NULL,
                                      _formatDesc,
                                      1,
                                      0,
                                      &timingInfo,
                                      1,
                                      &sampleSize,
                                      &sampleBuffer);
        if (status != noErr) {
            NSLog(@"\t\t SampleBufferCreate: \t failed...");
        }
    }
    
    if (status == noErr) {
        CFArrayRef attachments = CMSampleBufferGetSampleAttachmentsArray(sampleBuffer, YES);
        CFMutableDictionaryRef dict = (CFMutableDictionaryRef)CFArrayGetValueAtIndex(attachments, 0);
        CFDictionarySetValue(dict, kCMSampleAttachmentKey_DisplayImmediately, kCFBooleanTrue);
        VTDecodeFrameFlags flags = kVTDecodeFrame_EnableAsynchronousDecompression;
        VTDecodeInfoFlags flagOut;
        
        status = VTDecompressionSessionDecodeFrame(_decompressionSession,
                                                   sampleBuffer,
                                                   flags,
                                                   &sampleBuffer,
                                                   &flagOut);
        
        if (status == noErr) {
            VTDecompressionSessionWaitForAsynchronousFrames(_decompressionSession);
            dispatch_semaphore_wait(self.decoderSemaphore, DISPATCH_TIME_FOREVER);
        }
        
        _videoFrame.position = presentationTimeStamp / 1000000.0;
        _videoFrame.duration = (float)duration / 1000.0;
        CFRelease(sampleBuffer);
    }
    
    if (NULL != blockBuffer) {
        CFRelease(blockBuffer);
        blockBuffer = NULL;
    }
    
    return _videoFrame;
}

- (void)parseH264SequenceHeader:(uint8_t *)in_pBuffer bufferSize:(uint32_t)bufferSize
                         bufSPS:(uint8_t **)bufSPS sizeSPS:(int *)sizeSPS
                         bufPPS:(uint8_t **)bufPPS sizePPS:(int *)sizePPS{
    int spsSize = (in_pBuffer[6] << 8) + in_pBuffer[7];
    *bufSPS = &in_pBuffer[8];
    int ppsSize = (in_pBuffer[8 + spsSize + 1] << 8) + in_pBuffer[8 + spsSize + 2];
    *bufPPS = &in_pBuffer[8 + spsSize + 3];
    *sizePPS = spsSize;
    *sizePPS = ppsSize;
}

- (void)createDecompSession{
    _decompressionSession = NULL;
    VTDecompressionOutputCallbackRecord callBackRecord;
    callBackRecord.decompressionOutputCallback = decompressionSessionDecodeFrameCallback;
    
    callBackRecord.decompressionOutputRefCon = (__bridge void *)self;
    NSDictionary *destinationImageBufferAttributes = [NSDictionary dictionaryWithObjectsAndKeys:[NSNumber numberWithBool:YES], (id)kCVPixelBufferOpenGLESCompatibilityKey, nil];
    OSStatus status = VTDecompressionSessionCreate(NULL,
                                                   _formatDesc,
                                                   NULL,
                                                   (__bridge CFDictionaryRef)(destinationImageBufferAttributes),
                                                   &callBackRecord,
                                                   &_decompressionSession);
    if (status != noErr) {
        NSLog(@"Video Decompression Session create:\t failed...");
    }
}

void decompressionSessionDecodeFrameCallback(void *decompressionOutputRefCon,
                                             void *sourceFrameRefCon,
                                             OSStatus status,
                                             VTDecodeInfoFlags infoFlags,
                                             CVImageBufferRef imageBuffer,
                                             CMTime presentationTimeStamp,
                                             CMTime presentationDuration){
    if (status != noErr || !imageBuffer) {
        NSLog(@"Error decompresssing frame at time: %.3f error: %d infoFlags: %u", (float)presentationTimeStamp.value/presentationTimeStamp.timescale, (int)status, (unsigned int)infoFlags);
        return;
    }
    
    __weak VideoToolboxDecoder *weakSelf = (__bridge VideoToolboxDecoder *)decompressionOutputRefCon;
    [weakSelf getDecodeImageData:imageBuffer
                             pts:presentationTimeStamp
                        duration:presentationDuration];
    dispatch_semaphore_signal(weakSelf.decoderSemaphore);
}

- (void)getDecodeImageData:(CVImageBufferRef)imageBuffer pts:(CMTime)presentationTimeStamp duration:(CMTime)presentationDuration{
    NSUInteger frameWidth = (NSUInteger)CVPixelBufferGetWidth(imageBuffer);
    NSUInteger frameHeight = (NSUInteger)CVPixelBufferGetHeight(imageBuffer);
    _videoFrame = [[VideoFrame alloc] init];
    _videoFrame.width = frameWidth;
    _videoFrame.height = frameHeight;
    _videoFrame.imageBuffer = (__bridge id)imageBuffer;
}

- (NSMutableData *)buildYUVFromImageBuffer:(CVImageBufferRef)imageBuffer{
    NSMutableData *mutableData = [[NSMutableData alloc] init];
    
    NSUInteger frameWidth = (NSUInteger)CVPixelBufferGetWidth(imageBuffer);
    NSUInteger frameHeight = (NSUInteger)CVPixelBufferGetHeight(imageBuffer);
    
    size_t bytePerRowY = CVPixelBufferGetBytesPerRowOfPlane(imageBuffer, 0);
    size_t bytePerRowUV = CVPixelBufferGetBytesPerRowOfPlane(imageBuffer, 1);
    _videoFrame.linesize = bytePerRowY;
    
    CVPixelBufferLockBaseAddress(imageBuffer, 0);
    
    //luma Data
    void *base = CVPixelBufferGetBaseAddressOfPlane(imageBuffer, 0);
    NSMutableData *lumaData = [NSMutableData dataWithLength:frameHeight * frameWidth];
    uint8_t *luma = lumaData.mutableBytes;
    for (int i = 0; i < frameHeight; i ++) {
        memcpy(luma, base, frameWidth);
        luma += frameWidth;
        base += bytePerRowY;
    }
    luma -= frameWidth * frameHeight;
    
    //chroma Data
    base = CVPixelBufferGetBaseAddressOfPlane(imageBuffer, 1);
    int chromaDataSourceSize = (int)(bytePerRowUV * frameHeight / 2);
    NSMutableData *chromaBSourceData = [NSMutableData dataWithLength:chromaDataSourceSize / 2];
    uint8_t *chromaBSource = chromaBSourceData.mutableBytes;
    
    NSMutableData *chromaRSourceData = [NSMutableData dataWithLength:chromaDataSourceSize / 2];
    uint8_t *chromaRSource = chromaRSourceData.mutableBytes;
    
    for (int i = 0; i < chromaDataSourceSize; i++) {
        if (i % 2 == 0) {
            chromaBSource[i/2] = ((uint8_t *)base)[i];
        } else {
            chromaRSource[i/2] = ((uint8_t *)base)[i];
        }
    }
    
    int chromaDataSize = (int)(frameWidth * frameHeight / 2);
    NSMutableData *chromaBData = [NSMutableData dataWithLength:chromaDataSize / 2];
    uint8_t *chromaB = chromaBData.mutableBytes;
    
    NSMutableData *chromaRData = [NSMutableData dataWithLength:chromaDataSize / 2];
    uint8_t *chromaR = chromaRData.mutableBytes;
    
    for (int i = 0; i < frameHeight / 2; i++) {
        memcpy(chromaB, chromaBSource, frameWidth / 2);
        memcpy(chromaR, chromaRSource, frameWidth / 2);
        
        chromaB += frameWidth / 2;
        chromaR += frameWidth / 2;
        
        chromaBSource += bytePerRowUV / 2;
        chromaRSource += bytePerRowUV / 2;
    }
    
    chromaB -= chromaDataSize / 2;
    chromaR -= chromaDataSize / 2;
    
    CVPixelBufferUnlockBaseAddress(imageBuffer, 0);
    
    [mutableData appendData:lumaData];
    [mutableData appendData:chromaBData];
    [mutableData appendData:chromaRData];
    
    _videoFrame.luma = lumaData;
    _videoFrame.chromaB = chromaBData;
    _videoFrame.chromaR = chromaRData;

    return mutableData;
}

- (void)closeVideoStream{
    [super closeVideoStream];
    if (_formatDesc) {
        CFRelease(_formatDesc);
    }
    
    if (_decompressionSession) {
        VTDecompressionSessionInvalidate(_decompressionSession);
        CFRelease(_decompressionSession);
    }
}

NSString * const naluTypesStrings[] =
{
    @"0: Unspecified (non-VCL)",
    @"1: Coded slice of a non-IDR picture (VCL)",    // P frame
    @"2: Coded slice data partition A (VCL)",
    @"3: Coded slice data partition B (VCL)",
    @"4: Coded slice data partition C (VCL)",
    @"5: Coded slice of an IDR picture (VCL)",      // I frame
    @"6: Supplemental enhancement information (SEI) (non-VCL)",
    @"7: Sequence parameter set (non-VCL)",         // SPS parameter
    @"8: Picture parameter set (non-VCL)",          // PPS parameter
    @"9: Access unit delimiter (non-VCL)",
    @"10: End of sequence (non-VCL)",
    @"11: End of stream (non-VCL)",
    @"12: Filler data (non-VCL)",
    @"13: Sequence parameter set extension (non-VCL)",
    @"14: Prefix NAL unit (non-VCL)",
    @"15: Subset sequence parameter set (non-VCL)",
    @"16: Reserved (non-VCL)",
    @"17: Reserved (non-VCL)",
    @"18: Reserved (non-VCL)",
    @"19: Coded slice of an auxiliary coded picture without partitioning (non-VCL)",
    @"20: Coded slice extension (non-VCL)",
    @"21: Coded slice extension for depth view components (non-VCL)",
    @"22: Reserved (non-VCL)",
    @"23: Reserved (non-VCL)",
    @"24: STAP-A Single-time aggregation packet (non-VCL)",
    @"25: STAP-B Single-time aggregation packet (non-VCL)",
    @"26: MTAP16 Multi-time aggregation packet (non-VCL)",
    @"27: MTAP24 Multi-time aggregation packet (non-VCL)",
    @"28: FU-A Fragmentation unit (non-VCL)",
    @"29: FU-B Fragmentation unit (non-VCL)",
    @"30: Unspecified (non-VCL)",
    @"31: Unspecified (non-VCL)",
};

@end
