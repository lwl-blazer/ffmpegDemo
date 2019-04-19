//
//  main.cpp
//  ImageConvertProject
//
//  Created by luowailin on 2019/4/17.
//  Copyright © 2019 luowailin. All rights reserved.
//

#include <iostream>
#include "ImageConvertObject.hpp"

int main(int argc, const char * argv[]) {
    // insert code here...
    std::cout << "Hello, World!\n";
    
    ImageConvertObject object;
    object.simplest_yuv420_gray("/Users/luowailin/Documents/Code/ffmpegDemo/ImageConvertProject/ImageConvertProject/lena_256x256_yuv420p.yuv", 256, 256, 1);
   
    object.simplest_aac_parser("/Users/luowailin/Downloads/simplest_mediadata_test-master/simplest_mediadata_test/nocturne.aac");
    return 0;
}
