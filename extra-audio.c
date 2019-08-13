include <stdio.h>
#include <libavutil/log.h>
#include <libavformat/avio.h>
#include <libavformat/avformat.h>

#define ERROR_STR_SIZE 1024

/** FFmpeg 抽取音频
 * AAC分为:HE-AAC和LC-AAC的
 *
 * 抽取音频的两种方式:
 * 第一种:
     取出一个个音频包，然后在每个音频包前手动的添加ADTS Header 再写入文件,这种方式需要了解ADTS Header
 * 第二种:
     使用ffmpeg API 直建创建一个AAC文件，在ffmpeg库内部会自已查找对应的多媒体格式帮你做好ADTS Header并最终写好AAC文件。 代码采用此种方法
 */

int main(int argc, char *argv[]){
    
    int err_code;
    char errors[1024];
    
    char *src_filename = NULL;
    char *dst_filename = NULL;
    
    int audio_stream_index = -1;
    int len;
    
    //输出--为了让FFmpeg创建AAC文件所以需要多出的参数
    AVFormatContext *ofmt_ctx = NULL;
    AVOutputFormat *output_fmt = NULL;
    AVStream *out_stream = NULL;
    
    //输入
    AVFormatContext *fmt_ctx = NULL;
    AVStream *in_stream = NULL;
    AVPacket pkt;
    
    av_log_set_level(AV_LOG_DEBUG);
    
    //获取执行的参数
    if(argc < 3){
        av_log(NULL, AV_LOG_DEBUG, "the count of parameters\n");
        return -1;
    }
    src_filename = argv[1];
    dst_filename = argv[2];
    if(src_filename == NULL || dst_filename == NULL) {
        av_log(NULL, AV_LOG_DEBUG, "src or dts file is null\n");
        return -1;
    }
    
    av_register_all();
#pragma mark -- input file
    if ((err_code = avformat_open_input(&fmt_ctx, src_filename, NULL, NULL)) < 0){
        av_strerror(err_code, errors, 1024);
        av_log(NULL, AV_LOG_DEBUG, "Could not open source file:%s %d(%s)",src_filename, err_code, errors);
        return -1;
    }
    
    if((err_code = avformat_find_stream_info(fmt_ctx, NULL)) < 0) {
        av_strerror(err_code, errors, 1024);
        av_log(NULL, AV_LOG_DEBUG, "failed to find stream information:%s, %d(%s)\n",
               src_filename,
               err_code,
               errors);
        avformat_close_input(&fmt_ctx);
        return -1;
    }
    
    av_dump_format(fmt_ctx, 0, src_filename, 0);
    in_stream = fmt_ctx->streams[1];
    AVCodecParameters *in_codecpar = in_stream->codecpar;
    if(in_codecpar->codec_type != AVMEDIA_TYPE_AUDIO) {
        av_log(NULL, AV_LOG_ERROR, "The Codec type is invalid\n");
        avformat_close_input(&fmt_ctx);
        exit(1);
    }
    
#pragma mark -- output file
    ofmt_ctx = avformat_alloc_context();
    
    //step-1
    output_fmt = av_guess_format(NULL, dst_filename, NULL); //让FFmpeg帮你找到一个合适的文件格式
    if (!output_fmt) {
        av_log(NULL, AV_LOG_DEBUG, "Cloud not guess file format\n");
        exit(1);
    }
    ofmt_ctx->oformat = output_fmt;
    
    //step-2
    out_stream = avformat_new_stream(ofmt_ctx, NULL); //为输出文件创建一个新流
    if (!out_stream) {
        av_log(NULL, AV_LOG_DEBUG, "Failed to create out stream!\n");
        exit(1);
    }
    
    if (fmt_ctx->nb_streams < 2) {
        av_log(NULL, AV_LOG_ERROR, "the number of stream is too less\n");
        exit(1);
    }
    
    if ((err_code = avcodec_parameters_copy(out_stream->codecpar, in_codecpar)) < 0) { //拷贝配置项
        av_strerror(err_code, errors, ERROR_STR_SIZE);
        av_log(NULL, AV_LOG_ERROR, "faile to copy codec parameter, %d(%s)\n", err_code, errors);
    }
    
    out_stream->codecpar->codec_tag = 0;
    //step-3 打开新创建的文件
    if ((err_code = avio_open(&ofmt_ctx->pb, dst_filename, AVIO_FLAG_WRITE)) < 0) {
        av_strerror(err_code, errors, 1024);
        av_log(NULL, AV_LOG_DEBUG, "Could not open file %s, %d(%s)", dst_filename, err_code, errors);
        exit(1);
    }
    
    av_dump_format(ofmt_ctx, 0, dst_filename, 1);
    
#pragma mark -- 解码
    av_init_packet(&pkt);
    pkt.data = NULL;
    pkt.size = 0;
    
    audio_stream_index = av_find_best_stream(fmt_ctx, AVMEDIA_TYPE_AUDIO, -1,-1,NULL, 0);
    if (audio_stream_index < 0) {
        av_log(NULL, AV_LOG_DEBUG, "Could not find %s stream in input file %s\n", av_get_media_type_string(AVMEDIA_TYPE_AUDIO),src_filename);
        return AVERROR(EINVAL);
    }
    
    //step-4 写文件头
    if (avformat_write_header(ofmt_ctx, NULL) < 0) {
        av_log(NULL, AV_LOG_DEBUG, "Error occurred when opening output file\n");
        exit(1);
    }
    
    while(av_read_frame(fmt_ctx, &pkt) >= 0){
        if(pkt.stream_index == audio_stream_index){
            /** 注意的点
             * 在将抽取出的音频包写入输出文件之前，要重新计算它的时间戳，也就是将原来时间基的时间戳修改为输出流时间基的时间戳。
             *
             * av_rescale_q_rnd(int64_t a, int64_t b, int64_c, enum AVRounding rnd);
                作用是计算 "a * b / c"的值并分五种方式取整
                在FFmpeg中则是将以"时钟基c"表示的"数值a" 转换成以"时钟基b"来表示
             
             * AVRounding 有5种方式：
                AV_ROUND_ZERO = 0 趋近于0
                AV_ROUND_INF = 1 趋远于0
                AV_ROUND_DOWN = 2 趋于更小的整数
                AV_ROUND_UP = 3 趋于更大的整数
                AV_ROUND_NEAR_INF = 5 四舍五入，小于0.5取值趋向0，大于0.5取值趋远于0
             
             *
             * 关于FFmpeg中的pkt,dts，time_base的说明:https://www.itread01.com/content/1547032827.html
             */
            pkt.pts = av_rescale_q_rnd(pkt.pts, in_stream->time_base, out_stream->time_base, (AV_ROUND_NEAR_INF|AV_ROUND_PASS_MINMAX));
            pkt.dts = pkt.pts;
            pkt.duration = av_rescale_q(pkt.duration, in_stream->time_base, out_stream->time_base);
            pkt.pos = -1;
            pkt.stream_index = 0;
            
            //step-5 写文件内容
            av_interleaved_write_frame(ofmt_ctx, &pkt);
            av_packet_unref(&pkt);
        }
    }
    
    //step-6 写文件尾
    av_write_trailer(ofmt_ctx);
    //step-7 关闭文件
    avio_close(ofmt_ctx->pb);
    
    avformat_close_input(&fmt_ctx);
    avformat_close_input(&ofmt_ctx);
    
    return 0;
}

