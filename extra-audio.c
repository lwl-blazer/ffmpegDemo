#include <stdio.h>
#include <libavutil/log.h>
#include <libavformat/avio.h>
#include <libavformat/avformat.h>

void adts_header(char *szAdtsHeader, int dataLen){
    int audio_object_type = 2;
    int sampling_frequency_index = 7;
    int channel_config =2;
    
    int adtsLen = dataLen + 7;
    
    szAdtsHeader[0] = 0xff;
    szAdtsHeader[1] = 0xf0;
    szAdtsHeader[1] |= (0 <<3);
    szAdtsHeader[1] |= (0 <<1);
    szAdtsHeader[1] |= 1;
    
    szAdtsHeader[2] = (audio_object_type - 1) << 6;
    szAdtsHeader[2] |= (sampling_frequency_index & 0x0f) << 2;
    szAdtsHeader[2] |= (0 << 1);
    szAdtsHeader[2] |= (channel_config & 0x04) >> 2;
    
    szAdtsHeader[3] = (channel_config & 0x03) << 6;
    szAdtsHeader[3] |= (0 << 5 );
    szAdtsHeader[3] |= (0 << 4);
    szAdtsHeader[3] |= (0 << 3);
    szAdtsHeader[3] |= (0 << 2);
    szAdtsHeader[3] |= ((adtsLen & 0x1800) >> 11);
    
    szAdtsHeader[4] = (uint8_t)((adtsLen & 0x7f8) >> 3);
    szAdtsHeader[5] = (uint8_t)((adtsLen & 0x7) << 5);
    szAdtsHeader[5] |= 0x1f;
    szAdtsHeader[6] = 0xfc;
}

int main(int argc, char *argv[]){
    
    int err_code;
    char errors[1024];
    
    char *src_filename = NULL;
    char *dst_filename = NULL;
    
    FILE *dst_fd = NULL;
    
    int audio_stream_index = -1;
    int len;
    
    AVFormatContext *ofmt_ctx = NULL;
    AVOutputFormat *output_fmt = NULL;
    
    AVStream *out_stream = NULL;
    
    AVFormatContext *fmt_ctx = NULL;
    AVFrame *frame = NULL;
    AVPacket pkt;
    
    av_log_set_level(AV_LOG_DEBUG);
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
    dst_fd = fopen(dst_filename, "wb");
    if (!dst_fd) {
        av_log(NULL, AV_LOG_DEBUG, "Could not open sources file:%s,%d(%s)\n", src_filename,
               err_code,
               errors);
        return -1;
    }
    
    if((err_code = avformat_find_stream_info(fmt_ctx, NULL)) < 0) {
        av_strerror(err_code, errors, 1024);
        av_log(NULL, AV_LOG_DEBUG, "failed to find stream information:%s, %d(%s)\n",
               src_filename,
               err_code,
               errors);
        return -1;
    }
    
    av_dump_format(fmt_ctx, 0, src_filename, 0);
/*    
    frame = av_frame_alloc();
    if(!frame) {
        av_log(NULL, AV_LOG_DEBUG, "Could not allocate frame\n");
        return AVERROR(ENOMEM);
    }
    
    av_init_packet(&pkt);
    pkt.data = NULL;
    pkt.size = 0;
    
    audio_stream_index = av_find_best_stream(fmt_ctx, AVMEDIA_TYPE_AUDIO, -1,-1,NULL, 0);
    
    if (audio_stream_index) {
        av_log(NULL, AV_LOG_DEBUG, "Could not find %s stream in input file %s\n", av_get_media_type_string(AVMEDIA_TYPE_AUDIO),src_filename);
        return AVERROR(EINVAL);
    }
    
    while(av_read_frame(fmt_ctx, &pkt) >= 0){
        if(pkt.stream_index == audio_stream_index){
            char adts_header_buf[7];
            adts_header(adts_header_buf, pkt.size);
            fwrite(adts_header_buf, 1, 7, dst_fd);
            
            len = fwrite(pkt.data, 1, pkt.size, dst_fd);
            if (len != pkt.size) {
                av_log(NULL, AV_LOG_DEBUG, "warning , length of writted (%d,%d)\n", len, pkt.size);
                
            }
        }
        av_packet_unref(&pkt);
    }
    */

    avformat_close_input(&fmt_ctx);
    if (dst_fd) {
        fclose(dst_fd);
    }
    return 0;
}

