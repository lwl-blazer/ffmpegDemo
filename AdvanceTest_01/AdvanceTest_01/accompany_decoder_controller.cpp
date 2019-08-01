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
    int accompanyMetaData[2];
    //用一个临时的获取meta data
    AccompanyDecoder *tempDecoder = new AccompanyDecoder();
    tempDecoder->getMusicMeta(accompanyPath, accompanyMetaData);
    delete tempDecoder;
    
    
    accompanySampleRate = accompanyMetaData[0]; //采样率
    int accompanyByteCountPerSec = accompanySampleRate * CHANNEL_PER_FRAME * BITS_PER_CHANNEL / BITS_PER_BYTE;
    accompanyPacketBufferSize = (int)((accompanyByteCountPerSec / 2) * 0.2); //每次写入文件的大小 也是packet的size
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
        
        fwrite(accompanyPacket->buffer, //要被写入的指针
               sizeof(short),  //每次写的字节大小
               accompanyPacket->size, //总共写多少字节大小
               pcmFile); //写入的地方--输出流
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
