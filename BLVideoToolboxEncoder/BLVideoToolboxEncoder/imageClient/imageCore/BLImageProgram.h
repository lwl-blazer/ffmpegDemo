//
//  ELImageProgram.h
//  BLVideoToolboxEncoder
//
//  Created by luowailin on 2019/10/28.
//  Copyright © 2019 luowailin. All rights reserved.
//

#import <Foundation/Foundation.h>
#import <OpenGLES/ES2/gl.h>
#import <OpenGLES/ES2/glext.h>

#define STRINGIZE(x) #x
#define STRINGIZE2(x) STRINGIZE(x)
#define SHADER_STRING(text) @ STRINGIZE2(text)


NS_ASSUME_NONNULL_BEGIN

@interface BLImageProgram : NSObject

- (void)use;

- (BOOL)link;

- (GLuint)uniformIndex:(NSString *)uniformName;

- (GLuint)attributeIndex:(NSString *)attributeName;

- (void)addAttribute:(NSString *)attributeName;

- (instancetype)initWithVertexShaderString:(NSString *)vShaderString
                      fragmentShaderString:(NSString *)fShaderString;

@end

NS_ASSUME_NONNULL_END
