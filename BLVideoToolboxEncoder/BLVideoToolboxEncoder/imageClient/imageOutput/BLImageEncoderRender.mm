//
//  BLImageEncoderRender.m
//  BLVideoToolboxEncoder
//
//  Created by luowailin on 2019/10/30.
//  Copyright © 2019 luowailin. All rights reserved.
//

#import "BLImageEncoderRender.h"
#import "BLImageOutput.h"
#import "BLImageProgram.h"
#import "H264HwEncoderHandler.h"
#import "BLImageContext.h"

#import <OpenGLES/ES2/gl.h>
#import <OpenGLES/ES2/glext.h>

NSString *const videoEncodeVertexShaderString = SHADER_STRING
(
 attribute vec4 position;
 attribute vec4 inputTextureCoordinate;
 
 varying vec2 textureCoordinate;
 
 void main(){
    gl_Position = position;
    textureCoordinate = inputTextureCoordinate.xy;
}
 );

NSString *const videoEncodeFragmentShaderString = SHADER_STRING
(
 varying highp vec2 textureCoordinate;
 
 uniform sampler2D inputImageTexture;
 
 void main(){
    gl_FragColor = texture2D(inputImageTexture, textureCoordinate);
}
 );

NSString *const videoEncodeColorSwizzlingFragmentShaderString = SHADER_STRING
(
 varying highp vec2 textureCoordinate;
 
 uniform sampler2D inputImageTexture;
 
 void main(){
    gl_FragColor = texture2D(inputImageTexture, textureCoordinate).bgra;
}
 );


@implementation BLImageEncoderRender
{
    GLuint _encodeFramebuffer;
    GLuint _encodeRenderbuffer;
    uint8_t *_renderTargetBuf;
    
    int _width;
    int _height;
    float _fps;
    int _maxBitRate;
    int _avgBitRate;
    
    BLImageProgram *_program;
    GLint displayPositionAttribute;
    GLint displayTextureCoordinateAttribute;
    GLint displayInputTextureUniform;
    
    H264HwEncoderImpl *_h264Encoder;
    H264HwEncoderHandler *_h264HwEncoderHandler;
    id<BLVideoEncoderStatusDelegate> _encoderStatusDelegate;
    
    /**把编码放到一个单独的线程中去*/
    BLImageContext *_encoderContext;
}

- (instancetype)initWithWidth:(int)width
                       height:(int)height
                          fps:(float)fps
                   maxBitRate:(int)maxBitRate
                   avgBitRate:(int)avgBitRate
        encoderStatusDelegate:(nonnull id<BLVideoEncoderStatusDelegate>)encoderStatusDelegate{
    self = [super init];
    if (self) {
        _width = width;
        _height = height;
        _encoderStatusDelegate = encoderStatusDelegate;
        _fps = fps;
        _maxBitRate = maxBitRate;
        _avgBitRate = avgBitRate;
        [self h264Encoder];
    }
    return self;
}

- (void)settingMaxBitRate:(int)maxBitRate avgBitRate:(int)avgBitRate fps:(int)fps{
    if (_h264Encoder) {
        [_h264Encoder settingMaxBitRate:maxBitRate
                             avgBitRate:avgBitRate
                                    fps:fps];
    }
}

- (BOOL)prepareRender{
    BOOL ret = TRUE;
    
    _encoderContext = [[BLImageContext alloc] init];
    [_encoderContext useSharegroup:[[[BLImageContext shareImageProcessingContext] context] sharegroup]];
    
    NSLog(@"Create _encodeContext Success...");
    
    dispatch_sync([_encoderContext contextQueue], ^{
        [self->_encoderContext useAsCurrentContext];
        if ([BLImageContext supportFastTextureUpload]) {
            self->_program = [[BLImageProgram alloc] initWithVertexShaderString:videoEncodeVertexShaderString
                                                     fragmentShaderString:videoEncodeFragmentShaderString];
        } else {
           self->_program = [[BLImageProgram alloc] initWithVertexShaderString:videoEncodeVertexShaderString
                                                     fragmentShaderString:videoEncodeColorSwizzlingFragmentShaderString];
        }
        
        if (self->_program) {
            [self->_program addAttribute:@"position"];
            [self->_program addAttribute:@"inputTextureCoordinate"];
            if ([self->_program link]) {
                displayPositionAttribute = [self->_program attributeIndex:@"position"];
                displayTextureCoordinateAttribute = [self->_program attributeIndex:@"inputTextureCoordinate"];
                displayInputTextureUniform = [self->_program uniformIndex:@"inputImageTexture"];
                
                [self->_program use];
                glEnableVertexAttribArray(displayPositionAttribute);
                glEnableVertexAttribArray(displayTextureCoordinateAttribute);
            }
        }
    });
    
    return ret;
}

- (void)renderWithTextureId:(int)inputTex timingInfo:(CMSampleTimingInfo)timingInfo{
    glFinish();
    __weak typeof(BLImageEncoderRender *) weakSelf = self;
    dispatch_async([_encoderContext contextQueue], ^{
        [self->_encoderContext useAsCurrentContext];
        [weakSelf setFilterFBO];
        [self->_program use];
        
        glClearColor(1.0f, 0.0f, 0.0f, 1.0f);
        glClear(GL_COLOR_BUFFER_BIT| GL_DEPTH_BUFFER_BIT);
        
        glActiveTexture(GL_TEXTURE4);
        glBindTexture(GL_TEXTURE_2D, inputTex);
        
        glUniform1i(self->displayInputTextureUniform, 4);
        
        static const GLfloat imageVertices[] = {
            -1.0f, -1.0f,
             1.0f, -1.0f,
            -1.0f,  1.0f,
             1.0f,  1.0f,
        };
        
        static const GLfloat noRotationTextureCoordinates[] = {
            0.0f, 1.0f,
            1.0f, 1.0f,
            0.0f, 0.0f,
            1.0f, 0.0f,
        };
        
        glVertexAttribPointer(self->displayPositionAttribute, 2, GL_FLOAT, 0, 0, imageVertices);
        glEnableVertexAttribArray(self->displayPositionAttribute);
        glVertexAttribPointer(self->displayTextureCoordinateAttribute, 2, GL_FLOAT, 0, 0, noRotationTextureCoordinates);
        glEnableVertexAttribArray(self->displayTextureCoordinateAttribute);
        
        glDrawArrays(GL_TRIANGLE_STRIP, 0, 4);
        glFinish();
        
        
        
        //取出对应的这一帧图像，然后进行组成CMSampleBufferRef 最后进行编码
        CVPixelBufferRef pixel_buffer = NULL;
        if ([BLImageContext supportFastTextureUpload]) {
            pixel_buffer = self->renderTarget;
            CVReturn status = CVPixelBufferLockBaseAddress(pixel_buffer, 0);
            if (status != kCVReturnSuccess) {
                NSLog(@"CVPixelBufferLockBaseAddress pixel_buffer failed...");
            }
        } else {
            int bitmapBytesPerRow = self->_width * 4;
            OSType pixFmt = kCVPixelFormatType_32BGRA;
            CVReturn status = CVPixelBufferCreateWithBytes(kCFAllocatorDefault,
                                                           self->_width,
                                                           self->_height,
                                                           pixFmt,
                                                           [weakSelf renderTarget],
                                                           bitmapBytesPerRow,
                                                           NULL,
                                                           NULL,
                                                           NULL,
                                                           &pixel_buffer);
            
            if ((pixel_buffer == NULL) || (status != kCVReturnSuccess)) {
                CVPixelBufferRelease(pixel_buffer);
                return;
            } else {
                CVPixelBufferLockBaseAddress(pixel_buffer, 0);
                GLubyte *pixelBufferData = (GLubyte *)CVPixelBufferGetBaseAddress(pixel_buffer);
                glReadPixels(0, 0, self->_width, self->_height, GL_RGBA, GL_UNSIGNED_BYTE, pixelBufferData);
            }
        }
        
        CMSampleBufferRef encodeSampleBuffer = NULL;
        CMVideoFormatDescriptionRef videoInfo = NULL;
        CMVideoFormatDescriptionCreateForImageBuffer(NULL,
                                                     pixel_buffer,
                                                     &videoInfo);
        
        CMSampleBufferCreateForImageBuffer(kCFAllocatorDefault,
                                           pixel_buffer,
                                           true,
                                           NULL,
                                           NULL,
                                           videoInfo,
                                           &timingInfo,
                                           &encodeSampleBuffer);
        
        [[weakSelf h264Encoder] encode:encodeSampleBuffer];
        
        CVPixelBufferUnlockBaseAddress(pixel_buffer, 0);
        
        if (![BLImageContext supportFastTextureUpload]) {
            CVPixelBufferRelease(pixel_buffer);
        }
        CFRelease(videoInfo);
        CFRelease(encodeSampleBuffer);
    });
}

- (uint8_t *)renderTarget{
    if (nil == _renderTargetBuf) {
        int bitmapBytesPerRow = _width * 4;
        int bitmapByteCount = bitmapBytesPerRow * _height;
        _renderTargetBuf = new uint8_t[bitmapByteCount];
        memset(_renderTargetBuf, 0, sizeof(uint8_t) * bitmapByteCount);
    }
    return _renderTargetBuf;
}


- (H264HwEncoderImpl *)h264Encoder{
    if (!_h264Encoder) {
        _h264Encoder = [[H264HwEncoderImpl alloc] init];
        [_h264Encoder initWithConfiguration];
        _h264Encoder.delegate = self.H264HwEncoderHandler;
        _h264Encoder.encoderStatusDelegate = _encoderStatusDelegate;
        [_h264Encoder initEncode:_width
                          height:_height
                             fps:(int)_fps
                      maxBitRate:_maxBitRate
                      avgBitRate:_avgBitRate];
    }
    return _h264Encoder;
}

- (H264HwEncoderHandler *)H264HwEncoderHandler{
    if (_h264HwEncoderHandler) {
        _h264HwEncoderHandler = [[H264HwEncoderHandler alloc] init];
    }
    return _h264HwEncoderHandler;
}

- (void)setFilterFBO{
    if (!_encodeFramebuffer) {
        [self createDataFBO];
    }
    glBindFramebuffer(GL_FRAMEBUFFER, _encodeFramebuffer);
    glViewport(0, 0, _width, _height);
}

- (void)createRenderTargetWithSpecifiedPool{
    NSMutableDictionary *attributes;
    attributes = [NSMutableDictionary dictionary];
    [attributes setObject:[NSNumber numberWithInt:kCVPixelFormatType_32RGBA]
                   forKey:(NSString *)kCVPixelBufferPixelFormatTypeKey];
    [attributes setObject:[NSNumber numberWithInt:_width]
                   forKey:(NSString *)kCVPixelBufferWidthKey];
    [attributes setObject:[NSNumber numberWithInt:_height]
                   forKey:(NSString *)kCVPixelBufferHeightKey];
    
    CVPixelBufferPoolRef bufferPool = NULL;
    CVPixelBufferPoolCreate(kCFAllocatorDefault,
                            NULL,
                            (__bridge CFDictionaryRef)attributes,
                            &bufferPool);
    
    CVPixelBufferPoolCreatePixelBuffer(NULL,
                                       bufferPool,
                                       &renderTarget);
}

- (void)createRenderTargetWithSpecifiedMemPtr{
    int bitmapBytesPerRow = _width * 4;
    OSType pixFmt = kCVPixelFormatType_32RGBA;
    CVPixelBufferCreateWithBytes(kCFAllocatorDefault,
                                 _width,
                                 _height,
                                 pixFmt,
                                 [self renderTarget],
                                 bitmapBytesPerRow,
                                 NULL,
                                 NULL,
                                 NULL,
                                 &renderTarget);
    
    CVBufferSetAttachment(renderTarget,
                          kCVImageBufferColorPrimariesKey,
                          kCVImageBufferColorPrimaries_ITU_R_709_2,
                          kCVAttachmentMode_ShouldPropagate);
    
    CVBufferSetAttachment(renderTarget,
                          kCVImageBufferYCbCrMatrixKey,
                          kCVImageBufferYCbCrMatrix_ITU_R_601_4,
                          kCVAttachmentMode_ShouldPropagate);
    
    CVBufferSetAttachment(renderTarget,
                          kCVImageBufferTransferFunctionKey,
                          kCVImageBufferTransferFunction_ITU_R_709_2,
                          kCVAttachmentMode_ShouldPropagate);
}

- (void)createRenderTargetWithSpecifiedAttrs{
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
    
    
    CFDictionarySetValue(attrs,
                         kCVPixelBufferIOSurfacePropertiesKey,
                         empty);
    CVPixelBufferCreate(kCFAllocatorDefault,
                        _width,
                        _height,
                        kCVPixelFormatType_32BGRA,
                        attrs,
                        &renderTarget);
    
    CFRelease(attrs);
    CFRelease(empty);
}

- (void)createDataFBO{
    glActiveTexture(GL_TEXTURE1);
    glGenFramebuffers(1, &_encodeFramebuffer);
    glBindFramebuffer(GL_FRAMEBUFFER, _encodeFramebuffer);
    
    if ([BLImageContext supportFastTextureUpload]) {
        [self createRenderTargetWithSpecifiedAttrs];
        
        CVOpenGLESTextureCacheCreateTextureFromImage(kCFAllocatorDefault,
                                                     [_encoderContext coreVideoTextureCache],
                                                     renderTarget,
                                                     NULL,
                                                     GL_TEXTURE_2D,
                                                     GL_RGBA,
                                                     _width,
                                                     _height,
                                                     GL_BGRA,
                                                     GL_UNSIGNED_BYTE,
                                                     0,
                                                     &renderTexture);
        
        glBindTexture(CVOpenGLESTextureGetTarget(renderTexture),
                      CVOpenGLESTextureGetName(renderTexture));
        glTexParameterf(GL_TEXTURE_2D,
                        GL_TEXTURE_WRAP_S,
                        GL_CLAMP_TO_EDGE);
        glTexParameterf(GL_TEXTURE_2D, GL_TEXTURE_WRAP_T, GL_CLAMP_TO_EDGE);
        
        glFramebufferTexture2D(GL_FRAMEBUFFER,
                               GL_COLOR_ATTACHMENT0,
                               GL_TEXTURE_2D,
                               CVOpenGLESTextureGetName(renderTexture),
                               0);
        
        NSLog(@"Create render Texture Success..");
    } else {
        glGenRenderbuffers(1, &_encodeRenderbuffer);
        glBindRenderbuffer(GL_RENDERBUFFER, _encodeRenderbuffer);
        glRenderbufferStorage(GL_RENDERBUFFER, GL_RGBA8_OES, _width, _height);
        glFramebufferRenderbuffer(GL_FRAMEBUFFER,
                                  GL_COLOR_ATTACHMENT0,
                                  GL_RENDERBUFFER,
                                  _encodeRenderbuffer);
    }
    
    GLenum status = glCheckFramebufferStatus(GL_FRAMEBUFFER);
    if (status != GL_FRAMEBUFFER_COMPLETE) {
        NSLog(@"Incomplete filter FOB:%d", status);
    }
}

- (void)stopEncode{
    [self destoryDataFBO];
    [[self h264Encoder] endCompresseion];
    if (_renderTargetBuf) {
        delete [] _renderTargetBuf;
        _renderTargetBuf = nullptr;
    }
}

- (void)destoryDataFBO{
    dispatch_sync([_encoderContext contextQueue], ^{
        [self->_encoderContext useAsCurrentContext];
        if (self->_encodeFramebuffer) {
            glDeleteFramebuffers(1, &self->_encodeFramebuffer);
            self->_encodeFramebuffer = 0;
        }
        
        if (self->_encodeRenderbuffer) {
            glDeleteRenderbuffers(1, &self->_encodeRenderbuffer);
            _encodeRenderbuffer = 0;
        }
        
        if ([BLImageContext supportFastTextureUpload]) {
            if (renderTexture) {
                CFRelease(renderTexture);
            }
            
            if (renderTarget) {
                CVBufferRelease(renderTarget);
            }
            NSLog(@"Release Render Texture and Target Success..");
        }
    });
}



@end
