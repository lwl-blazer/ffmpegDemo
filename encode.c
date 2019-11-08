#include <libavutil/opt.h>
#include <libavcodec/avcodec.h>
#include <libavutil/channel_layout.h>
#include <libavutil/common.h>
#include <libavutil/imgutils.h>
#include <stdio.h>


static void video_encode_example(const char *filename, int codec_id){
    AVCodec *codec;
    AVCodecContext *c = NULL;
    int i, ret, x, y, got_outopt;
    FILE *f;
    AVFrame *frame;
    AVPacket pkt;
    
    uint8_t endcode[] = {0, 0, 1, 0xb7};
    
    printf("Encode Video file %s\n", filename);
    
    codec = avcodec_find_encoder(codec_id);
    if (!codec) {
        fprintf(stderr, "Codec not found\n");
        exit(1);
    }
    
    c = avcodec_alloc_context3(codec);
    if (!c) {
        fprintf(stderr, "Could not allocate video codec context\n");
        exit(1);
    }
    
    c->bit_rate = 400000;
    c->width = 352;
    c->height = 288;
    c->time_base = (AVRational){1, 25};
    
    c->gop_size = 10;
    c->max_b_frames = 1;
    c->pix_fmt = AV_PIX_FMT_YUV420P;
    
    if (codec_id == AV_CODEC_ID_H264) {
        av_opt_set(c->priv_data, "preset", "slow", 0);
    }
    
    if (avcodec_open2(c, codec, NULL) < 0) {
        fprintf(stderr, "Could not open codec\n");
        exit(1);
    }
    
    
    f = fopen(filename, "wb");
    if (!f) {
        fprintf(stderr, "Could not open %s\n", filename);
        exit(1);
    }
    
    frame = av_frame_alloc();
    if (!frame) {
        fprintf(stderr, "Could not allocate video frame\n");
        exit(1);
    }
    
    frame->format = c->pix_fmt;
    frame->width = c->width;
    frame->height = c->height;
    
    ret = av_image_alloc(frame->data, frame->linesize, c->width, c->height, c->pix_fmt, 32);
    if (ret < 0) {
        fprintf(stderr, "Could not allocate raw picture buffer\n");
        exit(1);
    }
    
    for (i = 0; i< 25; i++) {
        av_init_packet(&pkt);
        pkt.data = NULL;
        pkt.size = 0;
        
        fflush(stdout);
        for (y = 0; y < c->height; y++) {
            for (x = 0; x < c->width; x ++) {
                frame->data[0][y * frame->linesize[0] + x] = x + y + i * 3;
            }
        }
        
        for (y = 0; y < c->height / 2; y ++) {
            for (x = 0; x < c->width / 2; x ++) {
                frame->data[1][y * frame->linesize[1] + x] = 128 + y + i * 2;
                frame->data[2][y * frame->linesize[2] + x] = 64 + x + i * 5;
            }
        }
        
        frame->pts = i;
        
        ret = avcodec_encode_video2(c, &pkt, frame, &got_outopt);
        if (ret < 0) {
            fprintf(stderr, "Error encoding frame\n");
            exit(1);
        }
        
        if (got_outopt) {
            printf("Write frame %3d (size=%5d)\n", i , pkt.size);
            fwrite(pkt.data, 1, pkt.size, f);
            av_free_packet(&pkt);
        }
    }
    
    for (got_outopt = 1; got_outopt; i ++) {
        fflush(stdout);
        ret = avcodec_encode_video2(c, &pkt, NULL, &got_outopt);
        if (ret < 0) {
            fprintf(stderr, "Error encoding frame\n");
            exit(1);
        }
        
        if (got_outopt) {
            printf("Write frame %3d (size=%5d)\n", i, pkt.size);
            fwrite(pkt.data, 1, pkt.size, f);
            av_free_packet(&pkt);
        }
    }
    
    
    fwrite(endcode, 1, sizeof(endcode), f);
    fclose(f);
    
    avcodec_close(c);
    av_free(c);
    av_freep(&frame->data[0]);
    av_frame_free(&frame);
    printf("\n");
}


int main(int argc, char **argv){
    const char *output_type;
    if (argc < 2) {
        printf("usage: %s outputtype", argv[0]);
        return 1;
    }
    
    output_type = argv[1];
    const char *filename = argv[0];
    video_encode_example(filename, AV_CODEC_ID_H264);
    return 0;
}
