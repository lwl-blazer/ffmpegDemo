//
//  XDemux.h
//  BLPlayerItem
//
//  Created by luowailin on 2019/4/19.
//  Copyright © 2019 luowailin. All rights reserved.
// 解封装

#import <Foundation/Foundation.h>

#import <libavformat/avformat.h>

NS_ASSUME_NONNULL_BEGIN

@interface XDemux : NSObject{
    AVFormatContext *ic;  //AVFormatContext是一个句柄 也是一个主线
}

@property(nonatomic, assign) int totalMs;
@property(nonatomic, assign) int width;
@property(nonatomic, assign) int height;

@property(nonatomic, assign) int videoStream;
@property(nonatomic, assign) int audioStream;

//打开媒体文件或RTMP\HTTP\RTSP流
- (BOOL)open:(NSString *)url;

//seek pos的范围是0~1.0
- (BOOL)seek:(double)pos;

//判断
- (BOOL)isAudio:(AVPacket *)pkt;

//清除缓存
- (void)clear;
//关闭
- (void)close;

//空间需要调用者释放， 释放AVPacket对象空间和数据空间 av_packet_free
- (AVPacket *)read;

//copy视频参数，调用者释放 avcodec_parameters_free()
- (AVCodecParameters *)copyVideoParameters;

//copy音频参数，调用者释放 avcodec_parameters_free()
- (AVCodecParameters *)copyAudioParameters;

@end

NS_ASSUME_NONNULL_END
