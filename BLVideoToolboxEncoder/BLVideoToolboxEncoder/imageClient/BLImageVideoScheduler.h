//
//  BLImageVideoScheduler.h
//  BLVideoToolboxEncoder
//
//  Created by luowailin on 2019/10/28.
//  Copyright © 2019 luowailin. All rights reserved.
//

#import <UIKit/UIKit.h>
#import "BLImageVideoEncoder.h"

NS_ASSUME_NONNULL_BEGIN

@interface BLImageVideoScheduler : NSObject

/**默认开启自动对比度*/
- (instancetype)initWithFrame:(CGRect)bounds
               videoFrameRate:(int)frameRate;

- (instancetype)initWithFrame:(CGRect)bounds
               videoFrameRate:(int)frameRate
          disableAutoContrast:(BOOL)disableAutoContrast;


- (UIView *)previewView;

- (void)startPreview;

- (void)stopPreview;

- (int)switchFrontBackCamera;

- (void)startEncodeWithFPS:(float)fps
                maxBitRate:(int)maxBitRate
                avgBitRate:(int)avgBitRate
              encoderWidth:(int)encoderWidth
             encoderHeight:(int)encoderHeight
     encoderStatusDelegate:(id<BLVideoEncoderStatusDelegate>)encoderStatusDelegate;

- (void)stopEncode;

@end

NS_ASSUME_NONNULL_END
