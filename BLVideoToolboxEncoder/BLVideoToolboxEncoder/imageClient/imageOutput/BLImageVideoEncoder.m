//
//  BLImageVideoEncoder.m
//  BLVideoToolboxEncoder
//
//  Created by luowailin on 2019/10/30.
//  Copyright © 2019 luowailin. All rights reserved.
//

#import "BLImageVideoEncoder.h"

@implementation BLImageVideoEncoder{
    BLImageTextureFrame *_inputFrameTexture;
    BLImageEncoderRender *_encoderRenderer;
    float _fps;
    int _maxBitRate;
    int _avgBitRate;
    int _encoderWidth;
    int _encoderHeight;
    
    id<BLVideoEncoderStatusDelegate> _encoderStatusDelegate;
}

- (instancetype)initWithFPS:(float)fps
                 maxBitRate:(int)maxBitRate
                 avgBitRate:(int)avgBitRate
               encoderWidth:(int)encoderWidth
              encoderHeight:(int)encoderHeight
      encoderStatusDelegate:(id<BLVideoEncoderStatusDelegate>)encoderStatusDelegate{
    self = [super init];
    if (self) {
        _fps = fps;
        _maxBitRate = maxBitRate;
        _avgBitRate = avgBitRate;
        _encoderWidth = encoderWidth;
        _encoderHeight = encoderHeight;
        _encoderStatusDelegate = encoderStatusDelegate;
    }
    return self;
}

- (void)settingMaxBitRate:(int)maxBitRate avgBitRate:(int)avgBitRate fps:(int)fps{
    [[self encoderRenderer] settingMaxBitRate:maxBitRate
                                   avgBitRate:avgBitRate
                                          fps:fps];
}

- (void)stopEncode{
    if (_encoderRenderer) {
        [_encoderRenderer stopEncode];
        _encoderRenderer = nil;
    }
}

- (void)newFrameReadyAtTime:(CMTime)frameTime timingInfo:(CMSampleTimingInfo)timingInfo{
    [[self encoderRenderer] renderWithTextureId:[_inputFrameTexture texture]
                                     timingInfo:timingInfo];
}


- (void)setInputTexture:(BLImageTextureFrame *)textureFrame{
    _inputFrameTexture = textureFrame;
}

- (BLImageEncoderRender *)encoderRenderer{
    if (_encoderRenderer == nil) {
        _encoderRenderer = [[BLImageEncoderRender alloc] initWithWidth:_encoderWidth
                                                                height:_encoderHeight
                                                                   fps:_fps
                                                            maxBitRate:_maxBitRate
                                                            avgBitRate:_avgBitRate
                                                 encoderStatusDelegate:_encoderStatusDelegate];
        
        if (![_encoderRenderer prepareRender]) {
            NSLog(@"VideoEncoderRenderer prepareRender failed...");
        }
    }
    return _encoderRenderer;
}

@end
