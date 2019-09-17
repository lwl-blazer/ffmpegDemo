//
//  YUVFrameFastCopier.h
//  Advance-video-play
//
//  Created by luowailin on 2019/9/11.
//  Copyright © 2019 luowailin. All rights reserved.
//

#import "YUVFrameCopier.h"
#import "VideoDecoder.h"

NS_ASSUME_NONNULL_BEGIN

@interface YUVFrameFastCopier : YUVFrameCopier

- (void)renderWithTexId:(VideoFrame *)videoFrame;

@end

NS_ASSUME_NONNULL_END
