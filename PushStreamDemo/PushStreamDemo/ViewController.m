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

//推流
- (IBAction)pushButtonAction:(UIButton *)sender {
    //地址
    char input_str_full[500] = {0};
    char output_str_full[500] = {0};
    
    if (self.addType == 0) {
        NSString *input_nsstr = [[[NSBundle mainBundle] resourcePath] stringByAppendingPathComponent:self.fileField.text];
        sprintf(input_str_full, "%s", [input_nsstr UTF8String]); //sprintf 字符串格式化   需要溢出的可能性 可以考虑使用snprintf()
    }
    
    if (self.addType == 1) { 
        NSString *input_nsstr = self.fileField.text;
        sprintf(input_str_full, "%s", [input_nsstr UTF8String]);
    }
    
    sprintf(output_str_full, "%s", [self.outUrlField.text UTF8String]);
 
    printf("input path: %s\n", input_str_full);
    printf("output path: %s\n", output_str_full);
    
    //ffmpeg支持各种各样的输出文件格式 mp4,flv,3gp ...,  AVOutputFormat 保存了这些格式的信息和一些常规设置
    AVOutputFormat *ofmt = NULL;
    
    /** AVFormatContext
        AVFormatContext主要存储音视频格式中包含的信息 AVInputFormat存储输入音视频使用的封装格式，每种音视频封装格式都对应一个AVInputFormat结构
     *
     * AVFormatContext是一个贯穿始终的数据结构
     * 它是FFmpeg解封装(flv,mp4,rmvb,avi)功能的结构体，
     *
     * 主要的变量:
       struct AVInputFormat *iformat  输入数据的封装格式
       AVIOContext *pb 输入数据的缓存
       unsigned int nb_streams 音视频流的个数
       AVStream *streams  音视流
       char filename[1024] 文件名
       int64_t duration  时长  （单位：微秒us, 转换为秒需要除以1000000）
       int bit_rate  比特率  (单位bps, 转换为kbps需要除以1000)
       AVDictionary *metadata 元数据
     
     
     * 视频的原数据(metadata)信息可以通过AVDictionary获取，元数据存储在AVDictionaryEntry结构体中
       每条元数据分为key和value两个属性
     * 在FFmpeg中通过av_dict_get()函数获得视频的原数据
     * 获取元数据并存入meta字符串变量的过程:
       CString meta=NULL,key,value;
       AVDictionaryEntry *m = NULL;
       //使用循环读出
       //(需要读取的数据，字段名称，前一条字段（循环时使用），参数)
       while( m = av_dict_get(pFormatCtx->metadata,"",m,AV_DICT_IGNORE_SUFFIX)) {
         key.Format(m->key);
         value.Format(m->value);
         meta+=key+"\t:"+value+"\r\n";
       }
     */
    AVFormatContext *ifmt_ctx = NULL, *ofmt_ctx = NULL; //上下文
    
    AVPacket pkt;
    char in_filename[500] = {0};
    char out_filename[500] = {0};
    
    int ret, i;
    int videoindex = -1;
    int frame_index = 0;
    int64_t start_time = 0;
    
    strcpy(in_filename, input_str_full);
    strcpy(out_filename, output_str_full);
    
    /**在window平台下需要调用，  需要用到加解密时需要调用(在底层实现中调用了openssl 和 GnuTLS 两个安全通讯库)*/
    avformat_network_init();
    
    //打开媒体  大概做了1.输入输出结构体AVIOContext的初始化 2.输入数据的协议 3.连接URLProtocol
    ret = avformat_open_input(&ifmt_ctx, in_filename, 0, 0);
    if (ret < 0) {
        printf("Could not open input file.\n");
        goto end;
    }
    
    //读取一部分音视频数据并且获得一些相关信息   avformat_find_stream_info()主要用于给每个媒体流(音频/视频)的AVStream赋值
    ret = avformat_find_stream_info(ifmt_ctx, 0);
    if (ret < 0) {
        printf("Failed to retrieve input stream information");
        goto end;
    }
    
    //input
    for (i = 0; i < ifmt_ctx->nb_streams; i++) {
        if (ifmt_ctx->streams[i]->codecpar->codec_type == AVMEDIA_TYPE_VIDEO) { //得到视频流
            videoindex = i;
            break;
        }
    }
    //打印的作用
    av_dump_format(ifmt_ctx, 0, in_filename, 0);
    
    
    /** output
     * avformat_alloc_output_context2() 在FFmpeg中音视频编码器程序中第一个调用的函数，初始化用于输出的AVFormatContext结构体
     * 参数:函数调用成功之后，创建的结构体
     * 参数:指定AVFormatContext中的AVOutputFormat,用于确定输出格式 如果为NULL 由FFmpeg根据后面两个参数猜测输出格式， 一般传NULL
     * 参数:指定输出格式的名称
     * 参数:指定输出文件的名称
     * 返回值大于或等于0 即成功
     */
    avformat_alloc_output_context2(&ofmt_ctx, NULL, "flv", out_filename); //RTMP
    //avformat_alloc_output_context2(&ofmt_ctx, NULL, "mpegts", out_filename); //UDP
    if (!ofmt_ctx) {
        printf("Could not create output context\n");
        ret = AVERROR_UNKNOWN;
        goto end;
    }
    ofmt = ofmt_ctx->oformat;
    
    for (i = 0; i < ifmt_ctx->nb_streams; i++) {
        //1.解码
        //每个AVStream存储一个视频/音频流的相关数据，每个AVStream对应一个AVCodecContext,存储该视频/音频流使用解码方式的相关数据；每个AVCodecContext中对应一个AVCodec，包含该视频/音频对应的解码器，每种解码器都对应一种AVCodec结构
        AVStream *in_stream = ifmt_ctx->streams[i];
        AVCodec *codec = avcodec_find_decoder(in_stream->codecpar->codec_id); //查找FFmpeg的解码器  avcodec_find_encoder 查找FFmpeg的编码器   其实质是遍历AVCodec链表并且获得符合AVCodecID的元素
        
        //avformat_new_stream 创建流通道
        AVStream *out_stream = avformat_new_stream(ofmt_ctx, codec);
        if (!out_stream) {
            printf("Faile allocation output stream\n");
            ret = AVERROR_UNKNOWN;
            goto end;
        }
        
        
  /* 老版
        ret = avcodec_copy_context(out_stream->codec, in_stream->codec);
        if (ret < 0) {
            printf("Failed to copy context from input to output stream codec context\n");
            goto end;
        }
        
        out_stream->codec->codec_tag = 0;
        if (ofmt_ctx->oformat->flags & AVFMT_GLOBALHEADER) {
            out_stream->codec->flags |= AV_CODEC_FLAG_GLOBAL_HEADER;    // a|=b 等价于 a=a|b;
        }
*/
        
        //2.编码
        /** AVCodecContext
         * 主要的参数:
         * enum AVMediaType codec_type    编解码器的类型(视频，音频)
         * struct AVCodec *codec 采用的解码器AVCodec (H.264, MPEG2...)
         * int bit_rate 平均比特率
         * uint8_t *extradata; int extradata_size 针对特定编码器包含的附加信息(例如对于H.264解码器来说，存储SPS,PPS等)
         * AVRational time_base  根据该参数，可以把PTS转化为实际的时间   (单位为s)
         * int width, height  如果是视频的话，代表宽和高
         * int refs 参考帧的个数 (H.264的话会有多帧)
         * int sample_rate 采样率(音频)
         * int channels 声道数(音频)
         * enum AVSampleFormat sample_fmt  采样格式
         * int profile  型   (H.264里面有)
         * int level  级
         
         AVCodecContext中很多参数是编码的时候使用的。而不是解码时候使用的
         */
        AVCodecContext *pCodecCtx = avcodec_alloc_context3(codec); //创建一个AVCodecContext的结构体
        ret = avcodec_parameters_to_context(pCodecCtx, in_stream->codecpar); //把parameters放到AVCodecContext中
        if (ret < 0) {
            printf("Failed to copy context input to output stream codec context");
            goto end;
        }
        
        //flags是什么用途????
        pCodecCtx->codec_tag = 0;
        if (ofmt_ctx->oformat->flags & AVFMT_GLOBALHEADER) {
            pCodecCtx->flags |= AV_CODEC_FLAG_GLOBAL_HEADER;
        }
        
        //out_stream->codecpar 从pCodecCtx中获取
        ret = avcodec_parameters_from_context(out_stream->codecpar, pCodecCtx);
        if (ret < 0) {
            printf("Failed to copy context input to output stream codec context");
            goto end;
        }
    }
    av_dump_format(ofmt_ctx, 0, out_filename, 1);
    
    //open output url
    if (!(ofmt->flags & AVFMT_NOFILE)) {
        /**
         * avio_open()   / avio_open2()  打开FFmpeg的输入输出文件
         * 参数:函数调用成功之后创建的AVIOContext结构体
         * 参数:输入输出的协议地址
         * 参数:flags 打开地址的方式  AVIO_FLAG_READ 只读 AVIO_FLAG_WRITE 只写 AVIO_FLAG_READ_WRITE 读写
         *
         * 底层实现:
           主要调用了2个函数：ffurl_open()和ffio_fdopen() 其中ffurl_open用于初始化URLContext,ffio_fdopen()用于根据URLContext初始化AVIOContext. URLContext中包含的URLProtocol完成了具体的协议读写等工作，AVIOContext则是在URLContext的读写函数外面加上了一层“包装”（通过retry_transfer_wrapper()函数）。
         */
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
    
    start_time = av_gettime(); //系统主时钟
    
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


/** AVIOContext
 * AVIOContext 是FFmpeg管理输入输出数据的结构体
 * 主要的变量和作用:
 *  unsigned char *buffer 缓存开始位置
 *  int buffer_size 缓存大小 (默认32768)
 *  unsigned char *buf_ptr;  当前指针读取到的位置
 *  unsigned char *buf_end;  缓存结束的位置
 *  void *opaque; URLContext结构体
 */
