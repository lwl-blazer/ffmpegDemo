//
//  YUVFrameFastCopier.m
//  Advance-video-play
//
//  Created by luowailin on 2019/9/11.
//  Copyright © 2019 luowailin. All rights reserved.
//

#import "YUVFrameFastCopier.h"
#import <CoreVideo/CoreVideo.h>
#import <OpenGLES/EAGL.h>

__unused static const GLfloat kColorConversion601[] = {
    1.164,  1.164, 1.164,
      0.0, -0.392, 2.017,
    1.596, -0.813, 0.0,
};

GLfloat kColorConversion601FullRangeDefault[] = {
    1.0,   1.0,    1.0,
    0.0, -0.343, 1.765,
    1.4, -0.711,   0.0,
};

GLfloat kColorConversion601FullRange[] = {
       1.0,     1.0,      1.0,
       0.0, -0.39465, 2.03211,
   1.13983, -0.58060,     0.0,
};

static const GLfloat kColorConversion709[] = {
    1.164,  1.164, 1.164,
    0.0,   -0.213, 2.112,
    1.793, -0.533, 0.0,
};

NSString *const yuvFasterVertexShaderString = SHADER_STRING
(
 attribute vec4 position;
 attribute vec2 texcoord;
 uniform mat4 modelViewProjectionMatrix;
 varying vec2 v_texcoord;
 void main(){
     gl_Position = modelViewProjectionMatrix * position;
     v_texcoord = texcoord.xy;
 }
 );

NSString *const yuvFasterFragmentShaderString = SHADER_STRING
(
 varying highp vec2 v_texcoord;
 precision mediump float;
 
 uniform sampler2D inputImageTexture;
 uniform sampler2D SamplerUV;
 uniform mat3 colorConversionMatrix;
 void main(){
     mediump vec3 yuv;
     lowp vec3 rgb;
     
     yuv.x = texture2D(inputImageTexture, v_texcoord).r;
     yuv.yz = texture2D(SamplerUV, v_texcoord).ra - vec2(0.5, 0.5);
     
     rgb = colorConversionMatrix * yuv;
     gl_FragColor = vec4(rgb, 1);
 }
);


@interface YUVFrameFastCopier ()
{
    GLuint _framebuffer;
    GLuint _outputTextureID;
    
    GLint _uniformMatrix;
    GLint _chromaInputTextureUniform;
    GLint _colorConversionMatrixUniform;
    
    CVOpenGLESTextureRef _lumaTexture;
    CVOpenGLESTextureRef _chromaTexture;
    CVOpenGLESTextureCacheRef _videoTextureCache;
    
    const GLfloat *_preferredConversion;
    CVPixelBufferPoolRef _pixelBufferPool;
}

@end

@implementation YUVFrameFastCopier

- (BOOL)prepareRender:(NSInteger)frameWidth height:(NSInteger)frameHeight{
    BOOL ret = NO;
    
    if ([self buildProgram:yuvFasterVertexShaderString
            fragmentShader:yuvFasterFragmentShaderString]) {
        _chromaInputTextureUniform = glGetUniformLocation(filterProgram, "SamplerUV");
        _colorConversionMatrixUniform = glGetUniformLocation(filterProgram, "colorConversionMatrix");
        
        glUseProgram(filterProgram);
        glEnableVertexAttribArray(filterPositionAttribute);
        glEnableVertexAttribArray(filterTextureCoordinateAttribute);
        
        //生成FBO and TextureID
        glGenFramebuffers(1, &_framebuffer);
        glBindFramebuffer(GL_FRAMEBUFFER, _framebuffer);
        
        glActiveTexture(GL_TEXTURE1);
        glGenTextures(1, &_outputTextureID);
        glBindTexture(GL_TEXTURE_2D, _outputTextureID);
        
        glTexParameteri(GL_TEXTURE_2D, GL_TEXTURE_MIN_FILTER, GL_LINEAR);
        glTexParameteri(GL_TEXTURE_2D, GL_TEXTURE_MAG_FILTER, GL_LINEAR);
        glTexParameteri(GL_TEXTURE_2D, GL_TEXTURE_WRAP_S, GL_CLAMP_TO_EDGE);
        glTexParameteri(GL_TEXTURE_2D, GL_TEXTURE_WRAP_T, GL_CLAMP_TO_EDGE);
        
        glTexImage2D(GL_TEXTURE_2D, 0, GL_RGBA, (int)frameWidth, (int)frameHeight, 0, GL_BGRA, GL_UNSIGNED_BYTE, 0);
        NSLog(@"width=%d, height=%d", (int)frameWidth, (int)frameHeight);
        
        glFramebufferTexture2D(GL_FRAMEBUFFER, GL_COLOR_ATTACHMENT0, GL_TEXTURE_2D, _outputTextureID, 0);
        GLenum status = glCheckFramebufferStatus(GL_FRAMEBUFFER);
        if (status != GL_FRAMEBUFFER_COMPLETE) {
           NSLog(@"failed to make complete framebuffer object %x", status);
        }
        
        
        glBindTexture(GL_TEXTURE_2D, 0);
        if (!_videoTextureCache) {
            EAGLContext *context = [EAGLContext currentContext];
            CVReturn err = CVOpenGLESTextureCacheCreate(kCFAllocatorDefault, NULL, context, NULL, &_videoTextureCache);
            
            if (err != noErr) {
                NSLog(@"Error at CVOpenGLESTextureCacheCreate %d", err);
                return NO;
            }
        }
        
        _preferredConversion = kColorConversion709;
        _preferredConversion = kColorConversion601FullRange;
        
//        _preferredConversion = kColorConversion601FullRangeDefault;
//        _preferredConversion = kColorConversion601;
        
        ret = YES;
    }
    
    return ret;
}

- (GLint)outputTextureID{
    return _outputTextureID;
}

- (void)uploadTexture:(VideoFrame *)videoFrame width:(int)frameWidth height:(int)frameHeight{
    CVImageBufferRef pixelBuffer = nil;
    if (videoFrame.type == VideoFrameType) {
        pixelBuffer = [self buildCVPixelBufferByVideoFrame:videoFrame width:frameWidth height:frameHeight];
    } else if (videoFrame.type == iOSCVVideoFrameType) {
        pixelBuffer = (__bridge CVImageBufferRef)videoFrame.imageBuffer;
    }
    
    if (pixelBuffer) {
        [self clearUpTextures];
        glActiveTexture(GL_TEXTURE0);
        
        CVReturn err;
        err = CVOpenGLESTextureCacheCreateTextureFromImage(kCFAllocatorDefault,
                                                           _videoTextureCache,
                                                           pixelBuffer,
                                                           NULL,
                                                           GL_TEXTURE_2D,
                                                          // GL_RED_EXT,
                                                           GL_LUMINANCE,
                                                           frameWidth,
                                                           frameHeight,
                                                           GL_LUMINANCE,
                                                          // GL_RED_EXT,
                                                           GL_UNSIGNED_BYTE,
                                                           0,
                                                           &_lumaTexture);
        
        if (err) {
            NSLog(@"Error at CVOpenGLESTextureCacheCreateTextureFromImage %d", err);
        }
        
        glBindTexture(CVOpenGLESTextureGetTarget(_lumaTexture), CVOpenGLESTextureGetName(_lumaTexture));
        glTexParameteri(GL_TEXTURE_2D, GL_TEXTURE_MIN_FILTER, GL_LINEAR);
        glTexParameteri(GL_TEXTURE_2D, GL_TEXTURE_MAG_FILTER, GL_LINEAR);
        glTexParameteri(GL_TEXTURE_2D, GL_TEXTURE_WRAP_S, GL_CLAMP_TO_EDGE);
        glTexParameteri(GL_TEXTURE_2D, GL_TEXTURE_WRAP_T, GL_CLAMP_TO_EDGE);
        
        //UV-plane
        glActiveTexture(GL_TEXTURE1);
        err = CVOpenGLESTextureCacheCreateTextureFromImage(kCFAllocatorDefault,
                                                           _videoTextureCache,
                                                           pixelBuffer,
                                                           NULL,
                                                           GL_TEXTURE_2D,
                                                           GL_LUMINANCE_ALPHA,
                                                           frameWidth / 2,
                                                           frameHeight / 2,
                                                           GL_LUMINANCE_ALPHA,
                                                           GL_UNSIGNED_BYTE,
                                                           1,
                                                           &_chromaTexture);
        if (err) {
            NSLog(@"Error at CVOpenGLESTextureCacheCreateTextureFromImage %d", err);
        }
        
        glBindTexture(CVOpenGLESTextureGetTarget(_chromaTexture), CVOpenGLESTextureGetName(_chromaTexture));
        glTexParameteri(GL_TEXTURE_2D, GL_TEXTURE_MIN_FILTER, GL_LINEAR);
        glTexParameteri(GL_TEXTURE_2D, GL_TEXTURE_MAG_FILTER, GL_LINEAR);
        glTexParameteri(GL_TEXTURE_2D, GL_TEXTURE_WRAP_S, GL_CLAMP_TO_EDGE);
        glTexParameteri(GL_TEXTURE_2D, GL_TEXTURE_WRAP_T, GL_CLAMP_TO_EDGE);
        
        if (videoFrame.type == VideoFrameType) {
            CFRelease(pixelBuffer);
        }
    }
    
}

- (CVImageBufferRef)buildCVPixelBufferByVideoFrame:(VideoFrame *)videoFrame width:(int)width height:(int)height{
    CVPixelBufferRef pixelBuffer = nil;
    CVReturn error;
    
    if (!_pixelBufferPool) {
        NSMutableDictionary *attributes = [NSMutableDictionary dictionary];
        [attributes setObject:[NSNumber numberWithInt:kCVPixelFormatType_420YpCbCr8BiPlanarFullRange]
                       forKey:(NSString *)kCVPixelBufferPixelFormatTypeKey];
        [attributes setObject:[NSNumber numberWithInt:width]
                       forKey:(NSString *)kCVPixelBufferWidthKey];
        [attributes setObject:[NSNumber numberWithInt:height]
                       forKey:(NSString *)kCVPixelBufferHeightKey];
        [attributes setObject:@(videoFrame.linesize)
                       forKey:(NSString *)kCVPixelBufferBytesPerRowAlignmentKey];
        [attributes setObject:[NSDictionary dictionary]
                       forKey:(NSString *)kCVPixelBufferIOSurfacePropertiesKey];
        
        error = CVPixelBufferPoolCreate(kCFAllocatorDefault,
                                        NULL,
                                        (__bridge CFDictionaryRef)attributes,
                                        &_pixelBufferPool);
        if (error != kCVReturnSuccess) {
            NSLog(@"CVPixelBufferPool Create Failed...");
        }
    }
    
    if (!_pixelBufferPool) {
        NSLog(@"pixelBuffer Pool is NULL...");
    }
    
    CVPixelBufferPoolCreatePixelBuffer(NULL,
                                       _pixelBufferPool,
                                       &pixelBuffer);
    if (!pixelBuffer) {
        NSLog(@"CVPixelBufferPoolCreatePixelBuffer Failed...");
    }
    
    size_t bytePerRowY = CVPixelBufferGetBytesPerRowOfPlane(pixelBuffer, 0);
    size_t bytePerRowUV = CVPixelBufferGetBytesPerRowOfPlane(pixelBuffer, 0);
    int lumaDataSize = (int)(bytePerRowY * bytePerRowUV);
    uint8_t *lumaData = malloc(lumaDataSize);
    uint8_t *luma = (uint8_t *)videoFrame.luma.bytes;
    
    for (int i = 0; i < height; i ++) {
        memcpy(lumaData, luma, width);
        luma += width;
        lumaData += width;
    }
    lumaData -=lumaDataSize;
    
    
    uint8_t *sourceChromaB = (uint8_t *)(videoFrame.chromaB.bytes);
    uint8_t *sourceChromaR = (uint8_t *)(videoFrame.chromaR.bytes);
    
    int chromDataSize = (int)bytePerRowUV * height / 2;
    uint8_t *chromaB = malloc(chromDataSize / 2);
    uint8_t *chromaR = malloc(chromDataSize / 2);
    for (int i = 0; i < height / 2; i++) {
        memcpy(chromaB, sourceChromaB, width/2);
        memcpy(chromaR, sourceChromaR, width/2);
        sourceChromaB += width / 2;
        sourceChromaR += width / 2;
        chromaB += bytePerRowUV / 2;
        chromaR += bytePerRowUV / 2;
    }
    
    chromaB -= chromDataSize / 2;
    chromaR -= chromDataSize / 2;
    
    uint8_t *chromData = malloc(chromDataSize);
    for (int i = 0; i < chromDataSize; i ++) {
        if (i % 2 == 0) {
            chromData[i] = chromaB[i / 2];
        } else {
            chromData[i] = chromaR[i / 2];
        }
    }
    
    CVPixelBufferLockBaseAddress(pixelBuffer, 0);
    void *base = CVPixelBufferGetBaseAddressOfPlane(pixelBuffer, 0);
    memcpy(base, lumaData, lumaDataSize);
    
    base = CVPixelBufferGetBaseAddressOfPlane(pixelBuffer, 1);
    memcpy(base, chromData, chromDataSize);
    
    free(chromaB);
    free(chromaR);
    free(lumaData);
    free(chromData);
    
    CVPixelBufferUnlockBaseAddress(pixelBuffer, 0);
    return pixelBuffer;
}

- (void)renderWithTexId:(VideoFrame *)videoFrame{
    int frameWidth = (int)[videoFrame width];
    int frameHeight = (int)[videoFrame height];
    
    glBindFramebuffer(GL_FRAMEBUFFER, _framebuffer);
    glUseProgram(filterProgram);
    glViewport(0, 0, frameWidth, frameHeight);
    glClearColor(0.0f, 0.0f, 0.0f, 1.0f);
    glClear(GL_COLOR_BUFFER_BIT|GL_DEPTH_BUFFER_BIT);
    
    [self uploadTexture:videoFrame width:frameWidth height:frameHeight];
    
    static const GLfloat imageVertices[] = {
        -1.0f, -1.0f,
         1.0f, -1.0f,
        -1.0f,  1.0f,
         1.0f,  1.0f,
    };
 
    GLfloat noRotationTextureCoordinates[] = {
        0.0f, 1.0f,
        1.0f, 1.0f,
        0.0f, 0.0f,
        1.0f, 0.0f,
    };
    
    glVertexAttribPointer(filterPositionAttribute, 2, GL_FLOAT, 0, 0, imageVertices);
    glEnableVertexAttribArray(filterPositionAttribute);
    
    glVertexAttribPointer(filterTextureCoordinateAttribute, 2, GL_FLOAT, 0, 0, noRotationTextureCoordinates);
    glEnableVertexAttribArray(filterTextureCoordinateAttribute);
    
    glActiveTexture(GL_TEXTURE0);
    glBindTexture(GL_TEXTURE_2D, CVOpenGLESTextureGetName(_lumaTexture));
    glUniform1i(filterInputTextureUniform, 0);
    
    glActiveTexture(GL_TEXTURE1);
    glBindTexture(GL_TEXTURE_2D, CVOpenGLESTextureGetName(_chromaTexture));
    glUniform1i(_chromaInputTextureUniform, 1);
    
    glUniformMatrix3fv(_colorConversionMatrixUniform, 1, GL_FALSE, _preferredConversion);
    
    GLfloat modelviewPorj[16];
    mat4f_LoadOrtho(-1.0f, 1.0f, -1.0f, 1.0f, -1.0f, 1.0f, modelviewPorj);
    glUniformMatrix4fv(_uniformMatrix, 1, GL_FALSE, modelviewPorj);
    
    glDrawArrays(GL_TRIANGLE_STRIP, 0, 4);
    glBindFramebuffer(GL_FRAMEBUFFER, 0);
    
}

- (void)clearUpTextures{
    if (_lumaTexture) {
        CFRelease(_lumaTexture);
        _lumaTexture = NULL;
    }
    
    if (_chromaTexture) {
        CFRelease(_chromaTexture);
        _chromaTexture = NULL;
    }
    
    CVOpenGLESTextureCacheFlush(_videoTextureCache, 0);
}

- (void)releaseRender{
    [super releaseRender];
    if (_outputTextureID) {
        glDeleteTextures(1, &_outputTextureID);
        _outputTextureID = 0;
    }
    
    if (_framebuffer) {
        glDeleteFramebuffers(1, &_framebuffer);
        _framebuffer = 0;
    }
    
    [self clearUpTextures];
    
    if (_videoTextureCache) {
        CFRelease(_videoTextureCache);
    }
    
    if (_pixelBufferPool) {
        CFRelease(_pixelBufferPool);
    }
}


@end
