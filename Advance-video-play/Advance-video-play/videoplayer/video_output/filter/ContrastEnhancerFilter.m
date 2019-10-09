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

/**
 * 纹理单元 Texture Unit  sampler2D
 * 为什么sampler2D变量是个uniform，却不用glUniform给它赋值。
 * 使用glUniformli 我们可以给纹理采样器分配一个位置值，这样，能够在一个片元着色器中设置多个纹理。一个纹理的位置值通常称为一个纹理单元
 *
 * 纹理单元的主要目的是让我们能够在着色器中可以使用多于一个的纹理。通过把纹理单元赋值给采样器，我们可以一次绑定多个纹理，只要我们激活对应的纹理单元，就可以使用了
 */


NSString *const contrastFragmentShaderString = SHADER_STRING
(
 precision mediump float;
 uniform sampler2D inputImageTexture;
 varying vec2 v_texcoord;
 void main(){
     lowp vec4 textureColor = texture2D(inputImageTexture, v_texcoord);
    //颜色的改变 颜色的加深
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
    return _contrastTextureID;   //给DirectPassRenderer去进行纹理的数据处理
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
    }; //OpenGL二维纹理坐标  此坐标和计算机图像二维纹理坐标 正好是旋转180度   还有一种解释就是 OpenGL要求y轴0.0坐标是在图片的底部的，但是图片的y轴0.0坐标通常在顶部解决的方法是翻转y轴
    
    glVertexAttribPointer(filterPositionAttribute, 2, GL_FLOAT, 0, 0, imageVertices);
    glEnableVertexAttribArray(filterPositionAttribute);
    
    glVertexAttribPointer(filterTextureCoordinateAttribute, 2, GL_FLOAT, 0, 0, noRotationTextureCoordinates);
    glEnableVertexAttribArray(filterTextureCoordinateAttribute);
    
    glDrawArrays(GL_TRIANGLE_STRIP, 0, 4);
    glBindFramebuffer(GL_FRAMEBUFFER, 0);
}


@end
