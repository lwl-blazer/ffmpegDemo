//
//  accompany_decoder.cpp
//  AdvanceTest_01
//
//  Created by luowailin on 2019/8/1.
//  Copyright © 2019 luowailin. All rights reserved.
//

#include "accompany_decoder.hpp"

#define LOG_TAG "AccompanyDecoder"

AccompanyDecoder::AccompanyDecoder(){
    this->seek_seconds = 0.0;
    this->seek_resp = false;
    this->seek_req = false;
    accompanyFilePath = nullptr;
}

AccompanyDecoder::~AccompanyDecoder(){
    if (accompanyFilePath != nullptr) {
        delete [] accompanyFilePath;
        accompanyFilePath = nullptr;
    }
}

int AccompanyDecoder::getMusicMeta(const char *fileString, int *metaData){
    init(fileString);
    int sampleRate = avCodecContext->sample_rate;
    LOGI("sampleRate is %d", sampleRate);
    
    int bitRate = (int)avCodecContext->bit_rate;
    LOGI("bit_rate is %d", bitRate);
    destroy();
    metaData[0] = sampleRate;
    metaData[1] = bitRate;
    return 0;
}

void AccompanyDecoder::init(const char *fileString, int packetBufferSizeParam){
    init(fileString);
    packetBufferSize = packetBufferSizeParam;
}

int AccompanyDecoder::init(const char *fileString){
    
    LOGI("enter AccompanyDecoder::init");
    audioBuffer = nullptr;
    position = -1.0f;
    audioBufferCursor = 0;
    audioBufferSize = 0;
    
    swrContext = nullptr;
    swrBuffer = nullptr;
    swrBufferSize = 0;
    seek_success_read_frame_success = true;
    isNeedFirstFrameCorrectFlag = true;
    firstFrameCorrectionInSecs = 0.0;
    
    avformat_network_init();
    avFormatContext = avformat_alloc_context();
    //打开输入文件
    LOGI("open accompany file %s..", fileString);
    
    if (accompanyFilePath == nullptr) {
        int length = (int)strlen(fileString);
        //+1的原因是由于最后一个是'\0'
        accompanyFilePath = new char[length + 1];
        memset(accompanyFilePath, 0, length + 1);
        memcpy(accompanyFilePath, fileString, length + 1);
    }
#pragma mark -- 解复用
    int result = avformat_open_input(&avFormatContext,
                                     fileString,
                                     nullptr, nullptr);
    if (result != 0) {
        LOGI("can't open file %s result is %d", fileString, result);
        return -1;
    } else {
        LOGI("open file %s success and result is %d", fileString, result);
    }
    avFormatContext->max_analyze_duration = 50000;
    
    //检查在文件中的流的信息
    if (avformat_find_stream_info(avFormatContext, NULL) < 0) {
        LOGI("Couldn't find stream information");
        return -1;
    } else {
        LOGI("sucess avformat_find_stream_info result is %d", result);
    }
    
    stream_index = av_find_best_stream(avFormatContext,
                                       AVMEDIA_TYPE_AUDIO,
                                       -1,
                                       -1,
                                       nullptr,
                                       0);
    if (stream_index == -1) { //没有音频
        LOGI("no audio stream");
        return -1;
    } else {
        LOGI("stream index is %d", stream_index);
    }
    
    //音频流
    AVStream *audioStream = avFormatContext->streams[stream_index];
    if (audioStream->time_base.den && audioStream->time_base.num) { //时间基
        timeBase = av_q2d(audioStream->time_base);
    } else if (audioStream->time_base.den && audioStream->time_base.num) {
        timeBase = av_q2d(audioStream->time_base);
    }
    
    //获取音频流解码器上下文
    //avCodecContext = audioStream->codec;
    avCodecContext = avcodec_alloc_context3(nullptr);
    avcodec_parameters_to_context(avCodecContext, audioStream->codecpar);
    
    LOGI("avCodecContext->codec_id is %d AV_CODEC_ID_AAC is %d", avCodecContext->codec_id, AV_CODEC_ID_AAC);
    //根据解码器上下文找到解码器
    AVCodec *avCodec = avcodec_find_decoder(avCodecContext->codec_id);
    if (avCodec == nullptr) {
        LOGI("unsupported codec");
        return -1;
    }
    
    //打开解码器
    result = avcodec_open2(avCodecContext,
                           avCodec,
                           nullptr);
    if (result < 0) {
        LOGI("fail avformat_find_stream_info result is %d", result);
        return -1;
    } else {
        LOGI("sucess avformat_find_stream_info result is %d", result);
    }
    
    //判断是否需要resampler
    if (!audioCodecIsSupported()) {
        LOGI("because of audio Codec Is Not Supported so we will init swresampler...");
        /** 重采样 * 改变音频的采样率、sample rate、声道数等参数,使之按照我们期望的参数输出 */
        //分配SwrContext并设置/重置常用的参数
        swrContext = swr_alloc_set_opts(nullptr,
                                        av_get_default_channel_layout(OUT_PUT_CHANNELS),
                                        AV_SAMPLE_FMT_S16,
                                        avCodecContext->sample_rate,
                                        av_get_default_channel_layout(avCodecContext->channels),
                                        avCodecContext->sample_fmt,
                                        avCodecContext->sample_rate,
                                        0,
                                        nullptr);
        if (!swrContext || swr_init(swrContext)) { //swr_init() 当设置好相关的参数后，初始化SwrContext结构体
            if (swrContext) {
                swr_free(&swrContext);
            }
            avcodec_close(avCodecContext);
            LOGI("init resample failed...");
            return -1;
        }
    }
    
    LOGI("channels is %d sampleRate is %d", avCodecContext->channels, avCodecContext->sample_rate);
    pAudioFrame = av_frame_alloc();
    return 1;
}

bool AccompanyDecoder::audioCodecIsSupported(){
    if (avCodecContext->sample_fmt == AV_SAMPLE_FMT_S16) {
        return true;
    }
    return false;
}

AudioPacket* AccompanyDecoder::decodePacket(){
    short *samples = new short[packetBufferSize];
    int stereoSampleSize = readSamples(samples, packetBufferSize);
    AudioPacket *samplePacket = new AudioPacket();
    if (stereoSampleSize > 0) {
        //构造成一个packet
        samplePacket->buffer = samples;
        samplePacket->size = stereoSampleSize;
        /**这里由于每一个paceket的大小不一样有可能是200ms 但是这样子position就有可能不准确了*/
        samplePacket->position = position;
    } else {
        samplePacket->size = -1;
    }
    return samplePacket;
}

int AccompanyDecoder::readSamples(short *samples, int size){
    if (seek_req) {
        audioBufferCursor = audioBufferSize;
    }
    
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

void AccompanyDecoder::seek_frame(){
    LOGI("\n seek frame firstFrameCorrectionInSecs is %.6f, seek_seconds=%f, position=%f \n", firstFrameCorrectionInSecs, seek_seconds, position);
    float targetPosition = seek_seconds;
    float currentPosition = position;
    float frameDuration = duration;
    
    if (targetPosition < currentPosition) {
        this->destroy();
        this->init(accompanyFilePath);
        //TODO:这里的GT的测试样本会差距25ms 不会累加
        currentPosition = 0.0;
    }
    
    int readFrameCode = -1;
    while (true) {
        av_init_packet(&packet);
        readFrameCode = av_read_frame(avFormatContext, &packet);
        if (readFrameCode >= 0) {
            currentPosition += frameDuration;
            if (currentPosition >= targetPosition) {
                break;
            }
        }
        
        av_free(&packet);
    }
    
    seek_resp = true;
    seek_req = false;
    seek_success_read_frame_success = false;
}

//解码
int AccompanyDecoder::readFrame(){
    if (seek_req) {
        this->seek_frame();
    }
    int ret = 1;
    
    av_init_packet(&packet);
    int gotframe = 0;
    int readFrameCode = -1;
    while (true) {
        readFrameCode = av_read_frame(avFormatContext, &packet);  //得到的是AVPacket   对于音频流，一个AVPacket可能包含多个AVFrame,但是对于视频流一个AVPacket只包含一个AVFrame
        if (readFrameCode >= 0) { //read frame success
            if (packet.stream_index == stream_index) {
                int len = avcodec_send_packet(avCodecContext, &packet);
                /*int len = avcodec_decode_audio4(avCodecContext,
                                                pAudioFrame,
                                                &gotframe,
                                                &packet);*/ //解码--解码出原始数据
                if (len < 0) {
                    LOGI("decode audio error, skip packet");
                }
                //avcodec_send_packet avcodec_receive_frame 配套出现
                gotframe = avcodec_receive_frame(avCodecContext, pAudioFrame);

                if (gotframe == 0) {
                    int numChannels = OUT_PUT_CHANNELS;
                    int numFrames = 0;
                    void *audioData;
                    if (swrContext) {
                        const int ratio = 2;
                        //此函数用于音频，计算编码每一帧给编码器需要多少字节，然后我们自己再分配空间，填充到初始化AVFrame中
                        const int bufSize = av_samples_get_buffer_size(nullptr,
                                                                       numChannels,
                                                                       pAudioFrame->nb_samples * ratio,
                                                                       AV_SAMPLE_FMT_S16,
                                                                       1);
                        if (!swrBuffer || swrBufferSize < bufSize) {
                            swrBufferSize = bufSize;
                            swrBuffer = realloc(swrBuffer, swrBufferSize);
                        }
                        byte *outbuf[2] = {(byte *)swrBuffer, nullptr};
                        //numFrames 返回每个通道输出的样本数   按照swrContext设置的参数进行转换并输出
                        numFrames = swr_convert(swrContext,
                                                outbuf,   //输出的
                                                pAudioFrame->nb_samples *ratio,    //输出的数量
                                                (const uint8_t **)pAudioFrame->data, //输入的
                                                pAudioFrame->nb_samples);  //输入的数量
                        if (numFrames < 0) {
                            LOGI("fail resample audio");
                            ret = -1;
                            break;
                        }
                        //得到重采样的数据
                        audioData = swrBuffer;
                    } else {
                        if (avCodecContext->sample_fmt != AV_SAMPLE_FMT_S16) {
                            LOGI("bucheck, audio format is invalid");
                            ret = -1;
                            break;
                        }
                        audioData = pAudioFrame->data[0];
                        numFrames = pAudioFrame->nb_samples;
                    }
                    
                    if (isNeedFirstFrameCorrectFlag && position >= 0) {
                        float expectedPosition = position + duration;
                        //float actualPosition = av_frame_get_best_effort_timestamp(pAudioFrame) * timeBase;
                        float actualPosition = pAudioFrame->best_effort_timestamp * timeBase;
                        firstFrameCorrectionInSecs = actualPosition - expectedPosition;
                        isNeedFirstFrameCorrectFlag = false;
                    }
                    
//                    duration = av_frame_get_pkt_duration(pAudioFrame) * timeBase;
//                    position = av_frame_get_best_effort_timestamp(pAudioFrame) * timeBase - firstFrameCorrectionInSecs;
                    duration = pAudioFrame->pkt_duration * timeBase;
                    position = pAudioFrame->best_effort_timestamp * timeBase - firstFrameCorrectionInSecs;
                    
                    if (!seek_success_read_frame_success) {
                        LOGI("position is %.6f", position);
                        actualSeekPosition = position;
                        seek_success_read_frame_success = true;
                    }
                    
                    audioBufferSize = numFrames * numChannels;
                    
                    audioBuffer = (short *)audioData;
                    audioBufferCursor = 0;
                    break;
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


void AccompanyDecoder::destroy(){
    if (swrBuffer != nullptr) {
        free(swrBuffer);
        swrBuffer = nullptr;
        swrBufferSize = 0;
    }
    
    if (swrContext != nullptr) {
        swr_free(&swrContext);
        swrContext = nullptr;
    }
    
    if (pAudioFrame != nullptr) {
        av_free(pAudioFrame);
        pAudioFrame = nullptr;
    }
    
    if (avCodecContext != nullptr) {
        avcodec_close(avCodecContext);
        avCodecContext = nullptr;
    }
    
    if (avFormatContext != nullptr) {
        LOGI("leave LiveReceiver::destory");
        avformat_close_input(&avFormatContext);
        avFormatContext = nullptr;
    }
}
