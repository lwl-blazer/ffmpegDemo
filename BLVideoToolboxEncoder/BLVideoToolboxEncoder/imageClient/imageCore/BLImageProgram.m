//
//  ELImageProgram.m
//  BLVideoToolboxEncoder
//
//  Created by luowailin on 2019/10/28.
//  Copyright © 2019 luowailin. All rights reserved.
//

#import "BLImageProgram.h"

@implementation BLImageProgram{
    NSMutableArray *attributes;
    NSMutableArray *uniforms;
    GLuint program;
    GLuint vertShader;
    GLuint fragShader;
}


- (void)use{
    glUseProgram(program);
}

- (instancetype)initWithVertexShaderString:(NSString *)vShaderString
                      fragmentShaderString:(NSString *)fShaderString{
    
    self = [super init];
    if (self) {
        attributes = [NSMutableArray array];
        uniforms = [NSMutableArray array];
        
        program = glCreateProgram();
        
        if (![self compileShader:&vertShader
                            type:GL_VERTEX_SHADER
                          string:vShaderString]) {
            NSLog(@"Failed to compile vertex shader");
        }
        
        if (![self compileShader:&fragShader
                            type:GL_FRAGMENT_SHADER
                          string:fShaderString]) {
            NSLog(@"Failed to compile fragment shader");
        }
        
        glAttachShader(program, vertShader);
        glAttachShader(program, fragShader);
    }
    return self;
}

- (BOOL)compileShader:(GLuint *)shader
                 type:(GLenum)type
               string:(NSString *)shaderString{
    GLint status;
    const GLchar *source;
    
    source = (GLchar *)[shaderString UTF8String];
    if (!source) {
        NSLog(@"Failed to load vertex shader");
        return NO;
    }
    
    *shader = glCreateShader(type);
    glShaderSource(*shader,
                   1,
                   &source,
                   NULL);
    glCompileShader(*shader);
    glGetShaderiv(*shader,
                  GL_COMPILE_STATUS,
                  &status);
    if (status != GL_TRUE) {
        GLint logLength;
        glGetShaderiv(*shader,
                      GL_INFO_LOG_LENGTH,
                      &logLength);
        if (logLength > 0) {
            GLchar *log = (GLchar *)malloc(logLength);
            glGetShaderInfoLog(*shader, logLength, &logLength, log);
            NSLog(@"compile shader log is :%@", [NSString stringWithFormat:@"%s", log]);
        }
        return NO;
    }
    return YES;
}

- (void)addAttribute:(NSString *)attributeName{
    if (![attributes containsObject:attributeName]) {
        [attributes addObject:attributeName];
        glBindAttribLocation(program,
                             (GLuint)[attributes indexOfObject:attributeName],
                             [attributeName UTF8String]);
    }
}

- (BOOL)link{
    GLint status;
    
    glLinkProgram(program);
    
    glGetProgramiv(program, GL_LINK_STATUS, &status);
    
    if (status == GL_FALSE) {
        return NO;
    }
    
    if (vertShader) {
        glDeleteShader(vertShader);
        vertShader = 0;
    }
    
    if (fragShader) {
        glDeleteShader(fragShader);
        fragShader = 0;
    }
    return YES;
}

- (GLuint)attributeIndex:(NSString *)attributeName{
    return (GLuint)[attributes indexOfObject:attributeName];
}

- (GLuint)uniformIndex:(NSString *)uniformName{
    return glGetUniformLocation(program, [uniformName UTF8String]);
}



@end
