//
//  VideoDecoder.m
//  Advance-video-play
//
//  Created by luowailin on 2019/9/11.
//  Copyright © 2019 luowailin. All rights reserved.
//

#import "VideoDecoder.h"
#import <Accelerate/Accelerate.h>

static NSData *copyFrameData(UInt8 *src, int linesize, int width, int height) { //从AVFrame中copy出数据
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

/*
//计算 timeBase 和 fps
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
    
    //avg_frame_rate,r_frame_rate 都是视频的帧率 优先获取avg_frame_rate
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
*/

//计算 timeBase 和 fps
static void avStreamFPSTimeBase2(AVStream *st,
                                 AVCodecContext *codecContext,
                                 CGFloat defaultTimeBase,
                                 CGFloat *pFPS,
                                 CGFloat *pTimeBase) {
    CGFloat timebase;
    if (st->time_base.den && st->time_base.num) {
        timebase = av_q2d(st->time_base);
    } else if (codecContext->time_base.den && codecContext->time_base.num) {
        timebase = av_q2d(codecContext->time_base);
    } else {
        timebase = defaultTimeBase;
    }
    
    if (codecContext->ticks_per_frame != 1) {
        NSLog(@"WARNING: st.codec.ticks_per_frame=%d", codecContext->ticks_per_frame);
    }
    
    if (pFPS != NULL) {
        CGFloat fps;
        if (st->avg_frame_rate.den && st->avg_frame_rate.num) {
            fps = av_q2d(st->avg_frame_rate);
        } else if (st->r_frame_rate.den && st->r_frame_rate.num) {
            fps = av_q2d(st->r_frame_rate);
        } else {
            fps = 1.0 / timebase;
        }
        
        *pFPS = fps;
    }
    
    if (pTimeBase) {
        *pTimeBase = timebase;
    }
}




static NSArray *collectStreams(AVFormatContext *formatCtx, enum AVMediaType codecType) {
    NSMutableArray *ma = [NSMutableArray array];
    for (NSInteger i = 0; i < formatCtx->nb_streams; ++i) {
        if (codecType == formatCtx->streams[i]->codecpar->codec_type) {
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
    
    
    struct SwsContext *_swsContext;
    
    int _subscribeTimeOutTimeInSecs;
    int _readLastestFrameTime;
    
    BOOL _interrupted;
    
    int _connectionRetry;
    /*
    AVPicture _picture;
    BOOL _pictureValid;*/
}

@end

@implementation VideoDecoder

static int interrupt_callback(void *ctx){
    if (!ctx) {
        return 0;
    }
    
    /**__unsafe_unretained 和 weak是一样的，唯一的区别是对象被销毁时，指针也不会置空，此时指针指向是一个无用的野指针，如果再使用的话报'BAD_ACCESS'异常*/
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

- (BOOL)openFile:(NSString *)path
       parameter:(NSDictionary *)parameters
           error:(NSError * _Nullable __autoreleasing *)perror{
    
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
        /** 在网络的播放器中有可能拉到长宽都为0 并且Pix_fmt是None的流 这个时候我们需要重连(重连5次 retryTimes = 5) */
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
    for (NSNumber *n in _videoStreams) { //
        const NSUInteger iStream = n.integerValue;
        
        AVCodecContext *codecCtx = avcodec_alloc_context3(NULL);
        avcodec_parameters_to_context(codecCtx, _formatCtx->streams[iStream]->codecpar);
        
        //1.查找解码器
        AVCodec *codec = avcodec_find_decoder(codecCtx->codec_id);
        if (!codec) {
            NSLog(@"Find Video Decoder Failed codec_id %d CODEC_ID_H264 is %d", codecCtx->codec_id, AV_CODEC_ID_H264);
            return NO;
        }
        
        //2.打开解码器
        int openCodecErrCode = 0;
        if ((openCodecErrCode = avcodec_open2(codecCtx, codec, NULL)) < 0) {
            NSLog(@"open video codec failed openCodecErr is %s", av_err2str(openCodecErrCode));
            avcodec_free_context(&codecCtx);
            return NO;
        }
        
        _videoFrame = av_frame_alloc();
        if (!_videoFrame) {
            NSLog(@"Alloc Video Frame failed...");
            avcodec_free_context(&codecCtx);
            return NO;
        }
        
        _videoStreamIndex = iStream;
        _videoCodecCtx = codecCtx;
        
        //确定/限定 fps
        AVStream *st = _formatCtx->streams[_videoStreamIndex];
//        avStreamFPSTimeBase(st, 0.04, &_fps, &_videoTimeBase);
        avStreamFPSTimeBase2(st, codecCtx, 0.04, &_fps, &_videoTimeBase);
        break;
    }
    return YES;
}

- (BOOL)openAudioStream{
    _audioStreamIndex = -1;
    _audioStreams = collectStreams(_formatCtx, AVMEDIA_TYPE_AUDIO);
    for (NSNumber *n in _audioStreams) {
        const NSUInteger iStream = [n integerValue];
        
       
        AVCodecContext *codecCtx = avcodec_alloc_context3(NULL);
        avcodec_parameters_to_context(codecCtx, _formatCtx->streams[iStream]->codecpar);
        AVCodec *codec = avcodec_find_decoder(codecCtx->codec_id);
        if (!codec) {
            NSLog(@"Find Audio Decoder Failed codec_id %d CODEC_ID_AAC is %d", codecCtx->codec_id, AV_CODEC_ID_AAC);
            return NO;
        }
        
        int openCodecErrCode = 0;
        if ((openCodecErrCode = avcodec_open2(codecCtx, codec, NULL)) < 0) {
            NSLog(@"Open Audio Codec Failed openCodecErr is %s", av_err2str(openCodecErrCode));
            avcodec_free_context(&codecCtx);
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
                
                NSLog(@"init resampler failed...");
                avcodec_free_context(&codecCtx);
                return NO;
            }
            
            _audioFrame = av_frame_alloc();
            if (!_audioFrame) {
                NSLog(@"Alloc Audio Frame Failed...");
                if (swrContext) {
                    swr_free(&swrContext);
                }
                avcodec_free_context(&codecCtx);
                return NO;
            }
            
            _audioStreamIndex = iStream;
            _audioCondecCtx = codecCtx;
            _swrContext = swrContext;
            
            AVStream *st = _formatCtx->streams[_audioStreamIndex];
            //avStreamFPSTimeBase(st, 0.025, 0, &_audioTimeBase);
            avStreamFPSTimeBase2(st, codecCtx, 0.025, NULL, &_audioTimeBase);
            break;
        }
    }
    return YES;
}

- (BOOL)audioCodecIsSupported:(AVCodecContext *)audioCodecCtx{
    if (audioCodecCtx->sample_fmt == AV_SAMPLE_FMT_S16) {
        return true;
    }
    return false;
}


- (int)openInput:(NSString *)path
       parameter:(NSDictionary *)parameters{
    
    AVFormatContext *formatCtx = avformat_alloc_context();
    
    //设置中断处理
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
    
    if (formatCtx->streams[0]->codecpar->codec_id == AV_CODEC_ID_NONE) {
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

//设置probesize,max_analyze_duration,fps_probe_size 用到决定avformat_find_stream_info()读取的数据量
- (void)initAnalyzeDurationAndProbesize:(AVFormatContext *)formatCtx parameter:(NSDictionary *)parameters{
    float probeSize = [parameters[PROBE_SIZE] floatValue];
    
    //人输入中读取的数据的最大大小
    formatCtx->probesize = probeSize ?: 50 * 1024;
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

- (VideoFrame *)decodeVideo:(AVPacket)packet
                 packetSize:(int)pktSize
      decodeVideoErrorState:(int *)decodeVideoErrorState{
    VideoFrame *frame = nil;
    
    int len = avcodec_send_packet(_videoCodecCtx, &packet);
    if (len < 0) {
        NSLog(@"decode video error, skip packet %s", av_err2str(len));
        *decodeVideoErrorState = 1;
        return frame;
    }
    
    //为什么要用while:特别是音频的话，有可能出现一个AVPacket里多个AVFrame
    while (avcodec_receive_frame(_videoCodecCtx, _videoFrame) >= 0) {
        frame = [self handleVideoFrame];
    }
    
    /*
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
    }*/
    return frame;
}

- (NSArray *)decodeFrames:(CGFloat)minDuration
    decodeVideoErrorState:(int *)decodeVideoErrorState{
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
            int len = avcodec_send_packet(_audioCondecCtx, &packet);
            if (len < 0) {
                NSLog(@"decode audio error, skip packet");
            } else {
                while (avcodec_receive_frame(_audioCondecCtx, _audioFrame) == 0) {
                    AudioFrame *frame = [self handleAudioFrame];
                    if (frame) {
                        [result addObject:frame];
                        if (_videoStreamIndex == -1) {
                            _decodePosition = frame.position;
                            decodeDuration += frame.duration;
                            if (decodeDuration > minDuration) {
                                finished = YES;
                            }
                        }
                    }
                }
            }
            
            /*
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
                        if (_videoStreamIndex == -1) {
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
            }*/
        } else {
            NSLog(@"We Can Not Process Stream Except Audio And Video Stream...");
        }
        av_packet_unref(&packet);
        //av_free_packet(&packet);
    }
    
    _readLastestFrameTime = [[NSDate date] timeIntervalSince1970];
    return result;
}

- (BuriedPoint *)getBuriedPoint{
    return _buriedPoint;
}

- (VideoFrame *)handleVideoFrame{
    if (!_videoFrame->data[0]) {
        return nil;
    }
    
    VideoFrame *frame = [[VideoFrame alloc] init];
    if (_videoCodecCtx->pix_fmt == AV_PIX_FMT_YUV420P || _videoCodecCtx->pix_fmt == AV_PIX_FMT_YUVJ420P) {
        frame.luma = copyFrameData(_videoFrame->data[0],
                                   _videoFrame->linesize[0],
                                   _videoCodecCtx->width,
                                   _videoCodecCtx->height);
        frame.chromaB = copyFrameData(_videoFrame->data[1],
                                      _videoFrame->linesize[1],
                                      _videoCodecCtx->width / 2,
                                      _videoCodecCtx->height / 2);
        
        frame.chromaR = copyFrameData(_videoFrame->data[2],
                                      _videoFrame->linesize[2],
                                      _videoCodecCtx->width/2,
                                      _videoCodecCtx->height/2);
        
    } else {
        if (!_swrContext && ![self setupScaler]) {
            NSLog(@"Faile setup video scaler");
            return nil;
        }
        
        /** libswscale常用的函数数量很少，一般情况下就3个
         * 1.sws_getContext()   初始化一个swsContext  也可以用sws_getCachedContext()取代
         * 2.sws_scale()   处理图像数据
         * 3.sws_freeContext()   释放一个swsContext
         */
        uint8_t *const data[AV_NUM_DATA_POINTERS];
        int linesize[AV_NUM_DATA_POINTERS];
        sws_scale(_swsContext,
                  (const uint8_t **)_videoFrame->data,
                  _videoFrame->linesize,
                  0,
                  _videoCodecCtx->height,
                  data,
                  linesize);
        frame.luma = copyFrameData(data[0],
                                   linesize[0],
                                   _videoCodecCtx->width,
                                   _videoCodecCtx->height);
        frame.chromaB = copyFrameData(data[1],
                                      linesize[1],
                                      _videoCodecCtx->width / 2,
                                      _videoCodecCtx->height / 2);
        frame.chromaR = copyFrameData(data[2],
                                      linesize[2],
                                      _videoCodecCtx->width / 2,
                                      _videoCodecCtx->height / 2);
        /*
        sws_scale(_swsContext,
                  (const uint8_t **)_videoFrame->data,
                  _videoFrame->linesize,
                  0,
                  _videoCodecCtx->height,
                  _picture.data,
                  _picture.linesize);
        
        frame.luma = copyFrameData(_picture.data[0],
                                   _picture.linesize[0],
                                   _videoCodecCtx->width,
                                   _videoCodecCtx->height);
        
        frame.chromaB = copyFrameData(_picture.data[1],
                                      _picture.linesize[1],
                                      _videoCodecCtx->width / 2,
                                      _videoCodecCtx->height / 2);
        
        frame.chromaR = copyFrameData(_picture.data[2],
                                      _picture.linesize[2],
                                      _videoCodecCtx->width / 2,
                                      _videoCodecCtx->height / 2);*/
        
    }
    frame.width = _videoCodecCtx->width;
    frame.height = _videoCodecCtx->height;
    frame.linesize = _videoFrame->linesize[0];
    frame.type = VideoFrameType;
    
    //这里的处理是音视频同步的关键代码
    frame.position = _videoFrame->best_effort_timestamp * _videoTimeBase; //best_effort_timestamp 预估的时间戳
    //frame.position = av_frame_get_best_effort_timestamp(_videoFrame) * _videoTimeBase; //_videoFrame->best_effort_timestamp;
    //const int64_t frameDuration = av_frame_get_pkt_duration(_videoFrame); //获取当前帧的持续时间
    const int64_t frameDuration = _videoFrame->pkt_duration;
    if (frameDuration) {
        frame.duration = frameDuration * _videoTimeBase;
        frame.duration += _videoFrame->repeat_pict * _videoTimeBase * 0.5;
    } else {
        frame.duration = 1.0 / _fps;
    }
    
    return frame;
}

- (AudioFrame *)handleAudioFrame{
    if (!_audioFrame->data[0]) {
        return nil;
    }
    
    const NSUInteger numChannels = _audioCondecCtx->channels;
    NSInteger numFrames;
    
    void *audioData;
    
    if (_swrContext) {
        const NSUInteger ratio = 2;
        const int bufSize = av_samples_get_buffer_size(NULL, (int)numChannels, (int)(_audioFrame->nb_samples * ratio), AV_SAMPLE_FMT_S16, 1);
        if (!_swrBuffer || _swrBufferSize < bufSize) {
            _swrBufferSize = bufSize;
            _swrBuffer = realloc(_swrBuffer, _swrBufferSize);
        }
        
        Byte *outbuf[2] = {_swrBuffer, 0};
        numFrames = swr_convert(_swrContext,
                                outbuf,
                                (int)(_audioFrame->nb_samples * ratio),
                                (const uint8_t **)_audioFrame->data,
                                _audioFrame->nb_samples);
        
        if (numFrames < 0) {
            NSLog(@"Faile resample audio");
            return nil;
        }
        audioData = _swrBuffer;
    } else {
        if (_audioCondecCtx->sample_fmt != AV_SAMPLE_FMT_S16) {
            NSLog(@"Audio format is invalid");
            return nil;
        }
        
        audioData = _audioFrame->data[0];
        numFrames = _audioFrame->nb_samples;
    }
    const NSUInteger numElements = numFrames *numChannels;
    NSMutableData *pcmData = [NSMutableData dataWithLength:numElements * sizeof(SInt16)];
    memcpy(pcmData.mutableBytes, audioData, numElements * sizeof(SInt16));
    AudioFrame *frame = [[AudioFrame alloc] init];
//    frame.position = av_frame_get_best_effort_timestamp(_audioFrame) * _audioTimeBase;
//    frame.duration = av_frame_get_pkt_duration(_audioFrame) * _audioTimeBase;
    frame.position = _audioFrame->best_effort_timestamp * _audioTimeBase;
    frame.duration = _audioFrame->pkt_duration * _audioTimeBase;
    frame.samples = pcmData;
    frame.type = AudioFrameType;
    return frame;
}

- (void)triggerFirstScreen{
    if (_buriedPoint.failOpenType == 1) {
        _buriedPoint.firstScreenTimeMills = ([[NSDate date] timeIntervalSince1970] * 1000 - _buriedPoint.beginOpen) / 1000.0f;
    }
}

- (void)addBufferStatusRecord:(NSString *)statusFlag{
    if ([@"F" isEqualToString:statusFlag] && [[_buriedPoint.bufferStatusRecords lastObject] hasPrefix:@"F_"]) {
        return;
    }
    
    float timeInterval = ([[NSDate date] timeIntervalSince1970] * 1000 - _buriedPoint.beginOpen) / 1000.0f;
    [_buriedPoint.bufferStatusRecords addObject:[NSString stringWithFormat:@"%@_%.3f", statusFlag, timeInterval]];
}

- (void)closeFile{
    NSLog(@"Enter close File...");
    if (_buriedPoint.failOpenType == 1) {
        _buriedPoint.duration = ([[NSDate date] timeIntervalSince1970] * 1000 - _buriedPoint.beginOpen) / 1000.0f;
    }
    
    [self interrupt];
    
    [self closeAudioStream];
    [self closeVideoStream];
    
    _videoStreams = nil;
    _audioStreams = nil;
    
    if (_formatCtx) {
        _formatCtx->interrupt_callback.opaque = NULL;
        _formatCtx->interrupt_callback.callback = NULL;
        avformat_close_input(&_formatCtx);
        
        _formatCtx = NULL;
    }
    
    float decodeFrameAVGTimeMills = (double)decodeVideoFrameWasteTimeMills / (float)totalVideoFramecount;
    NSLog(@"Decoder decoder totalVideoFramecount is %d decodeFrameAVGTimeMills is %.3f", totalVideoFramecount, decodeFrameAVGTimeMills);
}


- (void)closeAudioStream{
    _audioStreamIndex = -1;
    
    if (_swrBuffer) {
        free(_swrBuffer);
        _swrBuffer = NULL;
        _swrBufferSize = 0;
    }
    
    if (_swrContext) {
        swr_free(&_swrContext);
        _swrContext = NULL;
    }
    
    if (_audioFrame) {
        av_free(_audioFrame);
        _audioFrame = NULL;
    }
    
    if (_audioCondecCtx) {
        //avcodec_close(_audioCondecCtx);
        avcodec_free_context(&_audioCondecCtx);
        _audioCondecCtx = NULL;
    }
}

- (void)closeVideoStream{
    _videoStreamIndex = -1;
    
    [self closeScaler];
    
    if (_videoFrame) {
        av_free(_videoFrame);
        _videoFrame = NULL;
    }
    
    if (_videoCodecCtx) {
//        avcodec_close(_videoCodecCtx);
        avcodec_free_context(&_videoCodecCtx);
        _videoCodecCtx = NULL;
        
    }
}

- (BOOL)setupScaler{
    [self closeScaler];
    /*_pictureValid = avpicture_alloc(&_picture,
                                    AV_PIX_FMT_YUV420P,
                                    _videoCodecCtx->width,
                                    _videoCodecCtx->height) == 0;
    if (!_pictureValid) {
        return NO;
    }*/
    
    /** 创建缩放图片或转换图片格式上下文
     * sws_getCachedContext()首先会到缓存里找，有就直接返回当前的，没有就创建一个新的
     */
    _swsContext = sws_getCachedContext(_swsContext,
                                       _videoCodecCtx->width,
                                       _videoCodecCtx->height,
                                       _videoCodecCtx->pix_fmt,
                                       _videoCodecCtx->width,
                                       _videoCodecCtx->height,
                                       AV_PIX_FMT_YUV420P,
                                       SWS_FAST_BILINEAR,   // 可以使用各种不同的算法来对图像进行处理。  对比的地址:https://blog.csdn.net/leixiaohua1020/article/details/12029505
                                       NULL, NULL, NULL);
    
    return _swsContext != NULL;
}

- (void)closeScaler{
    if (_swsContext) {
        sws_freeContext(_swsContext);
        _swsContext = NULL;
    }
    
    /*if (_pictureValid) {
        avpicture_free(&_picture);
        _pictureValid = NO;
    }*/
}


- (BOOL)isEOF{
    return _isEOF;
}

- (BOOL)isSubscribed{
    return _isSubscribe;
}

- (NSUInteger)frameWidth{
    return  _videoCodecCtx ? _videoCodecCtx->width : 0;
}

- (NSUInteger)frameHeight{
    return _videoCodecCtx ? _videoCodecCtx->height : 0;
}

- (CGFloat)sampleRate{
    return _audioCondecCtx ? _audioCondecCtx->sample_rate : 0;
}

- (NSUInteger)channels{
    return _audioCondecCtx ? _audioCondecCtx->channels : 0;
}

- (BOOL)validVideo{
    return _videoStreamIndex != -1;
}

- (BOOL)validAudio{
    return _audioStreamIndex != -1;
}

- (CGFloat)getVideoFPS{
    return _fps;
}

- (CGFloat)getDuration{
    if (_formatCtx) {
        if (_formatCtx->duration == AV_NOPTS_VALUE) {
            return -1;
        }
        return _formatCtx->duration / AV_TIME_BASE;
    }
    return -1;
}

@end
