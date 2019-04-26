//
//  XDecode.m
//  BLPlayerItem
//
//  Created by luowailin on 2019/4/19.
//  Copyright © 2019 luowailin. All rights reserved.
//

#import "XDecode.h"

@implementation XDecode

- (instancetype)init
{
    self = [super init];
    if (self) {
        self.isAudio = NO;
        codec = NULL;
    }
    return self;
}

- (BOOL)open:(AVCodecParameters *)para{
    
    if (!para) {
        return NO;
    }
    [self close];
    
    AVCodec *vcodec = avcodec_find_decoder(para->codec_id);
    if (!vcodec) {
        avcodec_parameters_free(&para);
        NSLog(@"can't find the code_id:%d", para->codec_id);
        return NO;
    }
    
    NSLog(@"Find the AVCodec: %d", para->codec_id);
    
    //根据找到的对应Decodec 申请一个AVCodecContext 然后将Decodec挂在AVCodecContext下
    codec = avcodec_alloc_context3(vcodec);
    
    //把AVCodecParameters参数同步至AVCodecContext中
    avcodec_parameters_to_context(codec, para);
    avcodec_parameters_free(&para);
    
    //thread_count 用于决定有多少个独立任务去执行
    codec->thread_count = 8;
    
    //当解码器的参数设置完毕后，打开解码器
    int ret = avcodec_open2(codec,
                            NULL,
                            NULL);
    if (ret != 0) {
        avcodec_free_context(&codec);
        
        char buf[1024] = {0};
        av_strerror(ret, buf, sizeof(buf) - 1);
        NSLog(@"avcodec_open2 failed!:%s", buf);
        return NO;
    }
    
    NSLog(@"avcodec_open2 success!");
    return YES;
}

/*
 * 老接口是使用的avcodec_decode_video2(视频解码接口) 和avcodec_decode_audio4(音频解码)
 *
 * avcodec_send_packet 和 avcodec_receive_frame调用关系并不是一对一的， 比如一些音频数据一个AVPacket中包含了1秒钟的音频，调用一次avcodec_send_packet之后，可能需要调用25次avcodec_receive才能获得全部的音频数据
 */
//发送编码数据包
- (BOOL)send:(AVPacket *)pkt{
    
    if (!pkt || pkt->size <= 0 || !pkt->data) {
        return NO;
    }
    
    if (!codec) {
        return NO;
    }
    int ret = avcodec_send_packet(codec, pkt);
    av_packet_free(&pkt);
    return ret != 0 ? NO : YES;
}


//接收解码后的数据
- (AVFrame *)recv{
    if (!codec) {
        return nil;
    }
    
    AVFrame *frame = av_frame_alloc();
    int ret = avcodec_receive_frame(codec, frame);
    
    if (ret != 0) {
        av_frame_free(&frame);
        return nil;
    }
    
    NSLog(@"[%d]", frame->linesize[0]);
    return frame;
}

- (void)clear{
    if (codec) {
        avcodec_flush_buffers(codec);
    }
}

- (void)close{
    if (codec) {
        avcodec_close(codec);
        avcodec_free_context(&codec);
    }
}

@end
