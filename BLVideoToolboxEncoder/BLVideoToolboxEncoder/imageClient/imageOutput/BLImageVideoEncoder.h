//
//  BLImageVideoEncoder.h
//  BLVideoToolboxEncoder
//
//  Created by luowailin on 2019/10/30.
//  Copyright © 2019 luowailin. All rights reserved.
//

#import <Foundation/Foundation.h>
#import "BLImageContext.h"
#import "BLImageEncoderRender.h"

NS_ASSUME_NONNULL_BEGIN

@interface BLImageVideoEncoder : NSObject<BLImageInput>

- (instancetype)initWithFPS:(float)fps
                 maxBitRate:(int)maxBitRate
                 avgBitRate:(int)avgBitRate
               encoderWidth:(int)encoderWidth
              encoderHeight:(int)encoderHeight
      encoderStatusDelegate:(id<BLVideoEncoderStatusDelegate>)encoderStatusDelegate;

- (void)settingMaxBitRate:(int)maxBitRate
               avgBitRate:(int)avgBitRate
                      fps:(int)fps;

- (void)stopEncode;

@end

NS_ASSUME_NONNULL_END
