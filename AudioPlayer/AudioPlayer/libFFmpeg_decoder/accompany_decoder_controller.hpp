//
//  accompany_decoder_controller.hpp
//  AdvanceTest_01
//
//  Created by luowailin on 2019/8/1.
//  Copyright © 2019 luowailin. All rights reserved.
//

#ifndef accompany_decoder_controller_hpp
#define accompany_decoder_controller_hpp

#include <stdio.h>
#include <unistd.h>
#include "accompany_decoder.hpp"

#define CHANNEL_PER_FRAME 2
#define BITS_PER_CHANNEL 16
#define BITS_PER_BYTE 8

#define QUEUE_SIZE_MAX_THRESHOLD 25
#define QUEUE_SIZE_MIN_THRESHOLD 20

class AccompanyDecoderController{
protected:
    FILE *pcmFile;
    
    AccompanyDecoder *accompanyDecoder;
    
    int accompanySampleRate;
    int accompanyPacketBufferSize;
    
public:
    AccompanyDecoderController();
    ~AccompanyDecoderController();
    
    void Init(const char *accompanyPath, const char *pcmFilePath);
    void Decode();
    void Destroy();
};

#endif /* accompany_decoder_controller_hpp */
