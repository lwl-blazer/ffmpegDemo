//
//  BLImageVideoScheduler.m
//  BLVideoToolboxEncoder
//
//  Created by luowailin on 2019/10/28.
//  Copyright © 2019 luowailin. All rights reserved.
//

#import "BLImageVideoScheduler.h"
#import "BLImageVideoCamera.h"
#import "BLImageView.h"

#define ASYNC_CONTRAST_ENHANCE 1


@implementation BLImageVideoScheduler
{
    BLImageVideoCamera *_videoCamera;
    BLImageVideoEncoder *_videoEncoder;
    BLImageView *_previewView;
}

- (instancetype)initWithFrame:(CGRect)bounds videoFrameRate:(int)frameRate{
    self = [self initWithFrame:bounds
                videoFrameRate:frameRate
           disableAutoContrast:NO];
    return self;
}

- (instancetype)initWithFrame:(CGRect)bounds videoFrameRate:(int)frameRate disableAutoContrast:(BOOL)disableAutoContrast{
    self = [super init];
    if (self) {
        _videoCamera = [[BLImageVideoCamera alloc] initWithFPS:frameRate];
        _previewView = [[BLImageView alloc] initWithFrame:bounds];
        [_videoCamera startCapture];
    }
    return self;
}



- (void)startEncodeWithFPS:(float)fps
                maxBitRate:(int)maxBitRate
                avgBitRate:(int)avgBitRate
              encoderWidth:(int)encoderWidth
             encoderHeight:(int)encoderHeight
     encoderStatusDelegate:(id<BLVideoEncoderStatusDelegate>)encoderStatusDelegate{
    _videoEncoder = [[BLImageVideoEncoder alloc] initWithFPS:fps
                                                  maxBitRate:maxBitRate
                                                  avgBitRate:avgBitRate
                                                encoderWidth:encoderWidth
                                               encoderHeight:encoderHeight
                                       encoderStatusDelegate:encoderStatusDelegate];
    [_videoCamera addTarget:_videoEncoder];
}


- (void)stopEncode{
    if (_videoEncoder) {
        [_videoCamera removeTarget:_videoEncoder];
        [_videoEncoder stopEncode];
        _videoEncoder = nil;
    }
}

- (UIView *)previewView{
    return _previewView;
}

- (void)startPreview{
    [_videoCamera addTarget:_previewView];
}


- (void)stopPreview{
    [_videoCamera removeTarget:_previewView];
}


- (int)switchFrontBackCamera{
    return [_videoCamera switchFrontBackCamera];
}



@end
