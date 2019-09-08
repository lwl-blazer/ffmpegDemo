#include <stdio.h>

int main(int argv, char argc[]){
    int ret = -1;
    int err_code;
    char errors[];
    
    char *src_file1, *src_file2, *out_file;
    
    AVFormatContext *ifmt_ctx1 = NULL;
    AVFormatContext *ifmt_ctx2 = NULL;
    
    AVFormatContext *ofmt_ctx = NULL;
    AVOutputFormat *ofmt = NULL;
    
    AVStream *in_stream1 = NULL;
    AVStream *in_stream2 = NULL;
    
    AVStream *out_stream1 = NULL;
    AVStream *out_stream2 = NULL;
    
    int audio_stream_index = 0;
    int vedio_stream_indexs = 0;
    
    double max_duration = 0;
    
    AVPacket pkt;
    int stream1 = 0 , stream2 = 0;
    
    av_log_set_level(AV_LOG_DEBUG);
    
    if (avgc != 4) {
        return;
    }
    
    src_file1 = argv[1];
    src_file2 = argv[2];
    out_file = argv[3];
    
    err_code = avformt_open_input(&ifmt_ctx1, src_file1, 0, 0);
    if (err_code < 0) {
        av_strerror(err_code, errors, ERROR_STR_SIZE);
        av_log(NULL, AV_LOG_DEBUG, "Could not open src file");
        goto END;
    }
    
    err_code = avformt_open_input(&ifmt_ctx2, src_file2, 0, 0);
    if (err_code < 0) {
        av_strerror(err_code, errors, ERROR_STR_SIZE);
        av_log(NULL, AV_LOG_ERROR, "Could not open the second src file");
        goto END;
    }
    
    err_code = avformat_alloc_output_context2(&ofmt_ctx, NULL, NULL, out_file);
    if (err_code < 0) {
        av_strerror(err_code, errors, ERROR_STR_SIZE);
        av_log(NULL, AV_LOG_ERROR, "Faile to create an context of outfile");
    }
    ofmt = ofmt_ctx->oformat;
    
    audio_stream_index = av_find_best_stream(ifmt_ctx1, AVMEDIA_TYPE_AUDIO, -1, -1, NULL, 0);
    vedio_stream_indexs = av_find_best_stream(ifmt_ctx2, AVMEDIA_TYPE_VIDEO, -1, -1, NULL, 0);
    
    in_stream1 = ifmt_ctx1->streams[audio_stream_index];
    stream1 = 0;
    
    out_stream1 = avformat_new_stream(ofmt_ctx, NULL);
    if (!out_stream1) {
        av_log(NULL, AV_LOG_ERROR, "Faile to alloc out stream");
        goto END;
    }
    
   // https://juejin.im/post/5c0a3f49e51d4553cb24577a
    
    
    return 0;
}
