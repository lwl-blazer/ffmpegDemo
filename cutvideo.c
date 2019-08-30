#include <stdlib.h>
#include <libavutil/timestamp.h>
#include <libavformat/avformat.h>

static void log_packet(const AVFormatContext *fmt_ctx, const AVPacket *pkt, const char *tag) {
    AVRational *time_base = &fmt_ctx->streams[pkt->stream_index]->time_base;
    
    printf("%s: pts:%s pts_time:%s dts:%s dts_time:%s duration:%s duration_time:%s stream_index:%d\n",
           tag,
           av_ts2str(pkt->pts), av_ts2timestr(pkt->pts, time_base),
           av_ts2str(pkt->dts), av_ts2timestr(pkt->dts, time_base),
           av_ts2str(pkt->duration), av_ts2timestr(pkt->duration, time_base),
           pkt->stream_index);
}


int cut_video(double from_seconds, double end_seconds, const char *in_filename, const char *out_filename) {
    
    AVOutputFormat *ofmt = NULL; //输出流的各种格式的合起的
    AVFormatContext *ifmt_ctx = NULL, *ofmt_ctx = NULL;
    
    AVPacket pkt;
    int ret, i;
    
    av_register_all();
    
    /**step1 打开输入文件  AVFormatContext*/
    if ((ret = avformat_open_input(&ifmt_ctx, in_filename, 0, 0)) < 0) {
        fprintf(stderr, "Could not open input file %s", in_filename);
        goto end;
    }
    

    if ((ret = avformat_find_stream_info(ifmt_ctx, 0)) < 0){ //试探的作用
        fprintf(stderr, "Failed to retrieve input stream information");
        goto end;
    }
    
    av_dump_format(ifmt_ctx, 0, in_filename, 0); //打印
    
    /** step2  打开输出文件 AVFormatContext **/
    avformat_alloc_output_context2(&ofmt_ctx, NULL, NULL, out_filename);
    if (!ofmt_ctx) {
        fprintf(stderr,"Could not create output context\n");
        ret = AVERROR_UNKNOWN;
        goto end;
    }
    
/**step3 创建新的AVStrem 参数的拷贝 然后放到ofmt_ctx中  并设置flags*/
    ofmt = ofmt_ctx->oformat;
    /*
    for (i = 0; i < ifmt_ctx->nb_streams; i ++) {
        AVStream *in_stream = ifmt_ctx->streams[i];
        AVStream *out_stream = avformat_new_stream(ofmt_ctx, in_stream->codec->codec);
        if (!out_stream) {
            fprintf(stderr, "Failed allocation output stream\n");
            ret = AVERROR_UNKNOWN;
            goto end;
        }
        
        ret = avcodec_copy_context(out_stream->codec, in_stream->codec);
        if (ret < 0) {
            fprintf(stderr, "Failed to copy context from input to output stream codec context\n");
            goto end;
        }
        
        //对于这个flag的处理，非常重要 
        out_stream->codec->codec_tag = 0;
        if (ofmt_ctx->oformat->flags & AVFMT_GLOBALHEADER) {   // 0x0040 AVFMT_GLOBALHEADER 
            out_stream->codec->flags |= AV_CODEC_FLAG_GLOBAL_HEADER;  //1 << 22  0x200000
        }
    }*/
    for (i = 0; i < ifmt_ctx->nb_streams; i ++){ //跟上面是一样的代码 只是使用了新的API
        AVStream *in_stream = ifmt_ctx->streams[i];
        AVCodec *in_codec = avcodec_find_decoder(in_stream->codecpar->codec_id);
        AVStream *out_stream = avformat_new_stream(ofmt_ctx, in_codec);

        if (!out_stream) {
            fprintf(stderr, "Failed allocation output stream\n");
            ret = AVERROR_UNKNOWN;
            goto end;
        }

        AVCodecContext *in_codec_context = avcodec_alloc_context3(in_codec);
        ret = avcodec_parameters_to_context(in_codec_context, in_stream->codecpar);
        if (ret < 0) {
            printf("Failed to copy in_stream codecpar to codec context\n");
            avcodec_free_context(&in_codec_context);
            goto end;
        }
        
        in_codec_context->codec_tag = 0;
        if (ofmt_ctx->oformat->flags & AVFMT_GLOBALHEADER) {   
            in_codec_context->flags |= AV_CODEC_FLAG_GLOBAL_HEADER; 
        }
        
        ret = avcodec_parameters_from_context(out_stream->codecpar, in_codec_context);
        if (ret < 0) {
            printf("Failed to copy codec context to out_stream codecpar context\n");
            avcodec_free_context(&in_codec_context);
            goto end;
        }
        avcodec_free_context(&in_codec_context);
    }
    
    av_dump_format(ofmt_ctx, 0, out_filename, 1);
    
    /** step4 打开 输出文件*/
    if (!(ofmt->flags & AVFMT_NOFILE)) {
        ret = avio_open(&ofmt_ctx->pb, out_filename, AVIO_FLAG_WRITE);
        if (ret < 0) {
            fprintf(stderr, "Could not open output file %s", out_filename);
            goto end;
        }
    }
    
    /**step 6 wirte 文件*/
    ret = avformat_write_header(ofmt_ctx, NULL);
    if (ret < 0) {
        fprintf(stderr, "Error occurred when opening output file\n");
        goto end;
    }
    

    /**step5 seek到指定位置 */
    ret = av_seek_frame(ifmt_ctx, -1, from_seconds * AV_TIME_BASE, AVSEEK_FLAG_ANY);
    if (ret < 0) {
        fprintf(stderr, "Error seek\n");
        goto end;
    }
    
    int64_t *dts_start_from = malloc(sizeof(int64_t) * ifmt_ctx->nb_streams);
    memset(dts_start_from, 0, sizeof(int64_t) *ifmt_ctx->nb_streams);
    
    int64_t *pts_start_from = malloc(sizeof(int64_t) * ifmt_ctx->nb_streams);
    memset(pts_start_from, 0, sizeof(int64_t) * ifmt_ctx->nb_streams);
    
    while (1) {
        AVStream *in_stream, *out_stream;
        ret = av_read_frame(ifmt_ctx, &pkt);
        if (ret < 0) {
            break;
        }
        
        in_stream = ifmt_ctx->streams[pkt.stream_index];
        out_stream = ofmt_ctx->streams[pkt.stream_index];
        
        log_packet(ifmt_ctx, &pkt, "in");
        
        if (av_q2d(in_stream->time_base) * pkt.pts > end_seconds) { //需要裁剪最后的时间
            av_packet_unref(&pkt);
            break;
        }
         
        if (dts_start_from[pkt.stream_index] == 0) {   //保存dts
            dts_start_from[pkt.stream_index] = pkt.dts;
            printf("dts_start_from: %s\n", av_ts2str(dts_start_from[pkt.stream_index]));
        }
         
        if (pts_start_from[pkt.stream_index] == 0) { //保存pts
            pts_start_from[pkt.stream_index] = pkt.pts;
            printf("pts_start_from:%s\n", av_ts2str(pts_start_from[pkt.stream_index]));
        }
        
 
        /** copy packet*/
        // pkt.pts = av_rescale_q_rnd(pkt.pts - pts_start_from[pkt.stream_index], in_stream->time_base, out_stream->time_base, AV_ROUND_NEAR_INF|AV_ROUND_PASS_MINMAX);
        // pkt.dts = av_rescale_q_rnd(pkt.dts - dts_start_from[pkt.stream_index], in_stream->time_base, out_stream->time_base, AV_ROUND_NEAR_INF|AV_ROUND_PASS_MINMAX);
        
        //这种写法跟上面的并没有差异
        pkt.pts = av_rescale_q_rnd(pkt.pts, in_stream->time_base, out_stream->time_base, AV_ROUND_NEAR_INF|AV_ROUND_PASS_MINMAX);
        pkt.dts = av_rescale_q_rnd(pkt.dts, in_stream->time_base, out_stream->time_base, AV_ROUND_NEAR_INF|AV_ROUND_PASS_MINMAX);
        if (pkt.pts < 0) {
            pkt.pts = 0;
        }
        
        if (pkt.dts < 0) {
            pkt.dts = 0;
        }
        
        pkt.duration = (int)av_rescale_q((int64_t)pkt.duration, in_stream->time_base, out_stream->time_base);
        
        pkt.pos = -1;
        log_packet(ofmt_ctx, &pkt, "out");
        printf("\n");
    
        
        if (pkt.pts >= pkt.dts) { //这个判断是不处理B帧   正确的方法是先解码再编码，然后再裁剪，可以利用AVFrame的pict_type是否等于AV_PICTURE_TYPE_B
            ret = av_interleaved_write_frame(ofmt_ctx, &pkt);
            if (ret < 0) {
                fprintf(stderr, "Error muxing packet\n");
                av_packet_unref(&pkt);
                break;
            }
        }
        av_packet_unref(&pkt);
    }
    
    free(dts_start_from);
    free(pts_start_from);
    
    av_write_trailer(ofmt_ctx);
    
end:
    avformat_close_input(&ifmt_ctx);
    
    /** close output*/
    if (ofmt_ctx && !(ofmt->flags & AVFMT_NOFILE)) {
        avio_closep(&ofmt_ctx->pb);
    }
    
    avformat_free_context(ofmt_ctx);
    
    if (ret < 0 && ret != AVERROR_EOF) {
        fprintf(stderr, "Error occurred: %s\n", av_err2str(ret));
        return 1;
    }
    return 0;
}


int main(int argc, char *argv[]) {
    if (argc < 5) {
        fprintf(stderr, "Usage: command startime, endtime srcfile outfile");
        return -1;
    }
    
    double startime = atoi(argv[1]);
    double endtime = atoi(argv[2]);
    cut_video(startime, endtime, argv[3], argv[4]);
    return 0;
}

