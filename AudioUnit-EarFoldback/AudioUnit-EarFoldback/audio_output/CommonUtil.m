//
//  CommonUtil.m
//  AdvanceTest_01
//
//  Created by luowailin on 2019/7/31.
//  Copyright © 2019 luowailin. All rights reserved.
//

#import "CommonUtil.h"

@implementation CommonUtil

+ (NSString *)bundlePath:(NSString *)fileName type:(NSString *)type{
    return [[NSBundle mainBundle] pathForResource:fileName ofType:type];
}

+ (NSString *)documentsPath:(NSString *)fileName{
    
    NSArray *paths = NSSearchPathForDirectoriesInDomains(NSDocumentDirectory, NSUserDomainMask, YES);
    return [[paths objectAtIndex:0] stringByAppendingPathComponent:fileName];
}

@end
