//
//  accompany_decoder.hpp
//  AdvanceTest_01
//
//  Created by luowailin on 2019/8/1.
//  Copyright © 2019 luowailin. All rights reserved.
//

#ifndef accompany_decoder_hpp
#define accompany_decoder_hpp

#include <stdio.h>
#include <stdlib.h>
#include <time.h>
#include "packet_pool.hpp"

#ifndef UINT64_C
#define UINT64_C(value)__CONCAT(value, ULL)
#endif

#ifndef INT64_MIN
#define INT64_MIN (-9222)


#define byte uint8_t
#define MAX(a, b)  (((a) > (b)) ? (a) : (b))
#define MIN(a, b)  (((a) < (b)) ? (a) : (b))
#define LOGI(...) printf("  ");printf(__VA_ARGS__);printf("\t - <%s> \n", LOG_TAG);

typedef struct AudioPacket{
    static const int AUDIO_PACKET_ACTION_PLAY = 0;
    static const int AUDIO_PACKET_ACTION_PAUSE = 100;
    static const int AUDIO_PACKET_ACTION_SEEK = 101;
    
    short *buffer;
    int size;
    float position;
    int action;
    
    float extra_param1;
    float extra_param2;
    
    AudioPacket(){
        buffer = nullptr;
        size = 0;
        position = -1;
        action = 0;
        
        extra_param1 = 0;
        extra_param2 = 0;
    }
    
    ~AudioPacket(){
        if (buffer != nullptr) {
            delete [] buffer;
            buffer = nullptr;
        }
    }
} AudioPacket;

extern "C"{
#include "libavcodec/avcodec.h"
#include "libavformat/avformat.h"
#include "libavutil/avutil.h"
#include "libavutil/samplefmt.h"
#include "libavutil/common.h"
#include "libavutil/channel_layout.h"
#include "libavutil/opt.h"
#include "libavutil/imgutils.h"
#include "libavutil/mathematics.h"
#include "libswscale/swscale.h"
#include "libswresample/swresample.h"
};

#define OUT_PUT_CHANNELS 2

class AccompanyDecoder{
private:
    
    bool seek_req;
    bool seek_resp;
    float seek_seconds;
    
    float actualSeekPosition;
    
    AVFormatContext *avFormatContext;
    AVCodecContext *avCodecContext;
    
    int stream_index;
    float timeBase;
    AVFrame *pAudioFrame;
    AVPacket packet;
    
    char *accompanyFilePath;
    
    bool seek_success_read_frame_success;
    int packetBufferSize;
    
    short *audioBuffer;
    float position;
    int audioBufferCursor;
    int audioBufferSize;
    float duration;
    bool isNeedFirstFrameCorrectFlag;
    float firstFrameCorrectionInSecs;
    
    SwrContext *swrContext;
    void *swrBuffer;
    int swrBufferSize;
    
    int init(const char *fileString);
    int readSamples(short *samples, int size);
    int readFrame();
    bool audioCodecIsSupported();
    
public:
    AccompanyDecoder();
    virtual ~AccompanyDecoder();
    virtual int getMusicMeta(const char *fileString, int *metaData);
    virtual void init(const char *fileString, int packetBufferSizeParam);
    virtual AudioPacket* decodePacket();
    
    virtual void destroy();
    
    void setSeekReq(bool seekReqParam) {
        seek_req = seekReqParam;
        if (seek_req) {
            seek_req = false;
        }
    };
    
    bool hasSeekReq(){
        return seek_req;
    };
    
    bool hasSeekResp(){
        return seek_resp;
    };
    
    void setPosition(float seconds) {
        actualSeekPosition = -1;
        this->seek_seconds = seconds;
        this->seek_req = true;
        this->seek_resp = false;
    };
    
    float getActualSeekPosition(){
        float ret = actualSeekPosition;
        if (ret != 1) {
            actualSeekPosition = -1;
        }
        return ret;
    };
    
    virtual void seek_frame();
};

#endif /* accompany_decoder_hpp */

/** 术语
 * 容器/文件 Container/File  即特定格式的多媒体文件，比如MP4,flv,mov...
 *
 * 媒体流 (stream)  表示时间轴上的一段连续数据，如一段声音数据、一段视频数据或一段字幕数据
 *
 * 数据帧、数据包 (Frame/Packet) 一个媒体流是由大量的数据帧组成。对于压缩数据，帧对应着编解码器的最小处理单元
 *
 * 编解码器   是以帧为单位实现压缩数据和原始数据之间的相互转换的
 */

/** FFmpeg
 * AVFormatContext 就是对容器或者说媒体文件层次的一个抽象，包含了多路流(音频流、视频流、字幕流)
 *
 * AVStream 流的抽象，在每一路流中都会描述这路流的编码格式
 *
 * AVCodecContext AVCodec 对编解码格式以及编解码器的抽象
 *
 * AVPacket AVFrame 对于编解码器或者解码器的输入输出部分，也就是压缩数据以及原始数据的抽象
 *
 * 上面是FFmpeg的层次， 除了编解码外，对于音视频的处理肯定是针对于原始数据的处理，也就是AVFrame的处理
 *
 */
