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

/**
 * 要想使用OpenGL ES，必须要有上下文以及关联的线程，iOS平台为OpenGL ES提供了EAGL作为OpenGL ES的上下文。在整个架构中的所有组件中，要针对编码器组件单独开辟一个线程，因为我们不希望它阻塞预览线程，从而影响预览的流畅效果，所以它也需要一个单独的OpenGL上下文，并且需要和渲染线程共享OpenGL上下文(两个OpenGLES线程共享上下文或者共享一个组，则代表可以互相使用对方的纹理对象以及帧缓存对象)，只有这样，在编码线程中才可以正确访问到预览线程中的纹理对象、帧缓存对象
 */
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


/**凡是需要输入纹理对象的节点都是Input类型
 * 在架构图的节点中Filter,BLImageView以及VideoEncoder都属于BLImageInput的类型，
 */
@protocol BLImageInput <NSObject>
//执行渲染操作
- (void)newFrameReadyAtTime:(CMTime)frameTime timingInfo:(CMSampleTimingInfo)timingInfo;
//设置输入纹理对象
- (void)setInputTexture:(BLImageTextureFrame *)textureFrame;

@end


NS_ASSUME_NONNULL_END
