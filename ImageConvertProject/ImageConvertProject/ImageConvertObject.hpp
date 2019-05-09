//
//  ImageConvertObject.hpp
//  ImageConvertProject
//
//  Created by luowailin on 2019/4/17.
//  Copyright © 2019 luowailin. All rights reserved.
//

#ifndef ImageConvertObject_hpp
#define ImageConvertObject_hpp

#include <stdio.h>

class ImageConvertObject {
    
public:
    ImageConvertObject();
    ~ImageConvertObject();
    int simplest_yuv420_split(const char *url, int w, int h, int num);
    int simplest_yuv444_split(const char *url, int w, int h, int num);
    int simplest_yuv420_gray(const char *url, int w, int h, int num);
    
    
    //PCM16LE 双声道音频采样数据的左声道和右声道
    int simplest_pcm16le_split(const char *url);
    
    //AAC
    int simplest_aac_parser(const char *url);
    
private:
    int getADTSframe(unsigned char *buffer, int buf_size, unsigned char *data, int *data_size);
};

#endif /* ImageConvertObject_hpp */
