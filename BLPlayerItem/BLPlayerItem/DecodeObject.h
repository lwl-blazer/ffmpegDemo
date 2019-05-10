//
//  DecodeObject.h
//  BLPlayerItem
//
//  Created by luowailin on 2019/5/10.
//  Copyright © 2019 luowailin. All rights reserved.
//  https://github.com/mrzhao12/FFmpegH264DecodeAndOpenGL

//https://github.com/IENT/YUView/releases

#import <Foundation/Foundation.h>

NS_ASSUME_NONNULL_BEGIN

@interface DecodeObject : NSObject

- (void)decodeWithUrl:(NSString *)url;
- (void)decodeWithTwoUrl:(NSString *)url;

@end

NS_ASSUME_NONNULL_END
