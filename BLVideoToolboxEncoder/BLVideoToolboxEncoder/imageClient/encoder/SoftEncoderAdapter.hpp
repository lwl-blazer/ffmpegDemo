//
//  SoftEncoderAdapter.hpp
//  BLVideoToolboxEncoder
//
//  Created by luowailin on 2019/11/8.
//  Copyright © 2019 luowailin. All rights reserved.
//

#ifndef SoftEncoderAdapter_hpp
#define SoftEncoderAdapter_hpp

#include <stdio.h>

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

class SoftEncoderAdapter {
    
private:
    int width;
    int height;
    int videoBitRate;
    float frameRate;
    
    
public:
    //构造编码器实例
    void init(const char *h264Path, int width, int height, int videoBitRate, float frameRate);
    
    //初始化编码器
    virtual int createEncoder(int inputTexId);
    
    //每一帧者做编码操作
    virtual int encode();
    
    //停止编码
    virtual void destroyEncoder();
};


#endif /* SoftEncoderAdapter_hpp */
