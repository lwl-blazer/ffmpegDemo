//
//  ViewController.m
//  PushStreamDemo
//
//  Created by luowailin on 2019/3/20.
//  Copyright © 2019 luowailin. All rights reserved.
//
// 测试视频地址:https://www.jianshu.com/p/5fab7968f76a
// 网络接口:http:/api.m.mtime.cn/PageSubArea/TrailerList.api

#import "ViewController.h"
#include <libavcodec/avcodec.h>
#include <libavformat/avformat.h>
#include <libavutil/mathematics.h>
#include <libavutil/time.h>

@interface ViewController ()

@property (weak, nonatomic) IBOutlet UITextField *fileField;
@property (weak, nonatomic) IBOutlet UITextField *outUrlField;
@property (nonatomic, assign) NSInteger addType;

@end

@implementation ViewController

- (void)viewDidLoad {
    [super viewDidLoad];
    self.addType = 0;
}

- (IBAction)addSegment:(UISegmentedControl *)sender {
    self.addType = sender.selectedSegmentIndex;
}


- (IBAction)pushButtonAction:(UIButton *)sender {
    
    char input_str_full[500] = {0};
    char output_str_full[500] = {0};
    
    
    if (self.addType == 0) {
        NSString *input_nsstr = [[[NSBundle mainBundle] resourcePath] stringByAppendingPathComponent:self.fileField.text];
        sprintf(input_str_full, "%s", [input_nsstr UTF8String]);
    }
    
    if (self.addType == 1) { 
        NSString *input_nsstr = self.fileField.text;
        sprintf(input_str_full, "%s", [input_nsstr UTF8String]);
    }
    
    sprintf(output_str_full, "%s", [self.outUrlField.text UTF8String]);
 
    printf("input path: %s\n", input_str_full);
    printf("output path: %s\n", output_str_full);
    
    AVOutputFormat *ofmt = NULL;
    AVFormatContext *ifmt_ctx = NULL, *ofmt_ctx = NULL;
    
    AVPacket pkt;
    char in_filename[500] = {0};
    char out_filename[500] = {0};
    
    int ret, i;
    int videoindex = -1;
    int frame_index = 0;
    int64_t start_time = 0;
    
    strcpy(in_filename, input_str_full);
    strcpy(out_filename, output_str_full);
    
    avformat_network_init();
    
    ret = avformat_open_input(&ifmt_ctx, in_filename, 0, 0);
    if (ret < 0) {
        printf("Could not open input file.\n");
        goto end;
    }
    
    ret = avformat_find_stream_info(ifmt_ctx, 0);
    if (ret < 0) {
        printf("Failed to retrieve input stream information");
        goto end;
    }
    
    //input
    for (i = 0; i < ifmt_ctx->nb_streams; i++) {
        if (ifmt_ctx->streams[i]->codecpar->codec_type == AVMEDIA_TYPE_VIDEO) {
            videoindex = i;
            break;
        }
    }
    
    av_dump_format(ifmt_ctx, 0, in_filename, 0);
    
    
    //output
    avformat_alloc_output_context2(&ofmt_ctx, NULL, "flv", out_filename); //RTMP
    //avformat_alloc_output_context2(&ofmt_ctx, NULL, "mpegts", out_filename); //UDP
    if (!ofmt_ctx) {
        printf("Could not create output context\n");
        ret = AVERROR_UNKNOWN;
        goto end;
    }
    ofmt = ofmt_ctx->oformat;
    for (i = 0; i < ifmt_ctx->nb_streams; i++) {
        AVStream *in_stream = ifmt_ctx->streams[i];
        AVCodec *codec = avcodec_find_decoder(in_stream->codecpar->codec_id);
        AVStream *out_stream =  avformat_new_stream(ofmt_ctx, codec);
        if (!out_stream) {
            printf("Faile allocation output stream\n");
            ret = AVERROR_UNKNOWN;
            goto end;
        }
    
        ret = avcodec_copy_context(out_stream->codec, in_stream->codec);
        //ret = avcodec_parameters_copy(out_stream->codecpar, in_stream->codecpar);
        if (ret < 0) {
            printf("Failed to copy context from input to output stream codec context\n");
            goto end;
        }
        
        out_stream->codec->codec_tag = 0;
        if (ofmt_ctx->oformat->flags & AVFMT_GLOBALHEADER) {
            out_stream->codec->flags |= AV_CODEC_FLAG_GLOBAL_HEADER;    // a|=b 等价于 a=a|b;
        }
        
    }
    
    av_dump_format(ofmt_ctx, 0, out_filename, 1);
    
    //open output url
    if (!(ofmt->flags & AVFMT_NOFILE)) {
        ret = avio_open(&ofmt_ctx->pb, out_filename, AVIO_FLAG_WRITE);
        if (ret < 0) {
            printf("Could not open output URL %s", out_filename);
            goto end;
        }
    }

    /** 写文件用到的3个函数
     * avformat_write_header()  用于写视频文件头
     * av_write_frame()
     * av_write_trailer()     用于写视频文件尾
     这三个函数功能是配套的
     */
    ret = avformat_write_header(ofmt_ctx, NULL);
    if (ret < 0) {
        printf( "Error occurred when opening output URL\n");
        goto end;
    }
    
    start_time = av_gettime();
    
    while (1) {
        AVStream *in_stream , *out_stream;
        ret = av_read_frame(ifmt_ctx, &pkt);
        if (ret < 0) {
            break;
        }
        
        if (pkt.pts == AV_NOPTS_VALUE) {
            AVRational time_base1 = ifmt_ctx->streams[videoindex]->time_base;
            
            int64_t calc_duration = (double) AV_TIME_BASE / av_q2d(ifmt_ctx->streams[videoindex]->r_frame_rate);
            
            pkt.pts = (double)(frame_index * calc_duration) / (double) av_q2d(time_base1) * AV_TIME_BASE;
            
            pkt.dts = pkt.pts;
            
            pkt.duration = (double)calc_duration / (double)(av_q2d(time_base1) * AV_TIME_BASE);
        }
        
        if (pkt.stream_index == videoindex) {
            AVRational time_base = ifmt_ctx->streams[videoindex]->time_base;
            AVRational time_base_q = {1, AV_TIME_BASE};
            
            int64_t pts_time = av_rescale_q(pkt.dts, time_base, time_base_q);
            int64_t now_time = av_gettime() - start_time;
            if (pts_time > now_time) {
                av_usleep((unsigned int)(pts_time - now_time));
            }
            
            in_stream = ifmt_ctx->streams[pkt.stream_index];
            out_stream = ofmt_ctx->streams[pkt.stream_index];
            
            pkt.pts = av_rescale_q_rnd(pkt.pts, in_stream->time_base, out_stream->time_base, (AV_ROUND_NEAR_INF|AV_ROUND_PASS_MINMAX));
            pkt.dts = av_rescale_q_rnd(pkt.dts, in_stream->time_base, out_stream->time_base, (AV_ROUND_NEAR_INF|AV_ROUND_PASS_MINMAX));
            pkt.duration = av_rescale_q(pkt.duration, in_stream->time_base, out_stream->time_base);
            
            pkt.pos = -1;
            
            if (pkt.stream_index == videoindex) {
                printf("Send %d video frames to output URL\n", frame_index);
                frame_index ++;
            }
            
            ret = av_interleaved_write_frame(ofmt_ctx, &pkt);
            
            if (ret < 0) {
                printf("Error muxing packet\n");
                break;
            }
        }
        av_packet_unref(&pkt);
    }
    av_write_trailer(ofmt_ctx);
end:
    avformat_close_input(&ifmt_ctx);
    
    if (ofmt_ctx && !(ofmt->flags && AVFMT_NOFILE)) {
        avio_close(ofmt_ctx->pb);
    }
    
    avformat_free_context(ofmt_ctx);
    if (ret < 0  && ret != AVERROR_EOF) {
        printf("Error occurred.\n");
        return;
    }
    return;
}

@end
