//
//  VideoWidgt.m
//  BLPlayerItem
//
//  Created by luowailin on 2019/4/19.
//  Copyright © 2019 luowailin. All rights reserved.
//

#import "VideoWidgt.h"
#import <GLKit/GLKit.h>

@interface VideoWidgt ()
{
    GLuint unis[3];
    GLuint texs[3];
    
    unsigned char *datas[3];
}

@property(nonatomic, assign) int width;
@property(nonatomic, assign) int height;

@end

@implementation VideoWidgt

- (instancetype)initWithWidth:(int)width height:(int)height
{
    self = [super init];
    if (self) {
        self.width = width;
        self.height = height;
        
       
        
        
    }
    return self;
}

@end
