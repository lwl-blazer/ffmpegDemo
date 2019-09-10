//
//  rgba_frame.hpp
//  OpenGLRenderer
//
//  Created by luowailin on 2019/9/3.
//  Copyright © 2019 luowailin. All rights reserved.
//

#ifndef rgba_frame_hpp
#define rgba_frame_hpp

#include <string>

class RGBAFrame {
public:
    float position;
    float duration;
    
    uint8_t *pixels;
    int width;
    int height;
    
    RGBAFrame();
    ~RGBAFrame();
    RGBAFrame *clone();
};



#endif /* rgba_frame_hpp */
