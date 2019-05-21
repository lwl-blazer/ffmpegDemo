//
//  BLRtmpConfig.h
//  PullStream
//
//  Created by luowailin on 2019/5/21.
//  Copyright © 2019 luowailin. All rights reserved.
//

#import <Foundation/Foundation.h>

NS_ASSUME_NONNULL_BEGIN

@interface BLRtmpConfig : NSObject

@property(nonatomic, copy) NSString *url;

@property(nonatomic, assign) int32_t width;
@property(nonatomic, assign) int32_t height;
@property(nonatomic, assign) double frameDuration;
@property(nonatomic, assign) int32_t videoBitrate;

@property(nonatomic, assign) double audioSampleRate;
@property(nonatomic, assign) BOOL stereo; //立体声

@end

NS_ASSUME_NONNULL_END
