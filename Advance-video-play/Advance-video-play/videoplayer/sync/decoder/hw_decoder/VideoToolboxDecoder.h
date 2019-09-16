//
//  VideoToolboxDecoder.h
//  Advance-video-play
//
//  Created by luowailin on 2019/9/11.
//  Copyright © 2019 luowailin. All rights reserved.
//

#import <Foundation/Foundation.h>
#import <VideoToolbox/VideoToolbox.h>
#import "VideoDecoder.h"

NS_ASSUME_NONNULL_BEGIN
@protocol H264DecoderDelegate <NSObject>
@optional

- (void)getDecodeImageData:(CVImageBufferRef)imageBuffer;
@end

@interface VideoToolboxDecoder : VideoDecoder

@property(nonatomic, weak) id<H264DecoderDelegate>delegate;

@property(nonatomic, assign) CMVideoFormatDescriptionRef formatDesc;
@property(nonatomic, assign) VTDecompressionSessionRef decompressionSession;

@end

NS_ASSUME_NONNULL_END
