#include <libavutil/timestamp.h>
#include <libavformat/avformat.h>

static void log_packet(const AVFormatContext *fmt_ctx, const AVPacket *pkt, const char *tag){
    AVRational *time_base = &fmt_ctx->streams[pkt->stream_index]->time_base;
    
    printf("%s: pts:%s pts_time:%s dts:%s dts_time:%s duration:%s duration_time:%s stream_index:%d\n",
           tag,
           av_ts2str(pkt->pts), av_ts2timestr(pkt->pts, time_base),
           av_ts2str(pkt->dts), av_ts2timestr(pkt->dts, time_base),
           av_ts2str(pkt->duration), av_ts2timestr(pkt->duration, time_base),
           pkt->stream_index);
}

int main(int argc, char **argv){
    
    AVOutputFormat *ofmt = NULL;
    AVFormatContext *ifmt_ctx = NULL, *ofmt_ctx = NULL;
    AVPacket pkt;
    const char *in_filename, *out_filename;
    int ret, i;
    int stream_index = 0;
    int *stream_mapping = NULL;
    int stream_mapping_size = 0;
    
    if (argc < 3) {
        printf("usage: %s input output\n"
               "API example program to remux a media file with libavformat and libavcodec.\n"
               "The output format is guessed according to the file extension.\n"
               "\n", argv[0]);
        return 1;
    }
    
    in_filename = argv[1];
    out_filename = argv[2];
    
    av_register_all();
    if ((ret = avformat_open_input(&ifmt_ctx, in_filename, 0, 0)) < 0) { //创建输入文件上下文
        fprintf(stderr, "Could not open input file %s", in_filename);
        goto end;
    }
    
    /**avformat_find_stream_info() 该函数可以读取一部分音视频数据并且获得一些相关的信息 探测文件信息*/
    if ((ret = avformat_find_stream_info(ifmt_ctx, 0)) < 0) {
        fprintf(stderr, "Failed to retrieve input stream information");
        goto end;
    }
    av_dump_format(ifmt_ctx, 0, in_filename, 0);
    
    //创建输出文件上下文
    avformat_alloc_output_context2(&ofmt_ctx, NULL, NULL, out_filename);
    if (!ofmt_ctx) {
        fprintf(stderr, "Could not create output context\n");
        ret = AVERROR_UNKNOWN;
        goto end;
    }
    
    stream_mapping_size = ifmt_ctx->nb_streams;
    stream_mapping = av_mallocz_array(stream_mapping_size, sizeof(*stream_mapping)); //申请空间
    if (!stream_mapping) {
        ret = AVERROR(ENOMEM);
        goto end;
    }
    
    //AVOutputFormat 输出端的信息 是FFmpeg解复用(解封装)用的结构体，比如，输出的的协议，输出的编解码器
    ofmt = ofmt_ctx->oformat;
    
    //就是把AVStream 读取到内存中
    for (i = 0; i < ifmt_ctx->nb_streams; i++) {
        AVStream *out_stream;
        AVStream *in_stream = ifmt_ctx->streams[i];
        AVCodecParameters *in_codecpar = in_stream->codecpar; //AVCodecParameters 用于记录编码后的流信息，即通道中存储的流的编码信息
        
        if (in_codecpar->codec_type != AVMEDIA_TYPE_AUDIO &&
            in_codecpar->codec_type != AVMEDIA_TYPE_VIDEO &&
            in_codecpar->codec_type != AVMEDIA_TYPE_SUBTITLE) {
            stream_mapping[i] = -1;
            continue;
        }
        stream_mapping[i] = stream_index++;
        
       //在AVFormatContext中创建Stream通道，用于记录通道信息
        out_stream = avformat_new_stream(ofmt_ctx, NULL);
        if (!out_stream) {
            fprintf(stderr, "Failed allocating output stream\n");
            ret = AVERROR_UNKNOWN;
            goto end;
        }
        
        ret = avcodec_parameters_copy(out_stream->codecpar, in_codecpar);
        if (ret < 0) {
            fprintf(stderr, "Failed to copy codec parameters\n");
            goto end;
        }
        
        out_stream->codecpar->codec_tag = 0;
    }
    
    av_dump_format(ofmt_ctx, 0, out_filename, 1);
    
    if (!(ofmt->flags & AVFMT_NOFILE)) {
        /** avio_open() / avio_open2()
         * 用于打开FFmpeg的输入输出文件
         * 参数1:函数调用成功之后创建的AVIOContext结构体
         * 参数2:输入输出协议的地址(文件路径)
         * 参数3:打开地址的方式   AVIO_FLAG_READ 只读  AVIO_FLAG_WRITE 只写  AVIO_FLAG_READ_WRITE 读写
         *
         * 功能:
         * avio_open2() 内部主要调用两个函数:ffurl_open() 和ffio_fdopen(), 其中ffurl_open()用于初始化URLContext,ffio_fdopen()用于根据URLContext初始化AVIOContext. URLContext中包含的URLProtocol完成了具体的协议读写等工作。AVIOContext则是在URLContext的读写函数外面加上一层'包装'(通过retry_transfer_wrapper()函数)
         * URLProtocol 主要包含用于协议读写的函数指针 url_open() url_read() url_write() url_close
         */
        ret = avio_open(&ofmt_ctx->pb, out_filename, AVIO_FLAG_WRITE);
        if (ret < 0) {
            fprintf(stderr, "Could not open output file '%s'", out_filename);
            goto end;
        }
    }

    ret = avformat_write_header(ofmt_ctx, NULL);
    if (ret < 0) {
        fprintf(stderr, "Error occurred when opening output file\n");
        goto end;
    }
    
    //去内存中取
    while (1) {
        AVStream *in_stream, *out_stream;
        ret = av_read_frame(ifmt_ctx, &pkt);
        if (ret < 0) {
            break;
        }
        
        in_stream = ifmt_ctx->streams[pkt.stream_index];
        if (pkt.stream_index >= stream_mapping_size || stream_mapping[pkt.stream_index] < 0) {
            av_packet_unref(&pkt);
            continue;
        }
        
        pkt.stream_index = stream_mapping[pkt.stream_index];
        out_stream = ofmt_ctx->streams[pkt.stream_index];
        log_packet(ifmt_ctx, &pkt, "in"); //打印
        
        /**不同时间基计算
         * av_rescale_q(a, b, c)
         * av_rescale_q_rnd(a, b, c, AVRoundion rnd) //AVRoundion 就是取整的方式
         * 作用:
            把时间戳从一个时基调整到另外一个时基时候用的函数。其中，a表示要换算的值，b表式原来的时间基，c表示要转换的时间基， 其计算公式是 a * b / c
         *
         * 时间戳转秒
         *  time_in_seconds = av_q2q(AV_TIME_BASE_Q) * timestamp
         *
         * 秒转时间戳
         *  timestamp = AV_TIME_BASE * time_in_seconds
         */
        pkt.pts = av_rescale_q_rnd(pkt.pts, in_stream->time_base, out_stream->time_base, AV_ROUND_NEAR_INF|AV_ROUND_PASS_MINMAX);
        pkt.dts = av_rescale_q_rnd(pkt.dts, in_stream->time_base, out_stream->time_base, AV_ROUND_NEAR_INF|AV_ROUND_PASS_MINMAX);
        pkt.duration = av_rescale_q(pkt.duration, in_stream->time_base, out_stream->time_base);
        
        pkt.pos = -1;
        
        log_packet(ofmt_ctx, &pkt, "out");
        
        ret = av_interleaved_write_frame(ofmt_ctx, &pkt);
        if (ret < 0) {
            fprintf(stderr, "Error muxing packet\n");
            break;
        }
        av_packet_unref(&pkt);
    }
    
    av_write_trailer(ofmt_ctx);
end:
    avformat_close_input(&ifmt_ctx); //关闭输入文件上下文
    
    if (ofmt_ctx && !(ofmt->flags && AVFMT_NOFILE)) {
        avio_closep(&ofmt_ctx->pb);
    }
    
    //释放输出文件的上下文
    avformat_free_context(ofmt_ctx);
    
    av_freep(&stream_mapping);
    
    if (ret < 0 && ret != AVERROR_EOF) {
        fprintf(stderr, "Error occurred: %s\n", av_err2str(ret));
        return -1;
    }
    
    return 0;
}

/**
 * MP4文件 转 FLV文件
 *
 * 输出文件的上下文
 * avformat_alloc_output_context2()/avformat_free_context()
 *
 * avformat_new_stream()
 *
 * avcodec_parameters_copy()
 *
 * av_format_write_header()
 * av_write_frame() / av_interleaved_write_frame()
 * av_write_trailer()
 */
