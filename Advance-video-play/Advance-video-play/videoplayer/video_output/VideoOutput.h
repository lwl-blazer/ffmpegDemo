//
//  VideoOutput.h
//  Advance-video-play
//
//  Created by luowailin on 2019/9/11.
//  Copyright © 2019 luowailin. All rights reserved.
//

#import <UIKit/UIKit.h>

#import "videoDecoder.h"
#import "BaseEffectFilter.h"

NS_ASSUME_NONNULL_BEGIN

@interface VideoOutput : UIView

- (instancetype)initWithFrame:(CGRect)frame textureWidth:(NSInteger)textureWidth
                textureHeight:(NSInteger)textureHeight
                 usingHWCodec:(BOOL)usingHWCodec;

- (instancetype)initWithFrame:(CGRect)frame textureWidth:(NSInteger)textureWidth
                textureHeight:(NSInteger)textureHeight
                 usingHWCodec:(BOOL)usingHWCodec
                   shareGroup:(EAGLSharegroup *)shareGroup;

- (void)presentVideoFrame:(VideoFrame *)frame;

- (BaseEffectFilter *)createImageProcessFilterInstance;
- (BaseEffectFilter *)getImageProcessFilterInstance;

- (void)destroy;

@end

NS_ASSUME_NONNULL_END
