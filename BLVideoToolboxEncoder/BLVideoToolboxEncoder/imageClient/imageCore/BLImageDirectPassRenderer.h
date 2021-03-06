//
//  BLImageDirectPassRenderer.h
//  BLVideoToolboxEncoder
//
//  Created by luowailin on 2019/10/28.
//  Copyright © 2019 luowailin. All rights reserved.
//

#import <Foundation/Foundation.h>

NS_ASSUME_NONNULL_BEGIN

@interface BLImageDirectPassRenderer : NSObject

- (BOOL)prepareRender;

- (void)renderWithTextureId:(int)inputTex
                      width:(int)width
                     height:(int)height
                aspectRatio:(float)aspectRatio;

@end

NS_ASSUME_NONNULL_END
