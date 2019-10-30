//
//  BLImageEncoderRender.h
//  BLVideoToolboxEncoder
//
//  Created by luowailin on 2019/10/30.
//  Copyright © 2019 luowailin. All rights reserved.
//

#import <Foundation/Foundation.h>
#import "H264HwEncoderImpl.h"

NS_ASSUME_NONNULL_BEGIN

@interface BLImageEncoderRender : NSObject
{
    CVPixelBufferRef renderTarget;
    CVOpenGLESTextureRef renderTexture;
}

- (instancetype)initWithWidth:(int)width
                       height:(int)height
                          fps:(float)fps
                   maxBitRate:(int)maxBitRate
                   avgBitRate:(int)avgBitRate
        encoderStatusDelegate:(id<BLVideoEncoderStatusDelegate>)encoderStatusDelegate;

- (void)settingMaxBitRate:(int)maxBitRate
               avgBitRate:(int)avgBitRate
                      fps:(int)fps;

- (BOOL)prepareRender;

- (void)renderWithTextureId:(int)inputTex
                 timingInfo:(CMSampleTimingInfo)timingInfo;

- (void)stopEncode;

@end

NS_ASSUME_NONNULL_END
