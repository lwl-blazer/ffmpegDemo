//
//  AudioPlayer.h
//  AudioPlayer
//
//  Created by luowailin on 2019/8/5.
//  Copyright © 2019 luowailin. All rights reserved.
//

#import <Foundation/Foundation.h>

NS_ASSUME_NONNULL_BEGIN

@interface AudioPlayer : NSObject

- (instancetype)initWithFilePath:(NSString *)filePath;
- (void)start;
- (void)stop;

@end

NS_ASSUME_NONNULL_END
