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

#define TEXTURE_FRAME_ASPECT_RATIO  16.0/9.0f
typedef enum {
    kBLImageNoRotation,
    kBLImageFlipHorizontal
} BLImageRotationMode;


@interface BLImageContext : NSObject

@property(readonly, nonatomic) dispatch_queue_t contextQueue;
@property(readonly, strong, nonatomic) EAGLContext *context;
@property(readonly, nonatomic) CVOpenGLESTextureCacheRef coreVideoTextureCache;

+ (void *)contextKey;

+ (BLImageContext *)shareImageProcessingContext;

+ (BOOL)supportFastTextureUpload;

+ (dispatch_queue_t)shareContextQueue;

+ (void)useImageProcessingContext;

- (CVOpenGLESTextureCacheRef)coreVideoTextureCache;

- (void)useSharegroup:(EAGLSharegroup *)sharegroup;

- (void)useAsCurrentContext;

@end

@protocol BLImageInput <NSObject>

- (void)newFrameReadyAtTime:(CMTime)frameTime timingInfo:(CMSampleTimingInfo)timingInfo;
- (void)setInputTexture:(BLImageTextureFrame *)textureFrame;

@end


NS_ASSUME_NONNULL_END
