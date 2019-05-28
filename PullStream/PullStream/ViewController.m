//
//  ViewController.m
//  PullStream
//
//  Created by luowailin on 2019/5/16.
//  Copyright © 2019 luowailin. All rights reserved.
//

#import "ViewController.h"
#include <librtmp/rtmp.h>
#include <librtmp/log.h>

#import <VideoToolbox/VideoToolbox.h>
#import "BLRtmpSession.h"
#import "BLRtmpConfig.h"
#import "AAPLEAGLLayer.h"


const uint8_t lyStartCode[4] = {0, 0, 0, 1};

@interface ViewController ()<BLRtmpSessionDelegate>{
    
    uint8_t *packetBuffer;
    long packetSize;
    
    uint8_t *mSPS;
    long mSPSSize;
    uint8_t *mPPS;
    long mPPSSize;
    
    uint8_t *naluBuffer;
    
    dispatch_queue_t mDecodeQueue;
    VTDecompressionSessionRef mDecodeSession;
    CMFormatDescriptionRef mFormatDescription;
    
}
@property (strong, nonatomic) AAPLEAGLLayer *eaglLayer;

@property(nonatomic, strong) NSFileManager *fileManager;
@property(nonatomic, copy) NSString *path;

@property(nonatomic, strong) BLRtmpSession *rtmpSession;

@end

@implementation ViewController

//第一步: 初始化Socket
- (void)InitSocket{
    
}

//最后一步:关闭Socket
- (void)cleanupSockets{
    
}

- (void)viewDidLoad {
    [super viewDidLoad];
    
    self.eaglLayer = [[AAPLEAGLLayer alloc] initWithFrame:self.view.frame];
    self.eaglLayer.backgroundColor = [UIColor redColor].CGColor;
    [self.view.layer addSublayer:self.eaglLayer];
    self.eaglLayer.zPosition = -1;
    
    mDecodeQueue = dispatch_get_global_queue(DISPATCH_QUEUE_PRIORITY_DEFAULT, 0);
    
    //创建空文件
    self.path = NSSearchPathForDirectoriesInDomains(NSDocumentDirectory, NSUserDomainMask, YES).lastObject;
    self.path = [self.path stringByAppendingPathComponent:@"receive.txt"];
    
    if ([self.fileManager fileExistsAtPath:self.path]) {
        [self.fileManager removeItemAtPath:self.path error:nil];
    }
    [self.fileManager createFileAtPath:self.path contents:nil attributes:nil];
}


- (void)readLiveStream{
    
    int nRead;
    
    BOOL bLiveStream = true;
    
    int bufsize = 1024 * 1024 * 10;
    char *buf = (char *)malloc(bufsize);
    
    memset(buf, 0, bufsize);
    
    long countbufsize = 0;
    
    char output_str_full[500] = {0};

    //把格式化的数据写入某个字符串中
    sprintf(output_str_full, "%s", [self.path UTF8String]);
    printf("output path: %s\n", output_str_full);
    FILE *fp = fopen(output_str_full, "wb");
    if (!fp) {
        RTMP_LogPrintf("Open Flie Error.\n");
        return;
    }
    
    //用于创建一个RTMP会话的句柄
    RTMP *rtmp = RTMP_Alloc();
    RTMP_Init(rtmp); //初始化句柄
    
    rtmp->Link.timeout = 20;
    
    //设置会话的参数
    if (!RTMP_SetupURL(rtmp, "rtmp://10.204.109.20:1935/live/room")) {
        RTMP_Log(RTMP_LOGERROR, "SetupURL Err\n");
        RTMP_Free(rtmp);
        return;
    }
    
    if (bLiveStream) {
        rtmp->Link.lFlags |= RTMP_LF_LIVE;
    }
    
    //1hour
    RTMP_SetBufferMS(rtmp, 3600 * 1000);
    
    
    //建立RTMP链接中的网络连接(NetConnection)
    if (!RTMP_Connect(rtmp, NULL)) {
        RTMP_Log(RTMP_LOGERROR, "connect err\n");
        RTMP_Free(rtmp);
        return;
    }
    
    //建立RTMP链接中的网络流(NetStream)
    if (!RTMP_ConnectStream(rtmp, 0)) {
        RTMP_Log(RTMP_LOGERROR, "connect stream Err\n");
        RTMP_Close(rtmp);
        RTMP_Free(rtmp);
        return;
    }
    
    while (YES) {
        //读取RTMP流的内容   当返回0字节的时候，代表流已经读取完毕
        nRead = RTMP_Read(rtmp, buf, bufsize);
        if (nRead) {
            
            NSData *data = [NSData dataWithBytes:buf length:nRead];
            
            fwrite(buf, 1, nRead, fp);
            countbufsize += nRead;
            RTMP_LogPrintf("Receive: %5dByte, Total: %5.2fkB\n",nRead,countbufsize*1.0/1024);
            
            
            packetBuffer = (uint8_t *)data.bytes;
            packetSize = (long)nRead;
            
            [self updateFrame];
            
        } else {
            break;
        }
    }
    
    fclose(fp);
    
    if (buf) {
        free(buf);
    }
    
    RTMP_Close(rtmp);
    RTMP_Free(rtmp); //清理会话
    rtmp = NULL;
    RTMP_LogPrintf("End\n");
}


- (IBAction)send:(id)sender {
   // [self readLiveStream];
    [self.rtmpSession connect];
}

- (NSFileManager *)fileManager{
    if (!_fileManager) {
        _fileManager = [NSFileManager defaultManager];
    }
    return _fileManager;
}

- (void)updateFrame{
    dispatch_sync(mDecodeQueue, ^{
        if (self->packetBuffer == NULL) {
            return;
        }
        
        uint8_t avcType = self->packetBuffer[0];
        long totalLength = self->packetSize;
        
        while (avcType == 0x17 || avcType == 0x27) {
            uint8_t type = self->packetBuffer[1];
            if (type == 0) {
                //获取sps
                int number_sps = 11;
                int count_sps = 1;
                int spsTotalLen = 0;
                uint8_t *spsTmp;
                {
                    int spslen = (self->packetBuffer[number_sps] & 0x000000FF) << 8 | (self->packetBuffer[number_sps + 1] & 0x000000FF);
                    number_sps += 2;
                    
                    spsTmp = malloc(spslen + 4);
                    memcpy(spsTmp, lyStartCode, 4);
                    spsTotalLen += 4;
                    
                    memcpy(spsTmp + 4, self->packetBuffer + number_sps, spslen);
                    spsTotalLen += spslen;
                    
                    number_sps += spslen;
                    
                    totalLength -= number_sps;
                    count_sps ++;
                }
                
                [self decodeNalu:spsTmp withSize:spsTotalLen];
                
                self->packetBuffer += number_sps + 1;
                
                //获取pps
                int number_pps = 0;
                int count_pps = 1;
                int ppsTotalLen = 0;
                uint8_t *ppsTmp;
                {
                    int ppslen = (self->packetBuffer[number_pps] & 0x000000FF) << 8 | (self->packetBuffer[number_pps + 1] & 0x000000FF);
                    number_pps += 2;
                    
                    ppsTmp = malloc(ppslen + 4);
                    memcpy(ppsTmp, lyStartCode, 4);
                    ppsTotalLen += 4;
                    
                    memcpy(ppsTmp + 4, self->packetBuffer + number_pps, ppslen);
                    ppsTotalLen += ppslen;
                    number_pps += ppslen;
                    
                    totalLength -= number_pps;
                    count_pps ++;
                }
                [self decodeNalu:ppsTmp withSize:ppsTotalLen];
                
                
                self->packetBuffer += number_pps;
                avcType = self->packetBuffer[0];
                
            } else if (type == 1) {
                
                BOOL isNalu = YES;
                
                //获取AVC NALU
                int len = 0;
                int num = 5;
                int naluTotalLen = 0;
                
                while (isNalu) {
                    len = (self->packetBuffer[num] & 0x000000FF) << 24 | (self->packetBuffer[num + 1] & 0x000000FF) << 16 | (self->packetBuffer[num + 2] & 0x000000FF) << 8 | (self->packetBuffer[num + 3] & 0x000000FF);
                    
                    self->naluBuffer = malloc(len + 4);
                    naluTotalLen += 4;
                    naluTotalLen += len;
                    
                    memcpy(self->naluBuffer, self->packetBuffer + num, len + 4);
                    
                    num = num + len + 4;
                    totalLength -= num;
                    
                    [self decodeNalu:self->naluBuffer withSize:naluTotalLen];
                    
                    self->packetBuffer += num;
                    num = 0;
                    naluTotalLen = 0;
                    free(self->naluBuffer);
                    
                    //可能存在下一个NALU
                    if (totalLength > 4) {
                        avcType = self->packetBuffer[0];
                        if (avcType == 0x17 || avcType == 0x27) {
                            isNalu = NO;
                        } else {
                            len = (self->packetBuffer[num] & 0x000000FF) << 24 | (self->packetBuffer[num + 1] & 0x000000FF) << 16 | (self->packetBuffer[num + 2] & 0x000000FF) << 8 | (self->packetBuffer[num + 3] & 0x000000FF);
                            if (len >= (totalLength - 4)) {
                                return;
                            }
                        }
                    }else{
                        return;
                    }
                }
            }
        }
    });
}

- (void)decodeNalu:(uint8_t *)frame withSize:(uint32_t)frameSize{
    //开始解码
    int nalu_type = frame[4] & 0x1F;
    CVPixelBufferRef pixelBuffer = NULL;
    
    //传输的时候，关键帧不能丢数据 否则绿屏 B/P可以丢这样会卡顿
    switch (nalu_type) {
        case 0x05:{ //关键帧
            uint32_t dataLength32 = htonl(frameSize - 4);
            memcpy(frame, &dataLength32, sizeof(uint32_t));
            [self initVideoToolBox];
            
            pixelBuffer = [self decode:frame withSize:frameSize];
            [self displayDecodedFrame:pixelBuffer];
        }
            break;
            
        case 0x07:{ //sps
            mSPSSize = frameSize - 4;
            mSPS = malloc(mSPSSize);
            memcpy(mSPS, frame + 4, mSPSSize);
        }
            break;
        case 0x08:{ //pps
            mPPSSize = frameSize - 4;
            mPPS = malloc(mPPSSize);
            memcpy(mPPS, frame + 4, mPPSSize);
        }
            break;
        default:{
            uint32_t dataLength32 = htonl(frameSize - 4);
            memcpy(frame, &dataLength32, sizeof(uint32_t));
            [self initVideoToolBox];
            pixelBuffer = [self decode:frame withSize:frameSize];
            [self displayDecodedFrame:pixelBuffer];
        }
            break;
    }
    
}

- (void)initVideoToolBox{
    if (!mDecodeSession) {
        const uint8_t *parameterSetPointers[2] = {mSPS, mPPS};
        const size_t parameterSetSizes[2] = {mSPSSize, mPPSSize};
        
        OSStatus status = CMVideoFormatDescriptionCreateFromH264ParameterSets(kCFAllocatorDefault,
                                                                              2,
                                                                              parameterSetPointers,
                                                                              parameterSetSizes,
                                                                              4,
                                                                              &mFormatDescription);
        
        if (status == noErr) {
            CFDictionaryRef attrs = NULL;
            const void *keys[] = {kCVPixelBufferPixelFormatTypeKey};
            
            uint32_t v = kCVPixelFormatType_420YpCbCr8PlanarFullRange;
            const void *values[] = {CFNumberCreate(NULL, kCFNumberSInt32Type, &v)};
            
            attrs = CFDictionaryCreate(NULL, keys, values, 1, NULL, NULL);
            
            VTDecompressionOutputCallbackRecord callBackRecord;
            callBackRecord.decompressionOutputCallback = didDecompress;
            callBackRecord.decompressionOutputRefCon = (__bridge void *)self;
            status = VTDecompressionSessionCreate(kCFAllocatorDefault,
                                                  mFormatDescription,
                                                  NULL,
                                                  attrs,
                                                  &callBackRecord,
                                                  &mDecodeSession);
            CFRelease(attrs);
        } else {
            NSLog(@"IOS8VT: reset decoder session failed status=%d", status);
        }
    }
}

void didDecompress(void *decompressionOutputRefCon, void *sourceFrameRefCon, OSStatus status, VTDecodeInfoFlags infoFlags, CVImageBufferRef pixelBuffer, CMTime presentationTimeStamp, CMTime presentationDuration) {
    CVPixelBufferRef *outputPixelBuffer = (CVPixelBufferRef *)sourceFrameRefCon;
    *outputPixelBuffer = CVPixelBufferRetain(pixelBuffer);
}


- (CVPixelBufferRef)decode:(uint8_t *)frame withSize:(uint32_t)frameSize{
    if (!mDecodeSession) {
        return nil;
    }
    
    CVPixelBufferRef outputPixbuffer = NULL;
    
    CMBlockBufferRef blockBuffer = NULL;
    OSStatus status = CMBlockBufferCreateWithMemoryBlock(NULL,
                                                         (void *)frame,
                                                         frameSize,
                                                         kCFAllocatorNull,
                                                         NULL,
                                                         0,
                                                         frameSize,
                                                         FALSE,
                                                         &blockBuffer);
    
    if (status == kCMBlockBufferNoErr) {
        CMSampleBufferRef sampleBuffer = NULL;
        const size_t sampleSizeArray[] = {frameSize};
        status = CMSampleBufferCreateReady(kCFAllocatorDefault,
                                           blockBuffer,
                                           mFormatDescription,
                                           1,
                                           0,
                                           NULL,
                                           1,
                                           sampleSizeArray,
                                           &sampleBuffer);
        
        
        if (status == kCMBlockBufferNoErr && sampleBuffer) {
            VTDecodeFrameFlags flags = 0;
            VTDecodeInfoFlags flagOut = 0;
            OSStatus decodeStatus = VTDecompressionSessionDecodeFrame(mDecodeSession,
                                                                      sampleBuffer,
                                                                      flags,
                                                                      &outputPixbuffer,
                                                                      &flagOut);
            
            if(decodeStatus == kVTInvalidSessionErr) {
                NSLog(@"IOS8VT: Invalid session, reset decoder session");
            } else if(decodeStatus == kVTVideoDecoderBadDataErr) {
                NSLog(@"IOS8VT: decode failed status=%d(Bad data)", decodeStatus);
            } else if(decodeStatus != noErr) {
                NSLog(@"IOS8VT: decode failed status=%d", decodeStatus);
            }
            CFRelease(sampleBuffer);
        }
        CFRelease(blockBuffer);
    }
    
    return outputPixbuffer;
}


- (void)displayDecodedFrame:(CVPixelBufferRef)imageBuffer{
    if (imageBuffer) {
        self.eaglLayer.pixelBuffer = imageBuffer;
        CVPixelBufferRelease(imageBuffer);
    }
}


#pragma mark -- BLRtmpSessionDelegate
- (void)rtmpSession:(BLRtmpSession *)rtmpSession didChangeStatus:(LLYRtmpSessionStatus)rtmpstatus{
    
}

- (void)rtmpSession:(BLRtmpSession *)rtmpSession receiveVideoData:(uint8_t *)data length:(int)length{
    packetBuffer = data;
    packetSize = length;
    [self updateFrame];
}


- (BLRtmpSession *)rtmpSession{
    if (!_rtmpSession) {
        _rtmpSession = [[BLRtmpSession alloc] init];
        _rtmpSession.delegate = self;
        
        BLRtmpConfig *config = [[BLRtmpConfig alloc] init];
        config.url = @"rtmp://10.204.109.20:1935/live/room";
        config.width = 480;
        config.height = 640;
        config.frameDuration = 1.0 / 30;
        config.videoBitrate = 512 *1024;
        
        _rtmpSession.config = config;
    }
    return _rtmpSession;
}

@end
