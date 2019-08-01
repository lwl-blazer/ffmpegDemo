//
//  Mp3Encoder.cpp
//  AdvanceTest_01
//
//  Created by luowailin on 2019/7/29.
//  Copyright © 2019 luowailin. All rights reserved.
//

#include "Mp3Encoder.hpp"

Mp3Encoder::Mp3Encoder(){
    
}

Mp3Encoder::~Mp3Encoder(){
    
}

int Mp3Encoder::Init(const char *pcmFilePath, const char *mp3FilePath, int sampleRate, int channels, int bitRate){
    
    int ret = -1;
    pcmFile = fopen(pcmFilePath, "rb");
    if (pcmFile) {
        mp3File = fopen(mp3FilePath, "wb");
        if (mp3File) {
            //设置参数
            lameClient = lame_init();
            lame_set_in_samplerate(lameClient, sampleRate);
            lame_set_out_samplerate(lameClient, sampleRate);
            
            lame_set_num_channels(lameClient, channels);
            //bitRate-比特率 单位是bps 声音中的比特率是指将模拟声音信号转换成数字声音信号后，单位时间内的二进制数据量是间接衡量音频质量的一个指标。
            lame_set_brate(lameClient, bitRate/1000);
            
            lame_init_params(lameClient);
            
            ret = 0;
        }
    }
    return ret;
}

void Mp3Encoder::Encode(){
    //每次读取bufferSize大小
    int bufferSize = 1024 * 256;
    short *buffer = new short[bufferSize/2];
    short *leftBuffer  = new short[bufferSize/4];
    short *rightBuffer = new short[bufferSize/4];
    
    unsigned char *mp3_buffer = new unsigned char[bufferSize];
    size_t readBufferSize = 0;
    
    while ((readBufferSize = fread(buffer, 2, bufferSize/2, pcmFile)) > 0) {
        
        //把左右声道分开
        for (int i = 0; i < readBufferSize; i++) {
            if (i % 2 == 0) {
                leftBuffer[i / 2] = buffer[i];
            } else {
                rightBuffer[i/2] = buffer[i];
            }
        }
        
        //送入编码器进行编码
        size_t wroteSize = lame_encode_buffer(lameClient,
                                              (short int *)leftBuffer,
                                              (short int *)rightBuffer,
                                              (int)(readBufferSize/2),
                                              mp3_buffer,
                                              bufferSize);
        //写入MP3文件中
        fwrite(mp3_buffer, 1, wroteSize, mp3File);
    }
    
    delete[] buffer;
    delete[] leftBuffer;
    delete[] rightBuffer;
    delete[] mp3_buffer;
}

void Mp3Encoder::Destory(){
    if (pcmFile) {
        fclose(pcmFile);
    }
    if (mp3File) {
        fclose(mp3File);
        lame_close(lameClient);
    }
}
