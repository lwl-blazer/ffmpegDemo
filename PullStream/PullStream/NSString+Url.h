//
//  NSString+Url.h
//  LLYRtmpDemo
//
//  Created by lly on 2017/3/7.
//  Copyright © 2017年 lly. All rights reserved.
//

#import <Foundation/Foundation.h>

//解析推流地址
@interface NSString (Url)

@property(readonly) NSString *scheme;
@property(readonly) NSString *host;
@property(readonly) NSString *app;
@property(readonly) NSString *playPath;
@property(readonly) UInt32    port;

@end
