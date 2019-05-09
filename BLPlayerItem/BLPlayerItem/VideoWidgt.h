//
//  VideoWidgt.h
//  BLPlayerItem
//
//  Created by luowailin on 2019/4/19.
//  Copyright © 2019 luowailin. All rights reserved.
//

#import <Foundation/Foundation.h>
#import <libavcodec/avcodec.h>

NS_ASSUME_NONNULL_BEGIN

@interface VideoWidgt : NSObject

- (instancetype)initWithWidth:(int)width height:(int)height;
- (void)repaint:(AVFrame *)frame;
- (void)initializelGL;
- (void)paintGL;
- (void)resizeGLWidth:(int)width height:(int)height;

@end

NS_ASSUME_NONNULL_END
