//
//  ELImageContext.h
//  BLVideoToolboxEncoder
//
//  Created by luowailin on 2019/10/28.
//  Copyright © 2019 luowailin. All rights reserved.
//

#import <Foundation/Foundation.h>
#import <OpenGLES/EAGL.h>
#import <CoreMedia/CoreMedia.h>
#import <OpenGLES/EAGL.h>
#import <OpenGLES/ES2/gl.h>
#import <OpenGLES/ES2/glext.h>
#import "BLImageTextureFrame.h"

NS_ASSUME_NONNULL_BEGIN

@interface BLImageContext : NSObject

@end

@protocol BLImageInput <NSObject>

- (void)newFrameReadyAtTime:(CMTime)frameTime timingInfo:(CMSampleTimingInfo)timingInfo;
- (void)setInputTexture:(BLImageTextureFrame *)textureFrame;

@end


NS_ASSUME_NONNULL_END
