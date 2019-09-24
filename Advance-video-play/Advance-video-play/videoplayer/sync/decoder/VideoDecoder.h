//
//  VideoDecoder.h
//  Advance-video-play
//
//  Created by luowailin on 2019/9/11.
//  Copyright © 2019 luowailin. All rights reserved.
//

#import <Foundation/Foundation.h>
#import <CoreGraphics/CoreGraphics.h>
#import <CoreVideo/CoreVideo.h>

#import <libavutil/pixdesc.h>
#import <libavutil/frame.h>
#import <libavformat/avformat.h>
#import <libavcodec/avcodec.h>
#import <libswscale/swscale.h>
#import <libswresample/swresample.h>

typedef enum {
    AudioFrameType,
    VideoFrameType,
    iOSCVVideoFrameType
} FrameType;

NS_ASSUME_NONNULL_BEGIN

@interface BuriedPoint : NSObject

//开始试图去打开一个直播流的绝对时间
@property(readwrite, nonatomic, assign) long long beginOpen;

//成功打开流花费时间
@property(readwrite, nonatomic, assign) float successOpen;

//首屏时间
@property(readwrite, nonatomic, assign) float firstScreenTimeMills;

//流打开失败花费时间
@property(readwrite, nonatomic, assign) float failOpen;

//流打开失败类型
@property(readwrite, nonatomic, assign) float failOpenType;

//打开流重试次数
@property(readwrite, nonatomic, assign) int retryTimes;

//拉流时长
@property(readwrite, nonatomic, assign) float duration;

//拉流状态
@property(readwrite, nonatomic, strong) NSMutableArray *bufferStatusRecords;

@end


@interface Frame : NSObject

@property(nonatomic, readwrite, assign) FrameType type;
@property(nonatomic, readwrite, assign) CGFloat position;
@property(nonatomic, readwrite, assign) CGFloat duration;

@end

@interface AudioFrame : Frame

@property(nonatomic, readwrite, strong) NSData *samples;

@end


@interface VideoFrame : Frame

@property(nonatomic, readwrite, assign) NSUInteger width;
@property(nonatomic, readwrite, assign) NSUInteger height;
@property(nonatomic, readwrite, assign) NSUInteger linesize;

@property(nonatomic, readwrite, strong) NSData *luma;
@property(nonatomic, readwrite, strong) NSData *chromaB;
@property(nonatomic, readwrite, strong) NSData *chromaR;
@property(nonatomic, readwrite, strong) id imageBuffer;

@end

#ifndef SUBSCRIBE_VIDEO_DATA_TIME_OUT
#define SUBSCRIBE_VIDEO_DATA_TIME_OUT 20
#endif

#ifndef NET_WORK_STREAM_RETRY_TIME
#define NET_WORK_STREAM_RETRY_TIME 3
#endif

#ifndef RTM_TCURL_KEY
#define RTM_TCURL_KEY @"RTMP_TCURL_KEY"
#endif

#ifndef FPS_PROBE_SIZE_CONFIGURED
#define FPS_PROBE_SIZE_CONFIGURED @"FPS_PROBE_SIZE_CONFIGURED"
#endif

#ifndef PROBE_SIZE
#define PROBE_SIZE @"PROBE_SIZE"
#endif

#ifndef MAX_ANALYZE_DURATION_ARRAY
#define MAX_ANALYZE_DURATION_ARRAY @"MAX_ANALYZE_DURATION_ARRAY"
#endif


@interface VideoDecoder : NSObject
{
    AVFormatContext *_formatCtx;
    BOOL _isOpenInputSuccess;
    
    BuriedPoint *_buriedPoint;
    
    int totalVideoFramecount;
    long long decodeVideoFrameWasteTimeMills;
    
    NSArray *_videoStreams;
    NSArray *_audioStreams;
    NSInteger _videoStreamIndex;
    NSInteger _audioStreamIndex;
    AVCodecContext *_videoCodecCtx;
    AVCodecContext *_audioCondecCtx;
    
    CGFloat _videoTimeBase;
    CGFloat _audioTimeBase;
}

- (BOOL)openFile:(NSString *)path
       parameter:(NSDictionary *)parameters
           error:(NSError **)perror;

- (NSArray *)decodeFrames:(CGFloat)minDuration
    decodeVideoErrorState:(int *)decodeVideoErrorState;

/**子类重写这两个方法*/
- (BOOL)openVideoStream;
- (void)closeVideoStream;

- (VideoFrame *)decodeVideo:(AVPacket)packet
                 packetSize:(int)pktSize
      decodeVideoErrorState:(int *)decodeVideoErrorState;

- (void)closeFile;

- (void)interrupt;

- (BOOL)isOpenInputSuccess;

- (void)triggerFirstScreen;
- (void)addBufferStatusRecord:(NSString *)statusFlag;

- (BuriedPoint *)getBuriedPoint;

- (BOOL)detectInterrupted;
- (BOOL)isEOF;
- (BOOL)isSubscribed;

- (NSUInteger)frameWidth;
- (NSUInteger)frameHeight;
- (CGFloat)sampleRate;
- (NSUInteger)channels;
- (BOOL)validVideo;
- (BOOL)validAudio;

- (CGFloat)getVideoFPS;
- (CGFloat)getDuration;

@end

NS_ASSUME_NONNULL_END
