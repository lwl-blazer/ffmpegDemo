//
//  BLImageTextureFrame.m
//  BLVideoToolboxEncoder
//
//  Created by luowailin on 2019/10/28.
//  Copyright © 2019 luowailin. All rights reserved.
//

#import "BLImageTextureFrame.h"
#import "BLImageOutput.h"
#import "BLImageContext.h"

@implementation BLImageTextureFrame{
    GLuint _framebuffer;
    GLuint _texture;
    GPUTextureFrameOptions _textureOptions;
    CGSize _size;
    
#if TARGET_IPHONE_SIMULATOR || TARGET_OS_IPHONE
    CVPixelBufferRef renderTarget;
    CVOpenGLESTextureRef renderTexture;
    NSUInteger readLockCount;
#endif
    
}

- (instancetype)initWithSize:(CGSize)framebufferSize{
    GPUTextureFrameOptions defaultTextureOptions;
    defaultTextureOptions.minFilter = GL_LINEAR;
    defaultTextureOptions.magFilter = GL_LINEAR;
    defaultTextureOptions.wrapS = GL_CLAMP_TO_EDGE;
    defaultTextureOptions.wrapT = GL_CLAMP_TO_EDGE;
    defaultTextureOptions.internalFormat = GL_RGBA;
    defaultTextureOptions.format = GL_BGRA;
    defaultTextureOptions.type = GL_UNSIGNED_BYTE;
    
    self = [self initWithSize:framebufferSize
               textureOptions:defaultTextureOptions];
    return self;
}

- (instancetype)initWithSize:(CGSize)framebufferSize
              textureOptions:(GPUTextureFrameOptions)fboTextureOptions{
    self = [super init];
    if (self) {
        _size = framebufferSize;
        _textureOptions = fboTextureOptions;
        [self generateFramebuffer];
    }
    return self;
}

- (void)activateFramebuffer{
    glBindFramebuffer(GL_FRAMEBUFFER, _framebuffer);
    glViewport(0, 0, (int)_size.width, (int)_size.height);
}

- (void)dealloc{
    [self destroyFrameBuffer];
}

- (int)width{
    return _size.width;
}

- (int)height{
    return _size.height;
}

- (GLuint)texture{
    return _texture;
}

- (GLubyte *)byteBuffer{
#if TARGET_IPHONE_SIMULTOR || TARGET_OS_IPHONE
    CVPixelBufferLockBaseAddress(renderTarget, 0);
    GLubyte *bufferBytes = CVPixelBufferGetBaseAddress(renderTarget);
    CVPixelBufferUnlockBaseAddress(renderTarget, 0);
    return bufferBytes;
#else
    return NULL;
#endif
}

#pragma mark -- private method

- (void)generateTexture{
    glActiveTexture(GL_TEXTURE1);
    glGenTextures(1, &_texture);
    glBindTexture(GL_TEXTURE_2D, _texture);
    glTexParameteri(GL_TEXTURE_2D,
                    GL_TEXTURE_MIN_FILTER,
                    _textureOptions.minFilter);
    glTexParameteri(GL_TEXTURE_2D,
                    GL_TEXTURE_MAG_FILTER,
                    _textureOptions.magFilter);
    glTexParameteri(GL_TEXTURE_2D,
                    GL_TEXTURE_WRAP_S,
                    _textureOptions.wrapS);
    glTexParameteri(GL_TEXTURE_2D,
                    GL_TEXTURE_WRAP_T,
                    _textureOptions.wrapT);
}

- (void)generateFramebuffer{
    
    glGenFramebuffers(1, &_framebuffer);
    glBindFramebuffer(GL_FRAMEBUFFER, _framebuffer);
    
    if ([BLImageContext supportFastTextureUpload]) {
        CVOpenGLESTextureCacheRef coreVideoTextureCache = [[BLImageContext shareImageProcessingContext] coreVideoTextureCache];
        
        CFDictionaryRef empty;
        CFMutableDictionaryRef attrs;
        empty = CFDictionaryCreate(kCFAllocatorDefault,
                                   NULL,
                                   NULL,
                                   0,
                                   &kCFTypeDictionaryKeyCallBacks,
                                   &kCFTypeDictionaryValueCallBacks);
        attrs = CFDictionaryCreateMutable(kCFAllocatorDefault,
                                          1,
                                          &kCFTypeDictionaryKeyCallBacks,
                                          &kCFTypeDictionaryValueCallBacks);
        CFDictionarySetValue(attrs, kCVPixelBufferIOSurfacePropertiesKey, empty);
        
        //如果要创建空的image buffer(CVPixelBuffer)并和texture绑定用来render，那么创建时需要为dictionary指定一个特殊的key:kCVPixelBufferIOSurfacePropertiesKey
        CVReturn err = CVPixelBufferCreate(kCFAllocatorDefault,
                                           (int)_size.width,
                                           (int)_size.height,
                                           kCVPixelFormatType_32BGRA,
                                           attrs,
                                           &renderTarget);
        if (err) {
            NSLog(@"FBO Size:%f, %f", _size.width, _size.height);
            NSAssert(NO, @"Error at CVPixelBufferCreate %d", err);
        }
        
        /**
         * Core Video允许OpenGL ES的texture 和一个image buffer绑定，从而省略创建texture的步骤，也方便对image buffer操作，例如以多种格式读取其中的数据而不用glReadPixels 这样比较费时的方法。Core Video中的OpenGL ES texture类型为CVOpenGLESTextureRef。
         *
         * CVOpenGLESTextureRef 一种基于纹理的图像缓冲区，为OpenGL ES提供源图像数据
         * typedef CVImageBufferRef CVOpenGLESTextureRef
         *
         * image buffer类型为CVImageBufferRef 其实两个类型是一回事
         *
         * 这些texture是由CVOpenGLESTextureCache缓存、管理的。可以用CVOpenGLESTextureCacheTextureFromImage来从image buffer 得到 texture 并将两者绑定，该texture可能是新建的或缓存的但未使用。用CVOpenGLESTextureCacheFlush来清理未使用的缓存
         *
         * CVOpenGLESTextureCacheCreateTextureFromImage-从已经存在的CVImageBufferRef创建一个CVOpenGLESTextureRef
         */
        err = CVOpenGLESTextureCacheCreateTextureFromImage(kCFAllocatorDefault,
                                                           coreVideoTextureCache,
                                                           renderTarget,
                                                           NULL,
                                                           GL_TEXTURE_2D,
                                                           _textureOptions.internalFormat,
                                                           (int)_size.width,
                                                           (int)_size.height,
                                                           _textureOptions.format,
                                                           _textureOptions.type,
                                                           0,
                                                           &renderTexture);
        if (err) {
            NSAssert(NO, @"Error at CVOpenGLESTextureCacheCreateTextureFromImage %d", err);
        }
        
        CFRelease(attrs);
        CFRelease(empty);
        
        glBindTexture(CVOpenGLESTextureGetTarget(renderTexture),
                      CVOpenGLESTextureGetName(renderTexture));
        
        _texture = CVOpenGLESTextureGetName(renderTexture);
        
        glTexParameterf(GL_TEXTURE_2D, GL_TEXTURE_WRAP_S, _textureOptions.wrapS);
        glTexParameterf(GL_TEXTURE_2D, GL_TEXTURE_WRAP_T, _textureOptions.wrapT);
        
        //附加到帧缓冲上
        glFramebufferTexture2D(GL_FRAMEBUFFER,
                               GL_COLOR_ATTACHMENT0,
                               GL_TEXTURE_2D,
                               CVOpenGLESTextureGetName(renderTexture),
                               0);
        /** glFramebufferTexture2D参数
         * target: 帧缓冲的目标(绘制、读取或者两者皆有)
         * attachment: 我们想要的附加的附件类型   当前我们正在附加一个颜色附件。注意最后的0意味着我们可以附加多个颜色附件，
         * textarget: 你希望附加的纹理类型
         * texture: 要附加的纹理本身
         * Level: 多级渐远纹理的级别     我们将它保留为0
         */
    } else {
        [self generateTexture];
        glBindTexture(GL_TEXTURE_2D,
                      _texture);
        glTexImage2D(GL_TEXTURE_2D,
                     0,
                     _textureOptions.internalFormat,
                     (int)_size.width,
                     (int)_size.height,
                     0,
                     _textureOptions.format,
                     _textureOptions.type,
                     0);
        glFramebufferTexture2D(GL_FRAMEBUFFER,
                               GL_COLOR_ATTACHMENT0,
                               GL_TEXTURE_2D,
                               _texture,
                               0);
    }
    glBindTexture(GL_TEXTURE_2D, 0);
}



- (void)destroyFrameBuffer{
    runSyncOnVideoProcessingQueue(^{
        if (self->_framebuffer) {
            glDeleteFramebuffers(1, &self->_framebuffer);
            self->renderTarget = NULL;
        }
        
        if ([BLImageContext supportFastTextureUpload]) {
            if (self->renderTarget) {
                CFRelease(self->renderTarget);
                self->renderTarget = NULL;
            }
            
            if (self->renderTexture) {
                CFRelease(self->renderTexture);
                self->renderTexture = NULL;
            }
        } else {
            glDeleteTextures(1, &self->_texture);
        }
    });
}

@end
