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
    GLfloat datas[3];
}

@property(nonatomic, assign) int width;
@property(nonatomic, assign) int height;

@end

@implementation VideoWidgt

- (instancetype)initWithWidth:(int)width height:(int)height
{
    self = [super init];
    if (self) {
        self.width = width;
        self.height = height;
        
        datas[0] = width * height;
        datas[1] = width * height / 4;
        datas[2] = width * height / 4;
        
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
    
}

//把program(着色器处理一下)，bind link等操作
- (void)initializelGL{
    
}

- (void)paintGL{
    
}

- (void)resizeGLWidth:(int)width height:(int)height{
    
}

@end
