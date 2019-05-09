//
//  XDecode.h
//  BLPlayerItem
//
//  Created by luowailin on 2019/4/19.
//  Copyright © 2019 luowailin. All rights reserved.
//

#import <Foundation/Foundation.h>
#import <libavformat/avformat.h>
#import <libavcodec/avcodec.h>

NS_ASSUME_NONNULL_BEGIN

@interface XDecode : NSObject{
    AVCodecContext *codec; //视频解码的上下文 包含解码器
}

@property(nonatomic, assign) BOOL isAudio;

//函数内部负责释放AVCodecParameters
- (BOOL)open:(AVCodecParameters *)para;

- (BOOL)send:(AVPacket *)pkt;
- (AVFrame *)recv;

- (void)close;
- (void)clear;

@end

NS_ASSUME_NONNULL_END
