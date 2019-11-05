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
/**
* BLImageProgram  用于把OpenGL的Program的构建、查找属性、使用等这些操作
*
* 每个节点都会有一个该类的引用实例
*/
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
