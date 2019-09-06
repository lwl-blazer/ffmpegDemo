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


static 


@interface RGBAFrameCopier : NSObject

- (BOOL)prepareRender:(NSInteger)textureWidth height:(NSInteger)textureHeight;
- (void)renderFrame:(uint8_t *)rgbaFrame;
- (void)releaseRender;

@end

NS_ASSUME_NONNULL_END
