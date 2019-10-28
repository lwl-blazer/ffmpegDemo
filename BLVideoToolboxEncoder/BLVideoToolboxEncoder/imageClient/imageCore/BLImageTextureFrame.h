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
