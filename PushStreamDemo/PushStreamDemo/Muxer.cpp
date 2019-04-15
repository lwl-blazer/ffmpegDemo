//
//  Muxer.cpp
//  PushStreamDemo
//
//  Created by luowailin on 2019/4/15.
//  Copyright © 2019 luowailin. All rights reserved.
//

#include "Muxer.hpp"
#include <libavutil/channel_layout.h> //用户音频声道布局操作
#include <libavutil/opt.h>  //设置操作选项操作
#include <libavutil/mathematics.h>   //用于数学相关操作
#include <libavutil/timestamp.h>   //用于时间戳操作
#include <libavformat/avformat.h>   //用于封装与解封装操作
#include <libswscale/swscale.h>     //用于缩放，转换颜色格式操作
#include <libswresample/swresample.h>   //用于进行音频采样率操作


#include <iostream>

using namespace std;
void Muxer::openUrl(char *url) {
   
    
    avformat_alloc_output_context2(&oc,
                                   nullptr,
                                   "flv",
                                   url);
    
    if (!oc) {
        cout << "cannot alloc flv format" << endl;
        return;
    }
    fmt = oc->oformat;
    
    AVStream *st;
    AVCodecContext *c;
    
    //申请一个将要写入的AVStream流， AVStream流主要作为存放音频、视频、字幕数据流使用
    st = avformat_new_stream(oc, nullptr);
    
    if (!st) {
        cout << "could not allocate stream\n" << endl;
        return;
    }
    
    st->id = oc->nb_streams - 1;
    
    //需要将codec 和AVStream进行对应， 可以根据视频编码参数对AVCodecContext的参数进行设置
    c->codec_id = st->codecpar->codec_id;
    c->bit_rate = 400000;
    c->width = 352;
    c->height = 288;
    st->time_base = (AVRational){1, 25};
    c->time_base = st->time_base;
    c->gop_size = 12;
    c->pix_fmt = AV_PIX_FMT_YUV420P;
    
    //为了兼容新版本FFmpeg的AVCodecparameters结构，需要做一个参数copy操作
    // avcodec_parameters_from_context
    
    
    //添加目标容器头信息----在操作封装格式时，有些封装格式需要写入头部信，所以在FFmpeg写封装数据时，需要先写封装格式的头部
    //avformat_write_header(oc, &opt);
    

//写入帧数据----在FFmpeg操作数据包时，均采用写帧操作进行音视频数据包的写入，而每一帧在常规情况均使用AVPacket结构进行音视频数据的存储，AVPacket结构中包含了PTS,DTS，Data等信息，数据在写入封装中时，会根据封装特性写入对应的信息
    AVIOContext *read_in = avio_alloc_context(nullptr,
                                              30 * 1024,
                                              0,
                                              nullptr,
                                              nullptr,
                                              nullptr,
                                              nullptr);
    
    //从内存中读取数据，需要将avio_alloc_context获取到的buffer与AVFormatContext建立关联，然后再像操作文件一样操作即可
    oc->pb = read_in;
    oc->flags = AVFMT_FLAG_CUSTOM_IO;
    int ret;
    //avformat_open_input()  该函数用于打开多媒体数据并且获得一些相关信息
    if (avformat_open_input(&oc, url, nullptr, nullptr) < 0) {
        cout << "Cannotgeth264memorydata" << endl;
        return;
    }
    
    while (true) {
        AVPacket pkt =  {0};
        av_init_packet(&pkt);
        
        ret = av_read_frame(oc, &pkt);
        if (ret < 0) {
            break;
        }
        
        //转换为解码器的时间戳
        //av_packet_rescale_ts(pkt, st->time_base, st->time_base);
        
        pkt.stream_index = st->index;
        
        //将packet通过av_interleaved_write_frame写入到输出的封装格式中
        //av_interleaved_write_frame(oc, pkt);
    
    }
    //写容器尾信息
    av_write_trailer(oc);
}
