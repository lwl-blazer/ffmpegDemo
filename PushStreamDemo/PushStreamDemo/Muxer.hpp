//
//  Muxer.hpp
//  PushStreamDemo
//
//  Created by luowailin on 2019/4/15.
//  Copyright © 2019 luowailin. All rights reserved.
//

#ifndef Muxer_hpp
#define Muxer_hpp

#include <stdio.h>

struct AVFormatContext;
struct AVOutputFormat;

class Muxer{
public:
    void openUrl(char *url);
    
protected:
    AVOutputFormat *fmt;
    AVFormatContext *oc;
};

#endif /* Muxer_hpp */
