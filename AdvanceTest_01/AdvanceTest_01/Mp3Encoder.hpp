//
//  Mp3Encoder.hpp
//  AdvanceTest_01
//
//  Created by luowailin on 2019/7/29.
//  Copyright © 2019 luowailin. All rights reserved.
//

#ifndef Mp3Encoder_hpp
#define Mp3Encoder_hpp

#include <stdio.h>
#include "lame.h"


/**
 * LAME库
 *  目前非常优秀的一种MP3编码引擎，在业界，转码成MP3格式的音频文件时，最常用的编码器就是LAME库。当达到320Kbit/s以上时，LAME编码出来的音频质量几乎可以和CD的音质相媲美，并且还能保证整个音频文件的体积非常小，因此若要在移动端平台上编码MP3文件，使用LAME便成为唯一的选择
 *
 * FDK_AAC库
 *  是用来编码和解码AAC格式音频文件的开源库，Android系统编码和解码AAC所用的就是这个库。
 *
 * X264
 *  是一个开源的H.264/MPEG-4 AVC视频编码函数库，是最好的有损视频编码器之一。一般的输入是视频帧的YUV表示。输出是编码之后的H264的数据包，并且支持CBR,VBR模式。可以在编码的过程中直接改变码率的设置，这在直播的场景中是非常实用的(直播场景下利用该特点可以做码率自适应)
 */
class Mp3Encoder {
private:
    FILE *pcmFile;
    FILE *mp3File;
    lame_t lameClient;
    
public:
    Mp3Encoder();
    ~Mp3Encoder();
    
    int Init(const char *pcmFilePath, const char *mp3FilePath, int sampleRate, int channels, int bitRate);
    void Encode();
    void Destory();
};


#endif /* Mp3Encoder_hpp */
