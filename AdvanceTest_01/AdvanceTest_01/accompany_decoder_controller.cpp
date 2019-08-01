//
//  accompany_decoder_controller.cpp
//  AdvanceTest_01
//
//  Created by luowailin on 2019/8/1.
//  Copyright © 2019 luowailin. All rights reserved.
//

#include "accompany_decoder_controller.hpp"

#define LOG_TAG "AccompanyDecoderController"

AccompanyDecoderController::AccompanyDecoderController(){
    accompanyDecoder = nullptr;
    pcmFile = nullptr;
}

AccompanyDecoderController::~AccompanyDecoderController(){
    
}

void AccompanyDecoderController::Init(const char *accompanyPath, const char *pcmFilePath){
    AccompanyDecoder *tempDecoder = new AccompanyDecoder();
    int accompanyMetaData[2];
    tempDecoder->getMusicMeta(accompanyPath, accompanyMetaData);
    delete tempDecoder;
    
    accompanySampleRate = accompanyMetaData[0];
    int accompanyByteCountPerSec = accompanySampleRate * CHANNEL_PER_FRAME * BITS_PER_CHANNEL / BITS_PER_BYTE;
    accompanyPacketBufferSize = (int)((accompanyByteCountPerSec / 2) * 0.2);
    accompanyDecoder = new AccompanyDecoder();
    accompanyDecoder->init(accompanyPath, accompanyPacketBufferSize);
    pcmFile = fopen(pcmFilePath, "wb+");
}

void AccompanyDecoderController::Decode(){
    while (true) {
        AudioPacket *accompanyPacket = accompanyDecoder->decodePacket();
        if (accompanyPacket->size == -1) {
            break;
        }
        
        fwrite(accompanyPacket->buffer,
               sizeof(short),
               accompanyPacket->size, pcmFile);
    }
}

void AccompanyDecoderController::Destroy(){
    if (accompanyDecoder != nullptr) {
        accompanyDecoder->destroy();
        delete accompanyDecoder;
        accompanyDecoder = nullptr;
    }
    
    if (pcmFile != nullptr) {
        fclose(pcmFile);
        pcmFile = nullptr;
    }
}
