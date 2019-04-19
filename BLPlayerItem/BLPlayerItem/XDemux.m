//
//  XDemux.m
//  BLPlayerItem
//
//  Created by luowailin on 2019/4/19.
//  Copyright © 2019 luowailin. All rights reserved.
//

#import "XDemux.h"

static double r2d(AVRational r) {
    return r.den == 0 ? 0 : (double)r.num / (double)r.den;
}


@implementation XDemux

- (instancetype)init
{
    self = [super init];
    if (self) {
        self.totalMs = 0;
        self.width = 0;
        self.height = 0;
        
        self.videoStream = 0;
        self.audioStream = 1;
        
    }
    return self;
}

- (BOOL)open:(NSString *)url{
    AVDictionary *opts = nil;
    av_dict_set(&opts, "rtsp_transport", "tcp", 0);
    av_dict_set(&opts, "max_delay", "500", 0);
    
    const char *str = [url UTF8String];
    
    //avformat_open_input  用于打开多媒体数据并且获得一些相关的信息   内部打开输入视频数据并且探测视频的格式  赋值AVFormatContext中的AVInputFormat
    int ret = avformat_open_input(&ic,
                                  str,
                                  NULL,
                                  &opts);
    if (ret != 0) {
        char buf[1024] = {0};
        av_strerror(ret, buf, sizeof(buf) - 1);
        NSLog(@"%s", buf);
        return NO;
    }
    
    NSLog(@"open %@ success", url);
    
    //从AVFormatContext中建立输入文件对应的流信息
    ret = avformat_find_stream_info(ic, NULL); //查找音视频流信息
    
    self.totalMs = (int)(ic->duration / (AV_TIME_BASE / 1000));   //毫秒
    NSLog(@"totalMs:%d", self.totalMs);
    
    av_dump_format(ic, 0, str, 0);
    
    //可以用遍历获取音视频stream_index， 也要以用这个方法
    self.videoStream = av_find_best_stream(ic,
                                           AVMEDIA_TYPE_VIDEO,
                                           -1,
                                           -1,
                                           NULL,
                                           0);
    
    //音视频流
    AVStream *as = ic->streams[self.videoStream];
    self.width = as->codecpar->width;
    self.height = as->codecpar->height;
    
    NSLog(@"=======================================================");
    NSLog(@"codec_id = %d", as->codecpar->codec_id);
    NSLog(@"format = %d", as->codecpar->format);
    NSLog(@"video fps = %lf", r2d(as->avg_frame_rate));
    
    self.audioStream = av_find_best_stream(ic,
                                           AVMEDIA_TYPE_AUDIO,
                                           -1,
                                           -1,
                                           NULL,
                                           0);
    as = ic->streams[self.audioStream];
    
    NSLog(@"=======================================================");
    NSLog(@"codec_id = %d", as->codecpar->codec_id);
    NSLog(@"format = %d", as->codecpar->format);
    NSLog(@"sample_rate = %d", as->codecpar->sample_rate);
    NSLog(@"channels = %d", as->codecpar->channels);
    NSLog(@"frame_size = %d", as->codecpar->frame_size);
    return YES;
}

//从把AVFormatContext的所有流读到AVPacket中
- (AVPacket *)read{
    if (!ic) {
        return nil;
    }
    
    AVPacket *pkt = av_packet_alloc();
    //读取音视频流   从AVFormatContext中读取音视频流数据包， 将音视频流数据包读取出来存储至AVPacket中,然后通过对AVPacket包判断，确定其为音频、视频、字幕数据，最后进行解码或者进行数据存储
    int ret = av_read_frame(ic, pkt);
    if (ret != 0) {
        av_packet_free(&pkt);
        return nil;
    }
    
    pkt->pts = pkt->pts * (1000 * r2d(ic->streams[pkt->stream_index]->time_base));
    pkt->dts = pkt->dts * (1000 * r2d(ic->streams[pkt->stream_index]->time_base));
    
    return pkt;
}

- (AVCodecParameters *)copyVideoParameters{
    if (!ic) {
        return nil;
    }
    
    /* 注意事项:
     * 为什么AVCodecParameters需要alloc而不是直接用指针引用  因为在解码的时候需要用的uint8_t *extradata的值，在被释放的时候也会同时被释放，
     * 所以需要alloc出空间，然后进行copy操作
     */
    AVCodecParameters *pa = avcodec_parameters_alloc();
    avcodec_parameters_copy(pa, ic->streams[self.videoStream]->codecpar);
    return pa;
}

- (AVCodecParameters *)copyAudioParameters{
    if (!ic) {
        return nil;
    }
    
    AVCodecParameters *pa = avcodec_parameters_alloc();
    avcodec_parameters_copy(pa, ic->streams[self.audioStream]->codecpar);
    return pa;
}

- (BOOL)seek:(double)pos{
    if (!ic) {
        return NO;
    }
    
    //清理读取缓存  一般读文件的时候没有，读文件流的时候肯定是有的，如果不清除可能会出现粘包现象
    avformat_flush(ic);
    
    long long seekPos = 0;
    //seek的位置计算  有三种情况的判断
    //timestamp  先基于AVStream的duration来计算 如果为空那再基于AVStream中的time_base 如果空基于AV_TIME_BASE(1000000)
    seekPos = (long long)(ic->streams[self.videoStream]->duration *pos);
    
    int ret = av_seek_frame(ic, self.videoStream, seekPos, AVSEEK_FLAG_BACKWARD|AVSEEK_FLAG_FRAME);
    return ret >= 0 ? YES : NO;
}


- (BOOL)isAudio:(AVPacket *)pkt{
    if (!pkt) {
        return NO;
    }
    
    if (pkt->stream_index == self.videoStream) {
        return NO;
    }
    return YES;
}

- (void)clear{
    if (!ic) {
        return;
    }
    
    avformat_flush(ic);
}

- (void)close{
    if (!ic) {
        return;
    }
    avformat_close_input(&ic);//执行结束操作主要为关闭输入文件以及释放资源等
    self.totalMs = 0;
}


@end
