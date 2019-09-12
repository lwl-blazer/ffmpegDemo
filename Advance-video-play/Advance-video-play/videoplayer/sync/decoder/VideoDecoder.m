//
//  VideoDecoder.m
//  Advance-video-play
//
//  Created by luowailin on 2019/9/11.
//  Copyright © 2019 luowailin. All rights reserved.
//

#import "VideoDecoder.h"
#import <Accelerate/Accelerate.h>

static NSData *copyFrameData(UInt8 *src, int linesize, int width, int height) {
    width = MIN(linesize, width);
    NSMutableData *md = [NSMutableData dataWithLength:width * height];
    Byte *dst = md.mutableBytes;
    for (NSUInteger i = 0; i < height; ++i) {
        memcpy(dst, src, width);
        dst += width;
        src += linesize;
    }
    return md;
}

static void avStreamFPSTimeBase(AVStream *st, CGFloat defaultTimeBase, CGFloat *pFPS, CGFloat *pTimeBase) {
    CGFloat fps, timebase;
    
    if (st->time_base.den && st->time_base.num) {
        timebase = av_q2d(st->time_base);
    } else if (st->codec->time_base.den && st->codec->time_base.num) {
        timebase = av_q2d(st->codec->time_base);
    } else {
        timebase = defaultTimeBase;
    }
    
    if (st->codec->ticks_per_frame != 1) {
        NSLog(@"WARNING: st.codec.ticks_per_frame=%d", st->codec->ticks_per_frame);
    }
    
    if (st->avg_frame_rate.den && st->avg_frame_rate.num) {
        fps = av_q2d(st->avg_frame_rate);
    } else if (st->r_frame_rate.den && st->r_frame_rate.num) {
        fps = av_q2d(st->r_frame_rate);
    } else {
        fps = 1.0 / timebase;
    }
    
    
    if (pFPS) {
        *pFPS = fps;
    }
    
    if (pTimeBase) {
        *pTimeBase = timebase;
    }
    
}

static NSArray *collectStreams(AVFormatContext *formatCtx, enum AVMediaType codecType) {
    NSMutableArray *ma = [NSMutableArray array];
    for (NSInteger i = 0; i < formatCtx->nb_streams; ++i) {
        if (codecType == formatCtx->streams[i]->codec->codec_type) {
            [ma addObject:[NSNumber numberWithInteger:i]];
        }
    }
    return [ma copy];
}

@implementation Frame

@end

@implementation AudioFrame

@end

@implementation VideoFrame

@end

@implementation BuriedPoint

@end


@interface VideoDecoder ()
{
    AVFrame *_videoFrame;
    AVFrame *_audioFrame;
    
    CGFloat _fps;
    
    CGFloat _decodePosition;
    
    BOOL _isSubscribe;
    BOOL _isEOF;
    
    SwrContext *_swrContext;
    void *_swrBuffer;
    NSUInteger _swrBufferSize;
    
    AVPicture _picture;
    BOOL _pictureValid;
    struct SwsContext *_swsContext;
    
    int _subscribeTimeOutTimeInSecs;
    int _readLastestFrameTime;
    
    BOOL _interrupted;
    
    int _connectionRetry;
}

@end

@implementation VideoDecoder

static int interrupt_callback(void *ctx){
    if (!ctx) {
        return 0;
    }
    
    __unsafe_unretained VideoDecoder *p = (__bridge VideoDecoder *)ctx;
    const BOOL r = [p detectInterrupted];
    if (r) {
        NSLog(@"DEBUG: INTERRUPT_CALLBACK");
    }
    return r;
}

- (void)interrupt{
    _subscribeTimeOutTimeInSecs = -1;
    _interrupted = YES;
    _isSubscribe = NO;
}

- (BOOL)detectInterrupted{
    if ([[NSDate date] timeIntervalSince1970] - _readLastestFrameTime > _subscribeTimeOutTimeInSecs) {
        return YES;
    }
    
    return _interrupted;
}

- (BOOL)openFile:(NSString *)path parameter:(NSDictionary *)parameters error:(NSError * _Nullable __autoreleasing *)perror{
    BOOL ret = YES;
    
    if (path == nil) {
        return NO;
    }
    
    _connectionRetry = 0;
    totalVideoFramecount = 0;
    _subscribeTimeOutTimeInSecs = SUBSCRIBE_VIDEO_DATA_TIME_OUT;
    _interrupted = NO;
    _isOpenInputSuccess = NO;
    _isSubscribe = YES;
    
    _buriedPoint = [[BuriedPoint alloc] init];
    _buriedPoint.bufferStatusRecords = [[NSMutableArray alloc] init];
    _readLastestFrameTime = [[NSDate date] timeIntervalSince1970];
    
    avformat_network_init();
    av_register_all();
    _buriedPoint.beginOpen = [[NSDate date] timeIntervalSince1970] * 1000;
    int openInputErrCode = [self openInput:path parameter:parameters];
    if (openInputErrCode > 0) {
        _buriedPoint.successOpen = ([[NSDate date] timeIntervalSince1970] * 1000 - _buriedPoint.beginOpen) / 1000.0;
        _buriedPoint.failOpen = 0.0f;
        _buriedPoint.failOpenType = 1;
        
        BOOL openVideoStataus = [self openVideoStream];
        BOOL openAudioStatus = [self openAudioStream];
        
        if (!openVideoStataus || !openAudioStatus) {
            [self closeFile];
            ret = NO;
        }
    } else {
        _buriedPoint.failOpen = ([[NSDate date] timeIntervalSince1970] * 1000 - _buriedPoint.beginOpen) / 1000.0;
        _buriedPoint.successOpen = 0.0f;
        _buriedPoint.failOpenType = openInputErrCode;
        ret = NO;
    }
    
    _buriedPoint.retryTimes = _connectionRetry;
    if (ret) {
        NSInteger videoWidth = [self frameWidth];
        NSInteger videoHeight = [self frameHeight];
        int retryTimes = 5;
        while ((videoWidth <= 0 || videoHeight <= 0) && retryTimes > 0) {
            NSLog(@"because of videowidth and videoHeight is Zero we will retry...");
            usleep(500 * 1000);
            _connectionRetry = 0;
            ret = [self openFile:path parameter:parameters error:perror];
            if (!ret) {
                //如果打开失败，则退出
                break;
            }
            retryTimes --;
            videoHeight = [self frameWidth];
            videoHeight = [self frameHeight];
        }
    }
    
    _isOpenInputSuccess = ret;
    return ret;
}

- (BOOL)isOpenInputSuccess{
    return _isOpenInputSuccess;
}

- (BOOL)openVideoStream{
    _videoStreamIndex = -1;
    _videoStreams = collectStreams(_formatCtx, AVMEDIA_TYPE_VIDEO);
    for (NSNumber *n in _videoStreams) {
        const NSUInteger iStream = n.integerValue;
        AVCodecContext *codecCtx = _formatCtx->streams[iStream]->codec;
        AVCodec *codec = avcodec_find_decoder(codecCtx->codec_id);
        if (!codec) {
            return NO;
        }
        
        int openCodecErrCode = 0;
        if ((openCodecErrCode = avcodec_open2(codecCtx, codec, NULL)) < 0) {
            NSLog(@"open video codec failed openCodecErr is %s", av_err2str(openCodecErrCode));
            return NO;
        }
        
        _videoFrame = avcodec_alloc_frame();
        if (!_videoFrame) {
            NSLog(@"Alloc Video Frame failed...");
            avcodec_close(codecCtx);
            return NO;
        }
        
        _videoStreamIndex = iStream;
        _videoCodecCtx = codecCtx;
        
        AVStream *st = _formatCtx->streams[_videoStreamIndex];
        avStreamFPSTimeBase(st, 0.04, &_fps, &_videoTimeBase);
        break;
    }
    return YES;
}

- (BOOL)openAudioStream{
    _audioStreamIndex = -1;
    _audioStreams = collectStreams(_formatCtx, AVMEDIA_TYPE_AUDIO);
    for (NSNumber *n in _audioStreams) {
        const NSUInteger iStream = [n integerValue];
        AVCodecContext *codecCtx = _formatCtx->streams[iStream]->codec;
        AVCodec *codec = avcodec_find_decoder(codecCtx->codec_id);
        if (!codec) {
            NSLog(@"Find Audio Decoder Failed codec_id %d CODEC_ID_AAC is %d", codecCtx->codec_id, AV_CODEC_ID_AAC);
            return NO;
        }
        
        int openCodecErrCode = 0;
        if ((openCodecErrCode = avcodec_open2(codecCtx, codec, NULL)) < 0) {
            NSLog(@"Open Audio Codec Failed openCodecErr is %s", av_err2str(openCodecErrCode));
            return NO;
        }
        
        
        SwrContext *swrContext = NULL;
        if (![self audioCodecIsSupported:codecCtx]) {
            NSLog(@"because of audio Codec is Not Supported so we will init swresampler...");
            
            swrContext = swr_alloc_set_opts(NULL,
                                            av_get_default_channel_layout(codecCtx->channels),
                                            AV_SAMPLE_FMT_S16,
                                            codecCtx->sample_rate,
                                            av_get_default_channel_layout(codecCtx->channels),
                                            codecCtx->sample_fmt,
                                            codecCtx->sample_rate,
                                            0,
                                            NULL);
            
            if (!swrContext || swr_init(swrContext)) {
                if (swrContext) {
                    swr_free(&swrContext);
                }
                
                avcodec_close(codecCtx);
                NSLog(@"init resampler failed...");
                return NO;
            }
            
            _audioFrame = avcodec_alloc_frame();
            if (!_audioFrame) {
                NSLog(@"Alloc Audio Frame Failed...");
                if (swrContext) {
                    swr_free(&swrContext);
                }
                avcodec_close(codecCtx);
                return NO;
            }
            
            _audioStreamIndex = iStream;
            _audioCondecCtx = codecCtx;
            _swrContext = swrContext;
            
            AVStream *st = _formatCtx->streams[_audioStreamIndex];
            avStreamFPSTimeBase(st, 0.025, 0, &_audioTimeBase);
            break;
        }
    }
    return YES;
}

- (BOOL)audioCodecIsSupported:(AVCodecContext *)audioCodecCtx{
    if (audioCodecCtx->sample_fmt == AV_SAMPLE_FMT_S16) {
        return YES;
    }
    return NO;
}


- (int)openInput:(NSString *)path parameter:(NSDictionary *)parameters{
    AVFormatContext *formatCtx = avformat_alloc_context();
    AVIOInterruptCB int_cb = {interrupt_callback, (__bridge void *)(self)};
    formatCtx->interrupt_callback = int_cb;
    int openInputErrCode = 0;
    if ((openInputErrCode = [self openFormatInput:&formatCtx path:path parameter:parameters]) != 0) {
        NSLog(@"Video decoder open input file failed... videoSourceURI is %@ openInputErr is %s", path, av_err2str(openInputErrCode));
        if (formatCtx) {
            avformat_free_context(formatCtx);
        }
        return openInputErrCode;
    }
    [self initAnalyzeDurationAndProbesize:formatCtx parameter:parameters];
    int findStreamErrCode = 0;
    double startFindStreamTimeMills = CFAbsoluteTimeGetCurrent() * 1000;
    if ((findStreamErrCode = avformat_find_stream_info(formatCtx, NULL)) < 0) {
        avformat_close_input(&formatCtx);
        avformat_free_context(formatCtx);
        
        NSLog(@"Video decoder find stream info failed... find stream ErrCode is %s", av_err2str(findStreamErrCode));
        
        return findStreamErrCode;
    }
    
    int wasteTimeMills = CFAbsoluteTimeGetCurrent() * 1000 - startFindStreamTimeMills;
    NSLog(@"Find stream info waste TimeMills is %d", wasteTimeMills);
    
    if (formatCtx->streams[0]->codec->codec_id == AV_CODEC_ID_NONE) {
        avformat_close_input(&formatCtx);
        avformat_free_context(formatCtx);
        
        NSLog(@"Video decoder First Stream Codec ID is UnKnown...");
        if ([self isNeedRetry]) {
            return [self openInput:path parameter:parameters];
        } else {
            return -1;
        }
    }
    _formatCtx = formatCtx;
    return 1;
}

- (int)openFormatInput:(AVFormatContext **)formatCtx path:(NSString *)path parameter:(NSDictionary *)parameters{
    
    const char *videoSourceURI = [path cStringUsingEncoding:NSUTF8StringEncoding];
    AVDictionary *options = NULL;
    NSString *rtmpTcurl = parameters[RTM_TCURL_KEY];
    if ([rtmpTcurl length] > 0) {
        const char *rtmp_tcurl = [rtmpTcurl cStringUsingEncoding:NSUTF8StringEncoding];
        av_dict_set(&options, "rtm_tcurl", rtmp_tcurl, 0);
    }
    return avformat_open_input(formatCtx, videoSourceURI, NULL, &options);
}

- (void)initAnalyzeDurationAndProbesize:(AVFormatContext *)formatCtx parameter:(NSDictionary *)parameters{
    float probeSize = [parameters[PROBE_SIZE] floatValue];
    formatCtx->probesize = probeSize ? 0: 50 * 1024;
    NSArray *durations = parameters[MAX_ANALYZE_DURATION_ARRAY];
    if (durations && durations.count > _connectionRetry) {
        formatCtx->max_analyze_duration = [durations[_connectionRetry] floatValue];
    } else {
        float multiplier = 0.5 + (double)pow(2.0, (double)_connectionRetry) * 0.25;
        formatCtx->max_analyze_duration = multiplier * AV_TIME_BASE;
    }
    
    BOOL fpsProbeSizeConfiged = [parameters[FPS_PROBE_SIZE_CONFIGURED] boolValue];
    if (fpsProbeSizeConfiged) {
        formatCtx->fps_probe_size = 3;
    }
}

- (BOOL)isNeedRetry{
    _connectionRetry ++;
    return _connectionRetry <= NET_WORK_STREAM_RETRY_TIME;
}

- (VideoFrame *)decodeVideo:(AVPacket)packet packetSize:(int)pktSize decodeVideoErrorState:(int *)decodeVideoErrorState{
    VideoFrame *frame = nil;
    while (pktSize > 0) {
        int gotframe = 0;
        int len = avcodec_decode_video2(_videoCodecCtx,
                                        _videoFrame,
                                        &gotframe,
                                        &packet);
        
        if (len < 0) {
            NSLog(@"decode video error, skip packet %s", av_err2str(len));
            *decodeVideoErrorState = 1;
            break;
        }
        
        if (gotframe) {
            frame = [self handleVideoFrame];
        }
        
        if (len == 0) {
            break;
        }
        pktSize -= len;
    }
    return frame;
}

- (NSArray *)decodeFrames:(CGFloat)minDuration decodeVideoErrorState:(int *)decodeVideoErrorState{
    if (_videoStreamIndex == -1 && _audioStreamIndex == -1) {
        return nil;
    }
    
    NSMutableArray *result = [NSMutableArray array];
    AVPacket packet;
    CGFloat decodeDuration = 0;
    BOOL finished = NO;
    while (!finished) {
        if (av_read_frame(_formatCtx, &packet) < 0) {
            _isEOF = YES;
            break;
        }
        
        int pktSize = packet.size;
        int pktStreamIndex = packet.stream_index;
        if (pktStreamIndex == _videoStreamIndex) {
            double startDecodeTimeMills = CFAbsoluteTimeGetCurrent() * 1000;
            VideoFrame *frame = [self decodeVideo:packet
                                       packetSize:pktSize
                            decodeVideoErrorState:decodeVideoErrorState];
            int wasteTimeMills = CFAbsoluteTimeGetCurrent() * 1000 - startDecodeTimeMills;
            decodeVideoFrameWasteTimeMills += wasteTimeMills;
            if (frame) {
                totalVideoFramecount ++;
                [result addObject:frame];
                
                decodeDuration += frame.duration;
                if (decodeDuration > minDuration) {
                    finished = YES;
                }
            }
        } else if (pktStreamIndex == _audioStreamIndex) {
            while (pktSize > 0) {
                int gotframe = 0;
                int len = avcodec_decode_audio4(_audioCondecCtx,
                                                _audioFrame,
                                                &gotframe,
                                                &packet);
                
                if (len < 0) {
                    NSLog(@"decode audio error, skip packet");
                    break;
                }
                
                if (gotframe) {
                    AudioFrame *frame = [self handleAudioFrame];
                    if (frame) {
                        [result addObject:frame];
                        if (_videoStreamIndex == -1;) {
                            _decodePosition = frame.position;
                            decodeDuration += frame.duration;
                            if (decodeDuration > minDuration) {
                                finished = YES;
                            }
                        }
                    }
                }
                
                if (len == 0) {
                    break;
                }
                pktSize -= len;
            }
        } else {
            NSLog(@"We Can Not Process Stream Except Audio And Video Stream...");
        }
        av_free_packet(&packet);
    }
    
    _readLastestFrameTime = [[NSDate date] timeIntervalSince1970];
    return result;
}

- (BuriedPoint *)getBuriedPoint{
    return _buriedPoint;
}

- (VideoFrame *)handleVideoFrame{
    
}

- (AudioFrame *)handleAudioFrame{
    
}

@end
