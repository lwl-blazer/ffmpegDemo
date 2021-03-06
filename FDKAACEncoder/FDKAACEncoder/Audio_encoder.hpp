//
//  Audio_encoder.hpp
//  FDKAACEncoder
//
//  Created by luowailin on 2019/10/21.
//  Copyright © 2019 luowailin. All rights reserved.
//
//  使用FFmpeg 进行软编码

#ifndef Audio_encoder_hpp
#define Audio_encoder_hpp

#include <stdio.h>
#include <stdlib.h>
#include <time.h>

#ifndef UINT64_C
#define UINT64_C(value)__CONCAT(value, ULL)
#endif

#define byte uint8_t

#define LOGI(...) printf(" "); printf(__VA_ARGS__); printf("\t - <%s> \n", LOG_TAG);

extern "C" {
#include "libavcodec/avcodec.h"
#include "libavformat/avformat.h"
#include "libavutil/avutil.h"
#include "libswresample/swresample.h"
#include "libavutil/samplefmt.h"
#include "libavutil/common.h"
#include "libavutil/channel_layout.h"
#include "libavutil/opt.h"
#include "libavutil/imgutils.h"
#include "libavutil/mathematics.h"
};

#ifndef PUBLISH_BITE_RATE
#define PUBLISH_BITE_RATE 64000
#endif

/** 利用FFmpeg 对音频进行编码操作 方便拓展 可以使用Android和iOS */
class AudioEncoder{
private:
    AVFormatContext *avFormatContext;
    AVCodecContext *avCodecContext;
    AVStream *audioStream;
    
    bool isWriteHeaderSuccess;
    double duration;
    
    AVFrame *input_frame;
    int buffer_size;
    uint8_t *samples;
    int samplesCursor;
    SwrContext *swrContext;
    uint8_t **convert_data;
    AVFrame *swrFrame;
    uint8_t *swrBuffer;
    int swrBufferSize;
    
    int publishBitRate;
    int audioChannels;
    int audioSampleRate;
    
    int totalSWRTimeMills;
    int totalEncodeTimeMills;
    
    //初始化的时候 要进行的工作
    int alloc_avframe();
    int alloc_audio_stream(const char *codec_name);
    //当够一个frame之后就要编码成一个packet
    void encodePacket();
    
public:
    AudioEncoder();
    virtual ~AudioEncoder();
    
    /** 初始化
     * @param bitRate 比特率  ---最终编码出来的文件的码率
     * @param channels 声道数
     * @param sampleRate 采样率
     * @param bitsPerSample 每个采样的bit大小
     * @param accFilePath 最终编码的文件路径
     * @param codec_name 编码器名字
     */
    int init(int bitRate, int channels, int sampleRate, int bitsPerSample, const char *accFilePath, const char *codec_name);
    int init(int bitRate, int channels, int bitsPerSample, const char *aacFilePath, const char *codec_name);
    
    //编码
    void encode(byte *buffer, int size);
    
    //销毁
    void destroy();
};

#endif /* Audio_encoder_hpp */
