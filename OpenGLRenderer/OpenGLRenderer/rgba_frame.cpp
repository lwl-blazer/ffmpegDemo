//
//  rgba_frame.cpp
//  OpenGLRenderer
//
//  Created by luowailin on 2019/9/3.
//  Copyright © 2019 luowailin. All rights reserved.
//

#include "rgba_frame.hpp"

#define LOG_TAG "RGBAFrame"

RGBAFrame::RGBAFrame(){
    position = 0.0f;
    duration = 0.0f;
    pixels = NULL;
    width = 0;
    height = 0;
}

RGBAFrame::~RGBAFrame(){
    if (pixels != nullptr) {
        delete[] pixels;
        pixels = nullptr;
    }
}

RGBAFrame *RGBAFrame::clone(){
    RGBAFrame *ret = new RGBAFrame();
    ret->duration = this->duration;
    ret->width = this->width;
    ret->height = this->height;
    ret->position = this->position;
    
    int pixelsLength = this->width * this->height * 4;
    ret->pixels = new uint8_t[pixelsLength];
    memcpy(ret->pixels, this->pixels, pixelsLength);
    return ret;
}
