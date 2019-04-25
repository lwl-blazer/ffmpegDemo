//
//  ShaderProgram.m
//  BLPlayerItem
//
//  Created by luowailin on 2019/4/19.
//  Copyright © 2019 luowailin. All rights reserved.
//

#import "ShaderProgram.h"
enum {
    ATTRIB_VERTEX,
    ATTRIB_TEXCOORDS,
    NUM_ATTRIBUTES
};

@interface ShaderProgram ()

@property(nonatomic, assign) GLuint shaderProgram;
@property(nonatomic, assign) GLuint vertShader;
@property(nonatomic, assign) GLuint fragShader;

@property(nonatomic, strong) NSMutableArray *attributes;
@property(nonatomic, strong) NSMutableArray *uniforms;

@end


@implementation ShaderProgram

- (instancetype)initWithShaderName:(NSString *)name{
    self = [super init];
    if (self) {
        _shaderProgram = glCreateProgram();
        
        NSString *vertShaderPath = [self pathForName:name type:@"vsh"];
        if (![self compileShader:&_vertShader type:GL_VERTEX_SHADER file:vertShaderPath]) {
            NSLog(@"Failed to compile vertex shader");
            self = nil;
            return self;
        }
        
        
        NSString *fragShaderPath = [self pathForName:name type:@"fsh"];
        if (![self compileShader:&_fragShader type:GL_FRAGMENT_SHADER file:fragShaderPath]) {
            NSLog(@"Failed to compile fragment shader");
            self = nil;
            return self;
        }
        
        
        glAttachShader(_shaderProgram, _vertShader);
        glAttachShader(_shaderProgram, _fragShader);
    }
    return self;
}

- (void)addVertexAttribute:(GLKVertexAttrib)attribute
                     named:(NSString *)name{
    glBindAttribLocation(_shaderProgram, attribute, [name UTF8String]);
}

- (GLuint)uniformIndex:(NSString *)uniform{
    return glGetUniformLocation(_shaderProgram, [uniform UTF8String]);
}


- (BOOL)linkProgram{
    
    GLint status;
    glLinkProgram(_shaderProgram);
    
    glGetProgramiv(_shaderProgram, GL_LINK_STATUS, &status);
    if (status == 0) {
        return NO;
    }
    
    //release shader
    if (_vertShader) {
        glDetachShader(_shaderProgram, _vertShader);
        glDeleteShader(_vertShader);
    }
    
    if (_fragShader) {
        glDetachShader(_shaderProgram, _fragShader);
        glDeleteShader(_fragShader);
    }
    
    return YES;
}

- (void)useProgram{
    glUseProgram(_shaderProgram);
}

- (NSString *)pathForName:(NSString *)name type:(NSString *)type{
    return [[NSBundle mainBundle] pathForResource:name ofType:type];
}

- (BOOL)compileShader:(GLuint *)shader type:(GLenum)type file:(NSString *)file{
    
    GLint status;
    const GLchar *source;
    
    source = (GLchar *)[[NSString stringWithContentsOfFile:file encoding:NSUTF8StringEncoding error:nil] UTF8String];
    if (!source) {
        NSLog(@"Failed to load vertex shader");
        return NO;
    }
    
    *shader = glCreateShader(type);
    glCompileShader(*shader);

#if defined(DEBUG)
    GLint logLength;
    glGetShaderiv(*shader, GL_INFO_LOG_LENGTH, &logLength);
    if (logLength > 0) {
        GLchar *log = (GLchar *)malloc(logLength);
        glGetShaderInfoLog(*shader, logLength, &logLength, log);
        NSLog(@"Shader compile log:\n%s", log);
        free(log);
    }
#endif

    glGetShaderiv(*shader, GL_COMPILE_STATUS, &status);
    if (status == 0) {
        glDeleteShader(*shader);
        return NO;
    }

    return YES;
}

@end
