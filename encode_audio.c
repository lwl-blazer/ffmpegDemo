#include <stdint.h>
#include <stdio.h>
#include <stdlib.h>

#include <libavcodec/avcodec.h>

#include <libavutil/channel_layout.h>
#include <libavutil/common.h>
#include <libavutil/frame.h>
#include <libavutil/samplefmt.h>

static int check_sample_fmt(const AVCodec *codec, enum AVSampleFormat sample_fmt){
    
    while (*p != AV_SAMPLE_FMT_NONE) {
        if (*p == sample_fmt) {
            return 1;
        }
        p++;
    }
    return 0;
}

static int select_sample_rate(const AVCodec *codec) {
    const int *p;
    int best_samplerate = 0;
    
    if (!codec->supported_samplerates) {
        return 44100;
    }
    
    p = codec->supported_samplerates;
    while (*p) {
        if (!best_samplerate || abs(44100 - *p) < abs(44100 - best_samplerate)) {
            best_samplerate = *p;
        }
        p++;
    }
    return best_samplerate;
}

static int select_channel_layout(const AVCodec *codec) {
    const uint64_t *p;
    uint64_t best_ch_layout = 0;
    int best_nb_channels = 0;
    
    if (!codec->channel_layout) {
        return AV_CH_LAYOUT_STEREO;
    }
    
    p = codec->channel_layouts;
    while (*p) {
        int nb_channels = av_get_channel_layout_nb_channels(*p);
        
        if(nb_channels > best_nb_channels) {
            best_ch_layout = *p;
            best_nb_channels = nb_channels;
        }
        
        p++;
    }
    return best_ch_layout;
}


int main(int argc, char **argv) {
    const char *filename;
    const AVCodec *codec;
    AVCodecContext *c = NULL;
    AVFrame *frame;
    AVPacket pkt;
    int i, j, k, ret, got_output;
    FILE *f;
    uint16_t *samples;
    float t, tincr;
    
    if (argc <= 1) {
        fprintf(stderr, "Usage:%s <output file>\n", argv[0]);
        return 0;
    }
    
    filename = argv[1];
    
    avcodec_register_all();
    codec = avcodec_find_encoder(AV_CODEC_ID_MP2);
    if (!codec) {
        fprintf(stderr, "Codec not found\n");
        exit(1);
    }
    
    c = avcodec_alloc_context3(codec);
    if (!c) {
        fprintf("stderr", "Could not allocate audio codec context \n");
        exit(1);
    }
    
    c->bit_rate = 64000;
    
    c->sample_fmt = AV_SAMPLE_FMT_S16;
    
}

