//
//  CommonUtil.h
//  AdvanceTest_01
//
//  Created by luowailin on 2019/7/31.
//  Copyright © 2019 luowailin. All rights reserved.
//

#import <Foundation/Foundation.h>

NS_ASSUME_NONNULL_BEGIN

@interface CommonUtil : NSObject

+ (NSString *)bundlePath:(NSString *)fileName type:(NSString *)type;
+ (NSString *)documentsPath:(NSString *)fileName;

@end

NS_ASSUME_NONNULL_END
