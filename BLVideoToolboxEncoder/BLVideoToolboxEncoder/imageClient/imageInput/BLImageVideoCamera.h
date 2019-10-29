//
//  BLImageVideoCamera.h
//  BLVideoToolboxEncoder
//
//  Created by luowailin on 2019/10/29.
//  Copyright © 2019 luowailin. All rights reserved.
//

#import "BLImageOutput.h"
#import <AVFoundation/AVFoundation.h>

NS_ASSUME_NONNULL_BEGIN

@interface BLImageVideoCamera : BLImageOutput<AVCaptureVideoDataOutputSampleBufferDelegate>

- (instancetype)initWithFPS:(int)fps;

- (void)startCapture;

- (void)stopCapture;

- (void)setFrameRate:(int)frameRate;

- (void)setFrameRate;

/**
 * 切换摄像头
 * @return 0:切到前置 1:切到后置 -1:失败
 * */
- (int)switchFrontBackCamera;

- (void)switchResolution;

@end

NS_ASSUME_NONNULL_END
