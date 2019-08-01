//
//  testDecoder.cpp
//  AdvanceTest_01
//
//  Created by luowailin on 2019/8/1.
//  Copyright © 2019 luowailin. All rights reserved.
//

#include "testDecoder.hpp"

DecoderAction::DecoderAction(){

}

DecoderAction::~DecoderAction(){
   
}

int DecoderAction::Init(const char *filePath, const char *pcmFilePath) {
    audioBufferSize = 0;
    audioBufferCursor = 0;
    swrContext = nullptr;
    audioBuffer = nullptr;
    swrBuffer = nullptr;
    swrBufferSize = 0;
    
    avformat_network_init();
    avFormatContext = avformat_alloc_context();

    fopen(pcmFilePath, "wb+");
    
    int result = avformat_open_input(&avFormatContext,
                                     filePath,
                                     nullptr,
                                     nullptr);
    if (result != 0) {
        printf("can't open file %s result is %d\n", filePath, result);
        destroy();
        return -1;
    } else {
        printf("open success: %s\n", pcmFilePath);
    }
    
    if (avformat_find_stream_info(avFormatContext, nullptr) < 0) {
        printf("Couldn't find stream information\n");
        destroy();
        return -1;
    }
    
    
    stream_index = av_find_best_stream(avFormatContext,
                                       AVMEDIA_TYPE_AUDIO,
                                       -1,
                                       -1,
                                       nullptr,
                                       0);
    if (stream_index < 0) {
        printf("no audio stream");
        destroy();
        return -1;
    }
    
    AVStream *audioStream = avFormatContext->streams[stream_index];
    if (audioStream->time_base.den && audioStream->time_base.num) {
        timeBase = av_q2d(audioStream->time_base);
    }
    
    avCodecContext = avcodec_alloc_context3(nullptr);
    avcodec_parameters_to_context(avCodecContext,
                                  audioStream->codecpar);
    
    AVCodec *avCodec = avcodec_find_decoder(avCodecContext->codec_id);
    if (avCodec == nullptr) {
        printf("unsupported codec\n");
        destroy();
        return -1;
    }
    
    result = avcodec_open2(avCodecContext,
                           avCodec,
                           nullptr);
    if (result < 0) {
        printf("faile avformat_find_info\n");
        destroy();
        return -1;
    }
    
    if (!audioCodecIsSupported()) {
        
        swrContext = swr_alloc_set_opts(nullptr,
                                        av_get_default_channel_layout(2),
                                        AV_SAMPLE_FMT_S16,
                                        avCodecContext->sample_rate,
                                        av_get_default_channel_layout(avCodecContext->channels),
                                        avCodecContext->sample_fmt,
                                        avCodecContext->sample_rate,
                                        0,
                                        nullptr);
        
        if (!swrContext || swr_init(swrContext)) {
            printf("init resample failed");
            destroy();
            return -1;
        }
    }
    
    
    pAudioFrame = av_frame_alloc();
    return 1;
}

bool DecoderAction::audioCodecIsSupported(){
    
    if (avCodecContext->sample_fmt == AV_SAMPLE_FMT_S16) {
        return true;
    }
    
    return false;
}

void DecoderAction::decodePacket(){
    
    int accompanySampleRate = avCodecContext->sample_rate;
    int accompanyByteCountPerSec = accompanySampleRate * 2 * 16 / 8;
    int packetBufferSize = (int)((accompanyByteCountPerSec / 2) * 0.2);
    
    while (true) {
        short *samples = new short[packetBufferSize];
        int stereoSampleSize = readSamples(samples, packetBufferSize);
        if (stereoSampleSize <= 0) {
            break;
        }
        fwrite(nullptr, sizeof(short), stereoSampleSize, pcmFile);
    }
}


int DecoderAction::readSamples(short *samples, int size){
    int sampleSize = size;
    while (size) {
        if (audioBufferCursor < audioBufferSize) {
            int audioBufferDataSize = audioBufferSize - audioBufferCursor;
            int copySize = MIN(size, audioBufferDataSize);
            
            memcpy(samples + (sampleSize - size), audioBuffer + audioBufferCursor, copySize * 2);
            size -= copySize;
            audioBufferCursor += copySize;
        } else {
            if (readFrame() < 0) {
                break;
            }
        }
    }
    
    int fillSize = sampleSize - size;
    if (fillSize == 0) {
        return -1;
    }
    return fillSize;
}

int DecoderAction::readFrame(){
    int ret = 1;
    av_init_packet(&packet);
    int gotframe = 0;
    int readFrameCode = -1;

    while (true) {
        readFrameCode = av_read_frame(avFormatContext, &packet);
        if (readFrameCode >= 0) {
            if (packet.stream_index == stream_index) {
                int len = avcodec_send_packet(avCodecContext, &packet);
                if (len < 0) {
                    printf("skip packet\n");
                }
                gotframe = avcodec_receive_frame(avCodecContext, pAudioFrame);
                if (gotframe == 0) {
                    int numChannels = 2;
                    int numFrames = 0;
                    void *audioData;
                    if (swrContext) {
                        const int ratio = 2;
                        const int bufSize = av_samples_get_buffer_size(nullptr,
                                                                       numChannels,
                                                                       pAudioFrame->nb_samples * ratio,
                                                                       AV_SAMPLE_FMT_S16,
                                                                       1);
                        
                        if (!swrBuffer || swrBufferSize < bufSize) {
                            swrBufferSize = bufSize;
                            swrBuffer = realloc(swrBuffer, swrBufferSize);
                        }
                        
                        uint8_t *outbuf[2] = {(uint8_t *)swrBuffer, nullptr};
                        numFrames = swr_convert(swrContext,
                                                outbuf,
                                                pAudioFrame->nb_samples * ratio,
                                                (const uint8_t *)pAudioFrame->data,
                                                pAudioFrame->nb_samples);
                        
                        
                    }
                }
            }
        }
    }
}


void DecoderAction::destroy(){
    
    if (swrBuffer != nullptr) {
        free(swrBuffer);
        swrBuffer = nullptr;
        swrBufferSize = 0;
    }
    
    if (pAudioFrame != nullptr) {
        av_free(pAudioFrame);
        pAudioFrame = nullptr;
    }
    
    if (avCodecContext != nullptr) {
        avcodec_close(avCodecContext);
        avCodecContext = nullptr;
    }
    
    if (swrContext != nullptr) {
        swr_free(&swrContext);
        swrContext = nullptr;
    }
    
    if (avFormatContext != nullptr) {
        avformat_close_input(&avFormatContext);
        avFormatContext = nullptr;
    }
    
    if (pcmFile != nullptr) {
        fclose(pcmFile);
        pcmFile = nullptr;
    }
}
