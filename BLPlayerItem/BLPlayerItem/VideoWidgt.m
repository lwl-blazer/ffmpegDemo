//
//  VideoWidgt.m
//  BLPlayerItem
//
//  Created by luowailin on 2019/4/19.
//  Copyright © 2019 luowailin. All rights reserved.
//

#import "VideoWidgt.h"
#import <GLKit/GLKit.h>
#import "ShaderProgram.h"

@interface VideoWidgt ()
{
    GLuint unis[3];
    GLuint texs[3];
    unsigned char *datas[3];
}

@property(nonatomic, assign) int width;
@property(nonatomic, assign) int height;

@property(nonatomic, strong) ShaderProgram *program;

@end

@implementation VideoWidgt

- (instancetype)initWithWidth:(int)width height:(int)height
{
    self = [super init];
    if (self) {
        self.width = width;
        self.height = height;
        
        //申请空间
        datas[0] = (unsigned char *)malloc(width * height);
        datas[1] = (unsigned char *)malloc(width * height / 4);
        datas[2] = (unsigned char *)malloc(width * height / 4);
        
        if (texs[0]) {
            glDeleteTextures(3, texs);
        }
        
        glGenTextures(3, texs);
        glBindTexture(GL_TEXTURE_2D, texs[0]);
        glTexParameteri(GL_TEXTURE_2D, GL_TEXTURE_MIN_FILTER, GL_LINEAR);
        glTexParameteri(GL_TEXTURE_2D, GL_TEXTURE_MAG_FILTER, GL_LINEAR);
        glTexImage2D(GL_TEXTURE_2D, 0, GL_RGB, width/2, height/2, 0, GL_RGB, GL_UNSIGNED_BYTE, NULL);
        
        glBindTexture(GL_TEXTURE_2D, texs[1]);
        glTexParameteri(GL_TEXTURE_2D, GL_TEXTURE_MIN_FILTER, GL_LINEAR);
        glTexParameteri(GL_TEXTURE_2D, GL_TEXTURE_MAG_FILTER, GL_LINEAR);
        glTexImage2D(GL_TEXTURE_2D, 0, GL_RGB, width/2, height/2, 0, GL_RGB, GL_UNSIGNED_BYTE, NULL);
        
        glBindTexture(GL_TEXTURE_2D, texs[2]);
        glTexParameteri(GL_TEXTURE_2D, GL_TEXTURE_MIN_FILTER, GL_LINEAR);
        glTexParameteri(GL_TEXTURE_2D, GL_TEXTURE_MAG_FILTER, GL_LINEAR);
        glTexImage2D(GL_TEXTURE_2D, 0, GL_RGB, width/2, height/2, 0, GL_RGB, GL_UNSIGNED_BYTE, NULL);
    }
    return self;
}


- (void)repaint:(AVFrame *)frame{
    if (!datas[0] || self.width * self.height == 0 || frame->width != self.width || frame->height != self.height) {
        av_frame_free(&frame);
        return;
    }
    
    memcpy(datas[0], frame->data[0], self.width * self.height);
    memcpy(datas[1], frame->data[1], self.width * self.height / 4);
    memcpy(datas[2], frame->data[2], self.width * self.height / 4);
    
}

//把program(着色器处理一下)，bind link等操作
- (void)initializelGL{
    self.program = [[ShaderProgram alloc] initWithShaderName:@"shader"];
    
    [self.program addVertexAttribute:GLKVertexAttribPosition named:@"vertexIn"];
    [self.program addVertexAttribute:GLKVertexAttribTexCoord0 named:@"textureIn"];
    
    [self.program linkProgram];

    static const GLfloat ver[] = {
        //x y z                纹理
        -1.0f, -1.0f, 0.0f,    0.0f, 1.0f,
         1.0f, -1.0f, 0.0f,    1.0f, 1.0f,
        -1.0f,  1.0f, 0.0f,    0.0f, 0.0f,
         1.0f,  1.0f, 0.0f,    1.0f, 0.0f
    };
    
    /*static const GLfloat tex[] = {
        0.0f, 1.0f,
        1.0f, 1.0f,
        0.0f, 0.0f,
        1.0f, 0.0f
    };*/

    GLuint buffer;
    glGenBuffers(1, &buffer);
    glBindBuffer(GL_ARRAY_BUFFER, buffer);
    glBufferData(GL_ARRAY_BUFFER, sizeof(ver), ver, GL_STATIC_DRAW);

    glVertexAttribPointer(GLKVertexAttribPosition, 3, GL_FLOAT, GL_FALSE, 5 * sizeof(GL_FLOAT), (void *)0);
    glEnableVertexAttribArray(GLKVertexAttribPosition);
    
    glVertexAttribPointer(GLKVertexAttribTexCoord0, 2, GL_FLOAT, GL_FALSE, 5 * sizeof(GL_FLOAT), (void *)NULL + 3);
    glEnableVertexAttribArray(GLKVertexAttribTexCoord0);

    
    unis[0] = [self.program uniformIndex:@"tex_y"];
    unis[1] = [self.program uniformIndex:@"tex_u"];
    unis[2] = [self.program uniformIndex:@"tex_v"];
}

- (void)paintGL{
    glActiveTexture(GL_TEXTURE0);
    glBindTexture(GL_TEXTURE_2D, texs[0]);
    /**
     * glTexSubImage2D 修改图像函数,因为修改一个纹理比重新创建一个纹理开销小的多
     * 对于一些视频捕捉程序可以先将视频图像存储在更大的初始图像中，创建一个渲染用的纹理，然后反复调用glTexSubImage2D()函数从图像视频图像区域读取数据到渲染纹理图像中。渲染用的纹理图像只需要创建一次即可
     */
    glTexSubImage2D(GL_TEXTURE_2D, 0, 0, 0, self.width, self.height, GL_RGB, GL_UNSIGNED_BYTE, &datas[0]);
    glUniform1i(unis[0], 0);
    
    glActiveTexture(GL_TEXTURE1);
    glBindTexture(GL_TEXTURE_2D, texs[1]);
    glTexSubImage2D(GL_TEXTURE_2D, 0, 0, 0, self.width/2, self.height/2, GL_RGB, GL_UNSIGNED_BYTE, &datas[1]);
    glUniform1i(unis[1], 1);
    
    glActiveTexture(GL_TEXTURE2);
    glBindTexture(GL_TEXTURE_2D, texs[2]);
    glTexSubImage2D(GL_TEXTURE_2D, 0, 0, 0, self.width/2, self.height/2, GL_RGB, GL_UNSIGNED_BYTE, &datas[2]);
    glUniform1i(unis[2], 2);
    
    
    glDrawArrays(GL_TRIANGLE_STRIP, 0, 4);
    
}




- (void)resizeGLWidth:(int)width height:(int)height{
    
}

@end
