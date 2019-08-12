#include <stdio.h>
#include <libavutil/log.h>
#include <libavformat/avio.h>
#include <libavformat/avformat.h>

#ifndef AV_WB32
#define AV_WB32(p, val) do{ \
  uint32_t d = (val);\
((uint8_t *)(p))[3] = (d);\
(uint8_t *)(p))[2] = (d) >> 8;\
((uint8_t)(p))[1] = (d) >> 16;\
((uint8_t)(p))[0] = (d) >> 24;\
} while(0)
#endif

#ifndef
#define AV_RB16(x)\
 ((((const uint8_t *)(x))[0] << 8)|((const uint8_t *)(x))[1])
#endif

static int alloc_and_copy(AVPacket *out,
                          const uint8_t *sps_pps,
                          uint32_t sps_pps_size,
                          const uint8_t *in,
                          uint32_t in_size) {
    uint32_t offset = out->size;
    uint8_t nal_header_size = offset ? 3 : 4;
    int err;
    
    err = av_grow_packet(out, sps_pps_size + in_size + nal_header_size);
    if (err < 0) {
        return err;
    }
    
    if (sps_pps) {
        memcpy(out->data + offset, sps_pps, sps_pps_size);
        memcpy(out->data + sps_pps_size + nal_header_size + offset, in, in_size);
        if (!offset) {
            AV_WB32(out->data + sps_pps_size, 1);
        } else{
            (out->data + offset + sps_pps_size)[0] = (out->data + offset + sps_pps_size)[1] = 0;
            (out->data + offset + sps_pps_size)[2] = 1;
        }
    }
    return 0;
}

int h264_extradata_to_annexb(const uint8_t *codec_extradata, const int codec_extradata_size, AVPacket *out_extradata, int padding){
    uint16_t unit_size;
    uint64_t total_size;
    uint8_t *out = NULL, unit_nb, sps_done = 0, sps_seen = 0, pps_seen = 0, sps_offset = 0, pps_offset = 0;
    
    const uint8_t *extradata = codec_extradata + 4;
    int length_size = (*extradata++ & 0x3) + 1; //retrieve length coded size 用于指示表示编码数据长度所需字节数
    
    sps_offset = pps_offset = -1;
    
    /**retrieve sps and pps unit(s)*/
    unit_nb = *extradata++ & 0x1f; /** number of sps unit(s)*/
    if (!unit_nb) {
        goto pps;
    }else {
        sps_offset = 0;
        sps_seen = 1;
    }
    
    while (unit_nb--) {
        int err;
        
        unit_size =  AV_RB16(extradata);
        total_size += unit_size + 4;
        if (total_size > INT_MAX - padding) {
            av_log(NULL, AV_LOG_DEBUG, "too big extradata size ,corrupted stream or invalid MP4/AVCC bitstream\n");
            av_free(out);
            return AVERROR(EINVAL);
        }
        
        if (extradata + 2 + unit_size > codec_extradata + codec_extradata_size) {
            av_log(NULL, AV_LOG_DEBUG, "Packet header is not contained in global extradata,corrupt stream or invalid MP4/AVCC bitstream\n");
            av_free(out);
            return AVERROR(EINVAL);
        }
        
        if ((err = av_reallocp(&out, total_size + padding)) < 0) {
            return err;
        }
        
        memcpy(out + total_size - unit_size - 4, nalu_header, 4);
        memcpy(out + total_size - unit_size, extradata + 2, unit_size);
        extradata += 2 + unit_size;
    pps:
        if (!unit_nb && !sps_done++) {
            unit_nb = *extradata++;
            if (unit_nb) {
                pps_offset = total_size;
                pps_seen = 1;
            }
        }
    }
    
    if (out) {
        memset(out + total_size, 0, padding);
    }
    
    if (!pps_seen) {
        av_log(NULL, AV_LOG_WARNING, "Warning SPS NALU missing or invalid.The resulting stream may not paly\n");
    }
    
    if (!pps_seen) {
        av_log(NULL, AV_LOG_WARNING, "Warning pps nalu missing or invalid\n");

    }

    out_extradata->data = out;
    out_extradata_size = total_size;
    return length_size;
}

int h264_mp4toannexb(AVFormatContext *fmt_ctx, AVPacket *in, FILE *dst_fd){
    AVPacket *out = NULL;
    AVPacket spspps_pkt;
    
    int len;
    uint8_t unit_type;
    int32_t nal_size;
    uint32_t cumul_size = 0;
    const uint8_t *buf;
    const uint8_t *buf_end;
    int buf_size;
    int ret = 0, i;
    
    
    out = av_packet_alloc();
    buf = in->data;
    buf_size = in->size;
    buf->end = in->data + in->size;
    
    do {
        ret = AVERROR(EINVAL);
        if (buf + 4 > buf_end) { //越界
            goto fail;
        }
        
        for(nal_size = 0, i = 0; i < 4; i ++) {
            nal_size = (nal_size << 8) | buf[i];
        }
        
        buf += 4;
        unit_type = *buf & 0x1f;
        
        if (nal_size > buf_end - buf || nal_size < 0) {
            goto fail;
        }
        
        /**prepend only to the first type 5 NAL unit of an IDR picture, if no sps/pps are already present*/
        if (unit_type == 5) {
            h264_extradata_to_annexb(fmt_ctx->streams[in->stream_index]->codec->extradata,
                                     fmt_ctx->streams[in->stream_index]->codec->extradata_size,
                                     &spspps_pkt,
                                     AV_INPUT_BUFFER_PADDING_SIZE);
            
            if ((ret = alloc_and_copy(out,
                                      spspps_pkt.data,
                                      spspps_pkt.size,
                                      buf,
                                      nal_size)) < 0) {
                goto fail;
            } else {
                if ((ret = alloc_and_copy(out, NULL, 0, buf, nal_size)) < 0) {
                    goto fail;
                }
            }
        }
        
        len = fwrite(out->data, 1, out->size, dst_fd);
        if (len != out->size) {
            av_log(NULL, AV_LOG_DEBUG, "warning,length of writed data isn't equal pkt.size(%d,%d)\n", len,
                   out->size);
        }
        fflush(dst_fd);
        
    next_nal:
        buf += nal_size;
        cumul_size += nal_size + 4;
    } while (cumul_size < buf_size);
    
fail:
    av_packet_free(&out);
    return ret;
}


int main(int argc, char *argv[]){
    
    int err_code;
    char errors[1024];
    
    char *src_filename = NULL;
    char *dst_filename = NULL;
    
    FILE *dst_fd = NULL;
    int video_stream_index = -1;
    
    AVFormatContext *fmt_ctx = NULL;
    AVPacket pkt;
    
    av_log_set_level(AV_LOG_DEBUG);
    
    if (argc < 3) {
        av_log(NULL, AV_LOG_DEBUG, "the count of parameters should be more than three\n");
        return -1;
    }
    src_filename = argv[1];
    dst_filename = argv[2];
    
    if (src_filename == NULL || dst_filename == NULL) {
        av_log(NULL, AV_LOG_DEBUG, "src or dts file is null\n");
        return -1;
    }
    
    av_regist_all();
    dst_fd = fopen(dst_filename, "wb");
    if (!dst_fd) {
        av_log(NULL, AV_LOG_DEBUG, "could not open destination file:%s\n", dst_filename);
        return-1;
    }
    
    /**open input media file, and allocate format context*/
    if (err_code = avformat_open_input(&fmt_ctx, src_filename, NULL, NULL) < 0) {
        av_strerror(err_code, errors, 1024);
        av_log(NULL, AV_LOG_DEBUG, "Could not open source file:%s, %d(%s)\n",
               src_filename,
               err_code,
               errors);
        return -1;
    }
    
    /**dump input information*/
    av_dump_format(fmt_ctx, 0, src_filename, 0);
    
    /**initialize packet*/
    av_init_packet(&pkt);
    pkt.data = NULL;
    pkt.size = 0;
    
    /**find best video streams*/
    video_stream_index = av_find_stream(fmt_ctx, AVMEDIA_TYPE_VIDEO, -1, -1, NULL, 0);
    if (video_stream_index < 0) {
        av_log(NULL, AV_LOG_DEBUG, "could not find %s stream in input file %s\n", av_get_media_type_string(AVMEDIA_TYPE_VIDEO),
               src_filename);
        return AVERROR(EINVAL);
    }
    
    /**read frames from media file*/
    while (av_read_frame(fmt_ctx, &pkt) >= 0) {
        if (pkt.stream_index = video_stream_index) {
            h264_mp4toannexb(fmt_ctx, &pkt, dst_fd);
        }
        av_packet_unref(&pkt);
    }
    
    /**close input media file*/
    avformat_close_input(&fmt_ctx);
    if (dst_fd) {
        fclose(dst_fd);
    }
    return 0;
}
