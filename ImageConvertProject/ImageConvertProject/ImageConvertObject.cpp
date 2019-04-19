//
//  ImageConvertObject.cpp
//  ImageConvertProject
//
//  Created by luowailin on 2019/4/17.
//  Copyright © 2019 luowailin. All rights reserved.
//

#include "ImageConvertObject.hpp"
#include <stdlib.h>
#include <math.h>
#include <string.h>
#include <iostream>

using namespace std;

ImageConvertObject::ImageConvertObject(){
    
}

ImageConvertObject::~ImageConvertObject(){
    
}

//分离YUV420P像素数据中的Y,U,V分量
int ImageConvertObject::simplest_yuv420_split(const char *url, int w, int h, int num) {
    
    FILE *fp = fopen(url, "rb+");
    FILE *fp1 = fopen("/Users/luowailin/Documents/Code/ffmpegDemo/output_420_y.y", "wb+");
    FILE *fp2 = fopen("/Users/luowailin/Documents/Code/ffmpegDemo/output_420_u.y", "wb+");
    FILE *fp3 = fopen("/Users/luowailin/Documents/Code/ffmpegDemo/output_420_v.y", "wb+");
    
    unsigned char *pic = (unsigned char *)malloc(w * h * 3 / 2);
    for (int i = 0; i < num; i ++) {
        
        /**
         * size_t fread(void *buffer, size_t size, size_t count, FILE * stream)
         * buffer -- 接收数据的地址
         * size -- 一个单元的大小
         * count -- 单元个数
         * stream -- 文件流
         * fread函数每次从stream中最多读取count个单元，每个单元大小为size个字节，将读取的数据放到buffer; 文件流的位置指针后移size*count字节
         */
        fread(pic, 1, w * h * 3 / 2, fp);
        //Y
        fwrite(pic, 1, w * h, fp1);
        //U
        fwrite(pic + w * h, 1, w * h / 4, fp2);
        //V
        fwrite(pic + w * h * 5 / 4, 1, w * h / 4, fp3);
    }
    
    free(pic);
    fclose(fp);
    fclose(fp1);
    fclose(fp2);
    fclose(fp3);
    
    return 0;
}

//分离YUV444P像素数据中的Y,U,V分量
int ImageConvertObject::simplest_yuv444_split(const char *url, int w, int h, int num) {
    
    FILE *fp = fopen(url, "rb+");
    FILE *fp1 = fopen("/Users/luowailin/Documents/Code/ffmpegDemo/output_444_y.y", "wb+");
    FILE *fp2 = fopen("/Users/luowailin/Documents/Code/ffmpegDemo/output_444_u.y", "wb+");
    FILE *fp3 = fopen("/Users/luowailin/Documents/Code/ffmpegDemo/output_444_v.y", "wb+");
    
    unsigned char *pic = (unsigned char *)malloc(w * h * 3);
    for (int i = 0; i < num; i ++) {
        fread(pic, 1, w * h * 3, fp);
        //Y
        fwrite(pic, 1, w * h, fp1);
        //U
        fwrite(pic+ w * h, 1, w * h, fp2);
        //V
        fwrite(pic + w * h * 2, 1, w * h, fp3);
    }
    
    free(pic);
    fclose(fp);
    fclose(fp1);
    fclose(fp2);
    fclose(fp3);
    
    return 0;
}


//把YUV420P格式像素数据彩色去掉，变成纯粹的灰度图
int ImageConvertObject::simplest_yuv420_gray(const char *url, int w, int h, int num){
    FILE *fp = fopen(url, "rb+");
    FILE *fp1 = fopen("/Users/luowailin/Documents/Code/ffmpegDemo/output_gray.yuv", "wb+");
    
    unsigned char *pic = (unsigned char *)malloc(w * h * 3 / 2);
    
    for (int i = 0; i < num; i ++) {
        fread(pic, 1, w * h * 3 / 2 , fp);
        
        /**
         * memset(void *ptr, int value, size_t num) 函数用来指定内存的前n个字节设置为特定的值
         * ptr -- 要操作的内存的指针
         * value -- 要设置的值，你即可以向value传递int类型的值 也可以传递char类型的值
         * num -- 为ptr的前num个字节
         *
         * memset()会将ptr所指的内存区域的前num个字节的值都设置为value,然后返回指向ptr的指针
         */
        memset(pic + w * h, 128, w * h / 2);
        /**
         * 灰度图像为什么要把U,V值设置128:
           因为U,V是图像中的经过偏置处理的色度分量，色度分量在偏置处理前的取值范围是-128至127，这时候的无色对应的是0值，经过偏置后色度分量取值变成了0至255，因而此时的无色对应的就是128了
         */
        
        fwrite(pic, 1, w * h * 3 / 2, fp1);
    }
    
    free(pic);
    fclose(fp);
    fclose(fp1);
    return 0;
}


/**
 AAC原始码流(又称为‘裸流’)是由一个一个的ADTS frame组成的，
 其中每个ADTS frame之间通过syncword(同步字)进行分隔。 同步字为0xFFF
 *
 * AAC码流解析的步聚就是首先从码流中搜索0x0FFF,分离出ADTS frame,  然后再分析ADTS frame的首部各个字段
 *
 * 每个Frame由ADTS Header和AAC audio data组成
 * ADTS header的长度可能为7字节或9字节  protection_absent=0时  9字节   protection_absent=1 7字节
 */
int ImageConvertObject::simplest_aac_parser(const char *url) {
    
    int data_size = 0;
    int size = 0;
    int cnt = 0;
    int offset = 0;
    
    FILE *myout = stdout;
    
    unsigned char *aacFrame = (unsigned char *)malloc(1024 * 5);
    unsigned char *aacbuffer = (unsigned char *)malloc(1024 *1024);
    
    FILE *ifile = fopen(url, "rb");
    if (!ifile) {
        printf("Open file error");
        return -1;
    }
    
    cout << "-----+- ADTS Frame Table -+------+" << endl;
    cout << " NUM | Profile | Frequency| Size |" << endl;
    cout << "-----+---------+----------+------+" << endl;
    
    while (!feof(ifile)) {
        data_size = fread(aacbuffer + offset, 1, 1024 * 1024 - offset, ifile);
        
        unsigned char * input_data = aacbuffer;
        
        while (1) {
            int ret = getADTSframe(input_data, data_size, aacFrame, &size);
            
            if (ret == -1) {
                break;
            } else if (ret == 1) {
                memcpy(aacbuffer, input_data, data_size);
                offset = data_size;
                break;
            }
            
            char profile_str[10] = {0};
            char frequence_str[10] = {0};
            
            unsigned char profile = aacFrame[2] & 0xC0;
            
            profile = profile >> 6;
            //表示使用了哪个级别的AAC
            switch (profile) {
                case 0:
                    sprintf(profile_str, "Main");
                    break;
                case 1:
                    sprintf(profile_str, "LC");
                    break;
                case 2:
                    sprintf(profile_str, "SSR");
                    break;
                default:
                    sprintf(profile_str, "unknown");
                    break;
            }
            
            unsigned char sampling_frequency_index = aacFrame[2] & 0x3C;
            sampling_frequency_index = sampling_frequency_index >> 3;
            
            //采样率
            switch (sampling_frequency_index) {
                case 0:
                    sprintf(frequence_str, "96000Hz");
                    break;
                case 1:
                    sprintf(frequence_str, "88200Hz");
                    break;
                case 2:
                    sprintf(frequence_str, "64000Hz");
                    break;
                case 3:
                    sprintf(frequence_str, "48000Hz");
                    break;
                case 4:
                    sprintf(frequence_str, "44100Hz");
                    break;
                case 5:
                    sprintf(frequence_str, "32000Hz");
                    break;
                case 6:
                    sprintf(frequence_str, "24000Hz");
                    break;
                case 7:
                    sprintf(frequence_str, "22050Hz");
                    break;
                case 8:
                    sprintf(frequence_str, "16000Hz");
                    break;
                case 9:
                    sprintf(frequence_str, "12000Hz");
                    break;
                case 10:
                    sprintf(frequence_str, "11025Hz");
                    break;
                case 11:
                    sprintf(frequence_str, "8000Hz");
                    break;
                    
                default:
                    sprintf(frequence_str, "unknown");
                    break;
            }
            
            fprintf(myout, "%5d| %8s|  %8s| %5d|\n",cnt,profile_str ,frequence_str,size);
            
            data_size -= size;
            input_data += size;
            cnt++;
        }
        
    }
    
    
    fclose(ifile);
    free(aacbuffer);
    free(aacFrame);
    return 0;
}

int ImageConvertObject::getADTSframe(unsigned char *buffer, int buf_size, unsigned char *data, int *data_size){
    
    int size = 0;
    
    if (!buffer || !data || !data_size) {
        return -1;
    }
    
    while (1) {
        if (buf_size < 7) {
            return -1;
        }
        
        //Sync words
        if ((buffer[0] == 0xff) && ((buffer[1] & 0xf0) == 0xf0)) {
            size |= ((buffer[3] & 0x03) << 11);  //high 2 bit
            size |= buffer[4] << 3;  //middle 8 bit
            size |= ((buffer[5] & 0xe0) >> 5);  //low 3 bit
            break;
        }
        
        --buf_size;
        ++buffer;
    }
    
    if (buf_size < size) {
        return 1;
    }
    
    memcpy(data, buffer, size);
    *data_size = size;
    return 0;
}
