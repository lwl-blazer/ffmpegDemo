//
//  BaseEffectFilter.m
//  Advance-video-play
//
//  Created by luowailin on 2019/9/11.
//  Copyright © 2019 luowailin. All rights reserved.
//

#import "BaseEffectFilter.h"

@implementation BaseEffectFilter

- (BOOL)prepareRender:(NSInteger)frameWidth height:(NSInteger)frameHeight{
    return NO;
}

- (void)renderWithWidth:(NSInteger)width height:(NSInteger)height position:(float)position{
    
}

- (BOOL)buildProgram:(NSString *)vertexShader fragmentShader:(NSString *)fragmentShader{
    BOOL result = NO;
    
    GLuint vertShader = 0, fragShader = 0;
    filterProgram = glCreateProgram();
    vertShader = complieShader(GL_VERTEX_SHADER, vertexShader);
    if (!vertexShader) {
        goto exit;
    }
    
    fragShader = complieShader(GL_FRAGMENT_SHADER, fragmentShader);
    if (!fragShader) {
        goto exit;
    }
    
    glAttachShader(filterProgram, vertShader);
    glAttachShader(filterProgram, fragShader);
    
    glLinkProgram(filterProgram);
    
    filterPositionAttribute = glGetAttribLocation(filterProgram, "position");
    filterTextureCoordinateAttribute = glGetAttribLocation(filterProgram, "texcoord");
    filterInputTextureUniform = glGetUniformLocation(filterProgram, "inputImageTexture");
    
    GLint status;
    glGetProgramiv(filterProgram, GL_LINK_STATUS, &status);
    if (status == GL_FALSE) {
        NSLog(@"Faile to link program %d", filterProgram);
        goto exit;
    }
    
    result = validateProgram(filterProgram);
    
exit:
    
    if (vertexShader) {
        glDeleteShader(vertShader);
    }
    
    if (fragShader) {
        glDeleteShader(fragShader);
    }
    
    if (result) {
        NSLog(@"OK Setup GL program");
    } else {
        glDeleteProgram(filterProgram);
        filterProgram = 0;
    }
    
    return result;
}

- (void)releaseRender{
    if (filterProgram) {
        glDeleteProgram(filterProgram);
        filterProgram = 0;
    }
}

- (void)setInputTexture:(GLint)textureId{
    _inputTexId = textureId;
}

- (GLint)outputTextureID{
    return -1;
}


@end
