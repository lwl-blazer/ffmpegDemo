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
