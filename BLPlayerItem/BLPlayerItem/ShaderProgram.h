//
//  ShaderProgram.h
//  BLPlayerItem
//
//  Created by luowailin on 2019/4/19.
//  Copyright © 2019 luowailin. All rights reserved.
//

#import <GLKit/GLKit.h>

NS_ASSUME_NONNULL_BEGIN

@interface ShaderProgram : NSObject

- (instancetype)initWithShaderName:(NSString *)name;

//编译program之前 link program之后 进行调用
- (void)addVertexAttribute:(GLKVertexAttrib)attribute
                     named:(NSString *)name;

- (GLuint)uniformIndex:(NSString *)uniform;

- (BOOL)linkProgram;

- (void)useProgram;

@end

NS_ASSUME_NONNULL_END
