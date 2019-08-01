//
//  testDecoder.hpp
//  AdvanceTest_01
//
//  Created by luowailin on 2019/8/1.
//  Copyright © 2019 luowailin. All rights reserved.
//

#ifndef testDecoder_hpp
#define testDecoder_hpp

#include <stdio.h>

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

#define MIN(a, b)  (((a) < (b)) ? (a) : (b))

class DecoderAction {
private:
    FILE *pcmFile;
    
    AVFormatContext *avFormatContext;
    AVCodecContext *avCodecContext;
    AVFrame *pAudioFrame;
    
    AVPacket packet;
    
    SwrContext *swrContext;
    short *audioBuffer;
    void *swrBuffer;
    int swrBufferSize;
    
    int stream_index;
    float timeBase;
    
    int audioBufferCursor;
    int audioBufferSize;
    
    bool audioCodecIsSupported();
    int readSamples(short *samples, int size);
    int readFrame();
    
public:
    DecoderAction();
    ~DecoderAction();
    
    int Init(const char *filePath, const char *pcmFilePath);
    virtual void decodePacket();
    virtual void destroy();
};

#endif /* testDecoder_hpp */
