//
//  avmerge2.c
//  AVmerge2
//
//  Created by luowailin on 2019/9/3.
//  Copyright © 2019 luowailin. All rights reserved.
//
// FFmpeg 小咖秀
// https://juejin.im/post/5c0a3f49e51d4553cb24577a


#include <stdio.h>
#include <libavutil/log.h>
#include <libavutil/timestamp.h>
#include <libavformat/avformat.h>

#define ERROR_STR_SIZE 1024


int main(int argc, char *argv[]){
    int ret = -1;
    int err_code;
    char errors[ERROR_STR_SIZE];
    
    char *src_file1, *src_file2, *out_file;
    
    AVFormatContext *ifmt_ctx1 = NULL;
    AVFormatContext *ifmt_ctx2 = NULL;
    
    AVFormatContext *ofmt_ctx = NULL;
    AVOutputFormat *ofmt = NULL;   //类似COM接口的数据结构，表示输出文件容器格式，着重于功能函数,每一种封装对应一个AVOutputFormat结构
    
    AVStream *in_stream1 = NULL;
    AVStream *in_stream2 = NULL;
    
    AVStream *out_stream1 = NULL;
    AVStream *out_stream2 = NULL;
    
    int audio_stream_index = 0;
    int video_stream_index = 0;
    
    double max_duration = 0;
    
    AVPacket pkt;
    int stream1 = 0, stream2 = 0;
    
    av_log_set_level(AV_LOG_DEBUG);
    
    if (argc != 4) {
        return -1;
    }
    
    src_file1 = argv[1];
    src_file2 = argv[2];
    out_file = argv[3];
    
    //打开第一个文件的输入流
    err_code = avformat_open_input(&ifmt_ctx1, src_file1, 0, 0);
    if (err_code < 0) {
        av_strerror(err_code, errors, ERROR_STR_SIZE);
        av_log(NULL, AV_LOG_DEBUG, "Could not open src file");
        goto END;
    }
    
    //打开第二个文件的输入流
    err_code = avformat_open_input(&ifmt_ctx2, src_file2, 0, 0);
    if (err_code < 0) {
        av_strerror(err_code, errors, ERROR_STR_SIZE);
        av_log(NULL, AV_LOG_ERROR, "Could not open the second src file");
        goto END;
    }
    
    //创建输出流
    err_code = avformat_alloc_output_context2(&ofmt_ctx, NULL, NULL, out_file);
    if (err_code < 0) {
        av_strerror(err_code, errors, ERROR_STR_SIZE);
        av_log(NULL, AV_LOG_ERROR, "Faile to create an context of outfile");
    }
    //ofmt = ofmt_ctx->oformat; //不知道为什么要进行赋值
    
    /**找到第一个参数里最好的音频流和第二个文件中的视频流下标*/
    audio_stream_index = av_find_best_stream(ifmt_ctx1, AVMEDIA_TYPE_AUDIO, -1, -1, NULL, 0);
    video_stream_index = av_find_best_stream(ifmt_ctx2, AVMEDIA_TYPE_VIDEO, -1, -1, NULL, 0);
    
    in_stream1 = ifmt_ctx1->streams[audio_stream_index];
    stream1 = 0;
    
    //创建音频输出流
    out_stream1 = avformat_new_stream(ofmt_ctx, NULL);
    if (!out_stream1) {
        av_log(NULL, AV_LOG_ERROR, "Faile to alloc out stream");
        goto END;
    }
    //拷贝流参数
    err_code = avcodec_parameters_copy(out_stream1->codecpar, in_stream1->codecpar);
    if (err_code < 0) {
        av_strerror(err_code, errors, ERROR_STR_SIZE);
        av_log(NULL, AV_LOG_ERROR, "Failed to copy codec parameter ");
    }
    out_stream1->codecpar->codec_tag = 0;
    
    in_stream2 = ifmt_ctx2->streams[video_stream_index];
    stream2 = 1;
    
    out_stream2 = avformat_new_stream(ofmt_ctx, NULL);
    if (!out_stream2) {
        av_log(NULL, AV_LOG_ERROR, "Failed to alloc out stream\n");
        goto END;
    }
    
    err_code = avcodec_parameters_copy(out_stream2->codecpar, in_stream2->codecpar);
    if (err_code < 0) {
        av_strerror(err_code, errors, ERROR_STR_SIZE);
        av_log(NULL, AV_LOG_ERROR, "Failed to copy codec parameter\n");
        goto END;
    }
    
    out_stream2->codecpar->codec_tag = 0;
    
    av_dump_format(ofmt_ctx, 0, out_file, 1);
    
    //判断两个流的长度，确定最终文件的长度
    if (in_stream1->duration * av_q2d(in_stream1->time_base) > in_stream2->duration * av_q2d(in_stream2->time_base)) {
        //in_stream1->duration * av_q2d(in_stream1->time_base) 换算成秒   AVStream中的duration是该视频流、音频流的长度
        max_duration = in_stream2->duration *av_q2d(in_stream2->time_base);
    } else {
        max_duration = in_stream1->duration * av_q2d(in_stream1->time_base);
    }
    
    //打开输出文件
    if (!(ofmt->flags & AVFMT_NOFILE)) {
        err_code = avio_open(&ofmt_ctx->pb, out_file, AVIO_FLAG_WRITE);
        if (err_code < 0) {
            av_strerror(err_code, errors, ERROR_STR_SIZE);
            av_log(NULL, AV_LOG_ERROR, "Could not open output file\n");
            goto END;
        }
    }
    
    //写入头信息
    err_code = avformat_write_header(ofmt_ctx, NULL);
    
    av_init_packet(&pkt);
    
    //读取音频数据并写入输出文件中
    while (av_read_frame(ifmt_ctx1, &pkt) >= 0) {
        //如果读取的时间超过了最长时间表示不需要该帧
        if (pkt.pts * av_q2d(in_stream1->time_base) > max_duration) {
            av_packet_unref(&pkt);
            continue; //跳过
        }
        
        //如果是我们需要的音频流，转换时间基后写入文件
        if (pkt.stream_index == audio_stream_index) {
            
            /** 不同时间基的换算
             * av_rescale_q(a, b, c)的作用是:把时间戳从一个时间基调整到另外一个时间基时候用的函数。其中，a表式要换算的值 b表示原来的时间基 c表示要转换的时间基。其计算公式为a * b / c;
             *
             * av_rescale_q_rnd() 返回值类型是int64_t 只是多了AV_ROUND_NEAR_INF AV_ROUND_PASS_MINMAX的取整方式而已
             */
            pkt.pts = av_rescale_q_rnd(pkt.pts, in_stream1->time_base, out_stream1->time_base, (AV_ROUND_NEAR_INF | AV_ROUND_PASS_MINMAX));
            pkt.dts = av_rescale_q_rnd(pkt.dts, in_stream1->time_base, out_stream1->time_base, (AV_ROUND_NEAR_INF | AV_ROUND_PASS_MINMAX));
            
            pkt.duration = av_rescale_q(max_duration, in_stream1->time_base, out_stream1->time_base);
            pkt.pos = -1;
            pkt.stream_index = stream1;
            av_interleaved_write_frame(ofmt_ctx, &pkt);
            av_packet_unref(&pkt);
        }
    }
    
    while (av_read_frame(ifmt_ctx2, &pkt) >= 0) {
        if (pkt.pts * av_q2d(in_stream2->time_base) > max_duration) {
            av_packet_unref(&pkt);
            continue;
        }
        
        if (pkt.stream_index == video_stream_index) {
            pkt.pts = av_rescale_q_rnd(pkt.pts, in_stream2->time_base, out_stream2->time_base, (AV_ROUND_NEAR_INF|AV_ROUND_PASS_MINMAX));
            pkt.dts = av_rescale_q_rnd(pkt.dts, in_stream2->time_base, out_stream2->time_base,
                                       (AV_ROUND_NEAR_INF|AV_ROUND_PASS_MINMAX));
            pkt.duration = av_rescale_q(max_duration, in_stream2->time_base, out_stream2->time_base);
            pkt.pos = -1;
            pkt.stream_index = stream2;
            av_interleaved_write_frame(ofmt_ctx, &pkt);
            av_packet_unref(&pkt);
        }
    }
    
    av_write_trailer(ofmt_ctx);
    
    ret = 0;
    
END:
    
    if (ifmt_ctx1) {
        avformat_close_input(&ifmt_ctx1);
    }
    if (ifmt_ctx2) {
        avformat_close_input(&ifmt_ctx2);
    }
    
    if (ofmt_ctx) {
        if (!(ofmt->flags & AVFMT_NOFILE)) {
            avio_closep(&ofmt_ctx->pb);
        }
        avformat_free_context(ofmt_ctx);
    }
    
    return ret;
}

/**关于时间基
 *
 * I/B/P帧
 * I帧--关键帧     帧内压缩技术
 * B帧--前后参考帧  帧间压缩技术  也就是说在压缩B帧前，它会参考它前面的非压缩视频帧和后面的非压缩的视频帧，记录下前后帧都不存放的"残差值"。这样可以达到最好的压缩率
 * P帧--向前参考帧  帧间压缩技术  也就是它参考的是前一个关键帧的数据 相对于B帧来说，P帧的压缩率要比B帧低
 *
 * 为什么会出现时间基的计算:
     是因为在压缩和解码B帧时，由于要双向参考，所以一定要先解码出前后的I和P帧，导致解码和显示顺序不一致，这就产生了时间基的计算。
     但是在实时互动直航系统中，很少使用B帧。因为它需要缓冲更多的数据，且使用的CPU也会更高。由于实时性的要求，所以一般不使用它
     但播放器，遇到带有B帧的H264数据是常有的事
 
 *
 * PTS(Presentation TimeStamp) 是渲染用的时间戳  --- 也就是我们的视频帧是按照PTS的时间戳来展示的
 * DTS(Decoding TimeStamp) 解码时间戳 ---  用于视频解码的
 *
 * 如果视频中没有B帧，那PTS和DTS是一样的，如果有B帧的情况，因为P帧参考的I帧，B帧是双向参考帧。也就是说，如果I帧和P帧没有解码的话，B帧是无法进行解码的，所以就出现了PTS和DTS两个时间戳
 *
 * 时间基 -- 时间刻度
 * 有了时间戳之后，最终进行展示时还要需要将PTS时间戳转成以秒为单位的时间。 引进FFmpeg中的时间基的概念
 *
 * .tbr  time base of rate  帧率
 * .tbn  time base of stream 视频流的时间基
 * .tbc  time base of codec  视频解码的时间基
 *
 * 计算公式 请查找上面的代码
 *
 * 参考:https://www.imooc.com/article/91381
 */
