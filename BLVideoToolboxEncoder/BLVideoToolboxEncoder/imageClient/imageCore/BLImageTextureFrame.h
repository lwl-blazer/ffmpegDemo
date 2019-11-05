//
//  BLImageTextureFrame.h
//  BLVideoToolboxEncoder
//
//  Created by luowailin on 2019/10/28.
//  Copyright © 2019 luowailin. All rights reserved.
//

#import <Foundation/Foundation.h>
#import <CoreGraphics/CoreGraphics.h>
#import <OpenGLES/ES2/gl.h>
#import <OpenGLES/ES2/glext.h>
#import <CoreGraphics/CGGeometry.h>

NS_ASSUME_NONNULL_BEGIN

typedef struct GPUTextureFrameOptions {
    GLenum minFilter;
    GLenum magFilter;
    GLenum wrapS;
    GLenum wrapT;
    GLenum internalFormat;
    GLenum format;
    GLenum type;
} GPUTextureFrameOptions;
/**
 * BLImageTextureFrame
 * 在架构图中每个节点的输入，会发现它们都是一个纹理对象(实际上是一个纹理ID),实际渲染到一个目标纹理对象的时候，还需要建立一个帧缓存对象，并且还要将该目标纹理对象Attach到这个帧缓存对象上，此类用于将纹理对象和帧缓存对象的创建、绑定、销毁等操作，使得每个节点的使用都更加方便
 * 
 */
@interface BLImageTextureFrame : NSObject

- (instancetype)initWithSize:(CGSize)framebufferSize;
- (instancetype)initWithSize:(CGSize)framebufferSize
              textureOptions:(GPUTextureFrameOptions)fboTextureOptions;

- (void)activateFramebuffer;

- (GLuint)texture;
- (GLubyte *)byteBuffer;
- (int)width;
- (int)height;

@end

NS_ASSUME_NONNULL_END
