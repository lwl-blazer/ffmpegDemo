//
//  PlayView.m
//  BLPlayerItem
//
//  Created by luowailin on 2019/4/19.
//  Copyright © 2019 luowailin. All rights reserved.
//

#import "PlayView.h"

@interface PlayView ()

@property(nonatomic, strong) EAGLContext *context;
@property(nonatomic, strong) GLKBaseEffect *effect;

@end


@implementation PlayView

- (void)awakeFromNib{
    [super awakeFromNib];
    [self setupGL];
}

- (instancetype)initWithFrame:(CGRect)frame
{
    self = [super initWithFrame:frame];
    if (self) {
        [self setupGL];
    }
    return self;
}

- (void)setupGL{
    self.context = [[EAGLContext alloc] initWithAPI:kEAGLRenderingAPIOpenGLES3];
    
    if (!self.context) {
        NSLog(@"Failed to create ES context");
    }
    
    self.context = self.context;
    self.drawableDepthFormat = GLKViewDrawableDepthFormat24;
    
    [EAGLContext setCurrentContext:self.context];
}


+ (Class)layerClass{
    return [CAEAGLLayer class];
}

- (void)dealloc{
    if (self.context == [EAGLContext currentContext]) {
        [EAGLContext setCurrentContext:nil];
        self.context = nil;
    }
}

@end
