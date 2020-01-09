//
//  testDecoder.cpp
//  AdvanceTest_01
//
//  Created by luowailin on 2019/8/1.
//  Copyright © 2019 luowailin. All rights reserved.
//

#include "testDecoder.hpp"
#define byte uint8_t

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

    pcmFile = fopen(pcmFilePath, "wb+");
    
#pragma mark -- 解复用
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
    
    av_dump_format(avFormatContext, 0, pcmFilePath, 0);
    
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
    if (avCodecContext->sample_fmt == AV_SAMPLE_FMT_S16) { //采样格式
        return true;
    }
    return false;
}

void DecoderAction::decodePacket(){
    
    //每次写入多少字节放入文件中
    int accompanySampleRate = avCodecContext->sample_rate;
    int accompanyByteCountPerSec = accompanySampleRate * 2 * 16 / 8;
    int packetBufferSize = (int)((accompanyByteCountPerSec / 2) * 0.2);
    
    while (true) {
        short *samples = new short[packetBufferSize];
        int stereoSampleSize = readSamples(samples, packetBufferSize);
        if (stereoSampleSize <= 0) {
            break;
        }
        fwrite(samples, sizeof(short), stereoSampleSize, pcmFile);
    }
}


int DecoderAction::readSamples(short *samples, int size){
    int sampleSize = size;
    //这个while循环是要达到一次要写入多少字节到文件中去，如果达到了，就进行一次写入
    while (size) {
        if (audioBufferCursor < audioBufferSize) { //直接把数据写入文件中
            int audioBufferDataSize = audioBufferSize - audioBufferCursor;
            int copySize = MIN(size, audioBufferDataSize); //保证把一次获取出来的数据全部写入完整
            
            memcpy(samples + (sampleSize - size), audioBuffer + audioBufferCursor, copySize * 2);
            size -= copySize;
            audioBufferCursor += copySize;
        } else { //读取数据
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
#pragma mark 获取流
        readFrameCode = av_read_frame(avFormatContext, &packet);
        if (readFrameCode >= 0) {
#pragma mark 读取数据包
            if (packet.stream_index == stream_index) {
                int len = avcodec_send_packet(avCodecContext, &packet);
                if (len < 0) {
                    printf("skip packet\n");
                }
                gotframe = avcodec_receive_frame(avCodecContext, pAudioFrame);
                if (gotframe == 0) { //每次解一帧数据 得到的是裸数据 pAudioFrame是保存的音频裸数据
                    int numChannels = 2;
                    int numFrames = 0;
                    void *audioData;
                    if (swrContext) {
                        const int ratio = 2;
                        //获取bufferSize就是要让swrBuffer有足够的存储空间，如果没有这个判断 这里会溢出
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
                                                outbuf,   //输出的
                                                pAudioFrame->nb_samples *ratio,    //输出的数量
                                                (const uint8_t **)pAudioFrame->data, //输入的
                                                pAudioFrame->nb_samples);  //输入的数量
                        
                        if (numFrames < 0) {
                            printf("fail resample audio\n");
                            ret = -1;
                            break;
                        }
                        audioData = swrBuffer;
                    } else { //WAV格式的会走在这里
                        /**
                         * WAVE(.wav)与PCM
                         * WAV格式的实质就是在PCM文件的前面加一个文件头。
                         * WAVE文件是RIFF格式的文件，其基本块名称是"WAVE"，其中包含了两个子块"fmt"和“data”.从编程的角度简单来说就是由WAVE_HEADER,WAVE_FMT,WAVE_DATA，采样数据(PCM数据)共4个部分组成。结构如下:
                         *
                         * 在写入WAVE文件头的时候给其中的每个字段赋上合适的值就可以了。但是有一点需要注意:WAVE_HEADER和WAVE_DATA中包含一个文件长度信息的dwSize字段，该字段的值必须在写入完音频采样数据之后才能获得。因此这两个结构体最后才写入WAVE文件中
                         */
                        typedef struct WAVE_HEADER{
                            char fccID[4];
                            unsigned long dwSize;
                            char fccType[4];
                        }WAVE_HEADER;
                        
                        typedef struct WAVE_FMT{
                            char fccID[4];
                            unsigned long dwSize;
                            unsigned short wFormatTag;
                            unsigned short wChannels;
                            unsigned long dwSamplesPerSec;
                            unsigned long dwAvgBytesPerSec;
                            unsigned short wBlockAlign;
                            unsigned short uiBitsPerSample;
                        }WAVE_FMT;
                        
                        typedef struct WAVE_DATA{
                            char fccID[4];
                            unsigned long dwSize;
                        }WAVE_DATA;
//                        if (avCodecContext->sample_fmt == AV_SAMPLE_FMT_S16) {
//                            printf("bucheck, audio format is invalid\n");
//                            ret = -1;
//                            break;
//                        }
                        audioData = pAudioFrame->data[0];
                        numFrames = pAudioFrame->nb_samples;
                    }
                    
                    audioBufferSize = numFrames * numChannels;
                    audioBuffer = (short *)audioData;
                    audioBufferCursor = 0;
                    break; //每次解一帧数据
                }
            }
        } else {
            ret = -1;
            break;
        }
    }
    av_packet_unref(&packet);
    return ret;
}

#pragma mark 释放资源
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
