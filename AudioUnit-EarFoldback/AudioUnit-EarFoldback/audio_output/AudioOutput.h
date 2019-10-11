//
//  AudioOutput.h
//  AudioUnit-EarFoldback
//
//  Created by luowailin on 2019/10/11.
//  Copyright © 2019 luowailin. All rights reserved.
//

#import <Foundation/Foundation.h>

NS_ASSUME_NONNULL_BEGIN

@interface AudioOutput : NSObject

- (BOOL)start;
- (void)stop;
- (void)changeVolume:(int)volume;

@end

NS_ASSUME_NONNULL_END
