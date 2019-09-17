//
//  ContrastEnhancerFilter.m
//  Advance-video-play
//
//  Created by luowailin on 2019/9/11.
//  Copyright © 2019 luowailin. All rights reserved.
//

#import "ContrastEnhancerFilter.h"

NSString *const contrastVertexShaderString = SHADER_STRING
(
 attribute vec4 position;
 attribute vec2 texcoord;
 varying vec2 v_texcoord;
 
 void main(){
     gl_Position = position;
     v_texcoord = texcoord;
 }
);

NSString *const contrastFragmentShaderString = SHADER_STRING
(
 precision mediump float;
 uniform sampler2D inputImageTexture;
 varying vec2 v_texcoord;
 void main(){
     lowp vec4 textureColor = texture2D(inputImageTexture, v_texcoord);
     gl_FragColor = vec4((textureColor.rgb - 0.36 * (textureColor.rgb - vec3(0.63)) * (textureColor.rgb - vec3(0.63))), textureColor.w);
 }
 );

@interface ContrastEnhancerFilter ()
{
    GLuint _contrastbuffer;
    GLuint _contrastTextureID;
}

@end

@implementation ContrastEnhancerFilter

- (BOOL)prepareRender:(NSInteger)frameWidth height:(NSInteger)frameHeight{
    BOOL ret = NO;
    if ([self buildProgram:contrastVertexShaderString
            fragmentShader:contrastFragmentShaderString]) {
        glUseProgram(filterProgram);
        glEnableVertexAttribArray(filterPositionAttribute);
        glEnableVertexAttribArray(filterTextureCoordinateAttribute);
        
        //生成FBO and TextureID
        glGenFramebuffers(1, &_contrastbuffer);
        glBindFramebuffer(GL_FRAMEBUFFER, _contrastbuffer);
        
        glActiveTexture(GL_TEXTURE1);
        glGenTextures(1, &_contrastTextureID);
        glBindTexture(GL_TEXTURE_2D, _contrastTextureID);
        
        glTexParameteri(GL_TEXTURE_2D, GL_TEXTURE_MIN_FILTER, GL_LINEAR);
        glTexParameteri(GL_TEXTURE_2D, GL_TEXTURE_MAG_FILTER, GL_LINEAR);
        glTexParameteri(GL_TEXTURE_2D, GL_TEXTURE_WRAP_S, GL_CLAMP_TO_EDGE);
        glTexParameteri(GL_TEXTURE_2D, GL_TEXTURE_WRAP_T, GL_CLAMP_TO_EDGE);
        
        glTexImage2D(GL_TEXTURE_2D, 0, GL_RGBA, (int)frameWidth, (int)frameHeight, 0, GL_BGRA, GL_UNSIGNED_BYTE, 0);
        
        glFramebufferTexture2D(GL_FRAMEBUFFER, GL_COLOR_ATTACHMENT0, GL_TEXTURE_2D, _contrastTextureID, 0);
        
        GLenum status = glCheckFramebufferStatus(GL_FRAMEBUFFER);
        
        if (status != GL_FRAMEBUFFER_COMPLETE) {
            NSLog(@"failed to make complete framebuffer object %x", status);
        }
        
        glBindTexture(GL_TEXTURE_2D, 0);
        ret = YES;
    }
    return ret;
}

- (void)releaseRender{
    [super releaseRender];
    if (_contrastbuffer) {
        glDeleteFramebuffers(1, &_contrastbuffer);
        _contrastbuffer = 0;
    }
    
    if (_contrastTextureID) {
        glDeleteTextures(1, &_contrastTextureID);
        _contrastTextureID = 0;
    }
}

- (GLint)outputTextureID{
    return _contrastTextureID;
}

- (void)renderWithWidth:(NSInteger)width height:(NSInteger)height position:(float)position{
    glBindFramebuffer(GL_FRAMEBUFFER, _contrastbuffer);
    glUseProgram(filterProgram);
    
    glViewport(0, 0, (int)width, (int)height);
    glClearColor(0.0f, 0.0f, 0.0f, 1.0f);
    glClear(GL_COLOR_BUFFER_BIT|GL_DEPTH_BUFFER_BIT);
    
    glActiveTexture(GL_TEXTURE0);
    glBindTexture(GL_TEXTURE_2D, _inputTexId);
    glUniform1i(filterInputTextureUniform, 0);
    
    static const GLfloat imageVertices[] = {
       -1.0f, -1.0f,
        1.0f, -1.0f,
       -1.0f,  1.0f,
        1.0f,  1.0f,
    };
    
    GLfloat noRotationTextureCoordinates[] = {
        0.0f, 0.0f,
        1.0f, 0.0f,
        0.0f, 1.0f,
        1.0f, 1.0f,
    };
    
    glVertexAttribPointer(filterPositionAttribute, 2, GL_FLOAT, 0, 0, imageVertices);
    glEnableVertexAttribArray(filterPositionAttribute);
    
    glVertexAttribPointer(filterTextureCoordinateAttribute, 2, GL_FLOAT, 0, 0, noRotationTextureCoordinates);
    glEnableVertexAttribArray(filterTextureCoordinateAttribute);
    
    glDrawArrays(GL_TRIANGLE_STRIP, 0, 4);
    glBindFramebuffer(GL_FRAMEBUFFER, 0);
}


@end
