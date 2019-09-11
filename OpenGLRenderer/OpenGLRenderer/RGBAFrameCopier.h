//
//  RGBAFrameCopier.h
//  OpenGLRenderer
//
//  Created by luowailin on 2019/9/3.
//  Copyright © 2019 luowailin. All rights reserved.
//

#import <Foundation/Foundation.h>
#import <OpenGLES/ES2/gl.h>
#import <OpenGLES/ES2/glext.h>

NS_ASSUME_NONNULL_BEGIN

static inline BOOL validateProgram(GLuint prog){
    
    GLint status;
    glValidateProgram(prog);
    
#ifdef DEBUG
    
    GLint logLength;
    glGetProgramiv(prog, GL_INFO_LOG_LENGTH, &logLength);
    if (logLength > 0) {
        GLchar *log = (GLchar *)malloc(logLength);
        glGetProgramInfoLog(prog, logLength, &logLength, log);
        NSLog(@"Program validate log:\n%s", log);
        free(log);
    }
#endif
    
    glGetProgramiv(prog, GL_VALIDATE_STATUS, &status);
    if (status == GL_FALSE) {
        NSLog(@"Failed to validate program %d", prog);
        return NO;
    }
    
    return YES;
}


static inline GLuint compileShader(GLenum type, NSString *shaderString){
    GLint status;
    const GLchar *sources = (GLchar *)shaderString.UTF8String;
    
    GLuint shader = glCreateShader(type);
    if (shader == 0 || shader == GL_INVALID_ENUM) {
        NSLog(@"Failed to create shader %d", type);
        return 0;
    }
    
    //把编写的着色器程序加载到着色器句柄所关联的内存中
    glShaderSource(shader, 1, &sources, NULL);
    //编译该shader
    glCompileShader(shader);
    
#ifdef DEBUG
    //验证该shader是否编译成功
    GLint logLength;
    glGetShaderiv(shader, GL_INFO_LOG_LENGTH, &logLength);
    if (logLength > 0) {
        GLchar *log = (GLchar *)malloc(logLength);
        glGetShaderInfoLog(shader, logLength, &logLength, log);
        NSLog(@"Shader compile log:\n%s", log);
        free(log);
    }
#endif
    //打印信息帮助我们调试shader launage的错误信息
    glGetShaderiv(shader, GL_COMPILE_STATUS, &status);
    if (status == GL_FALSE) {
        glDeleteShader(shader);
        NSLog(@"Failed to complie shader:\n");
        return 0;
    }
    return shader;
}


@interface RGBAFrameCopier : NSObject

- (BOOL)prepareRender:(NSInteger)textureWidth height:(NSInteger)textureHeight;
- (void)renderFrame:(uint8_t *)rgbaFrame;
- (void)releaseRender;

@end

NS_ASSUME_NONNULL_END
