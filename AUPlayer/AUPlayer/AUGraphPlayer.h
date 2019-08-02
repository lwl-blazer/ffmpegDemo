//
//  AUGraphPlayer.h
//  AUPlayer
//
//  Created by luowailin on 2019/8/2.
//  Copyright © 2019 luowailin. All rights reserved.
//

#import <Foundation/Foundation.h>

NS_ASSUME_NONNULL_BEGIN

@interface AUGraphPlayer : NSObject

- (instancetype)initWithFilePath:(NSString *)path;
- (BOOL)play;
- (void)stop;
- (void)setInputSource:(BOOL)isAcc;

@end

NS_ASSUME_NONNULL_END
