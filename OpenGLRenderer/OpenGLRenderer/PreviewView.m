//
//  PreviewView.m
//  OpenGLRenderer
//
//  Created by luowailin on 2019/9/3.
//  Copyright © 2019 luowailin. All rights reserved.
//

#import "PreviewView.h"
#import "RGBAFrameCopier.h"
#include "rgba_frame.hpp"
#import "png_decoder.h"

@interface PreviewView ()

@property(nonatomic, assign) BOOL readyToRender;
@property(nonatomic, assign) BOOL shouldEnableOpenGL;
@property(nonatomic, strong) NSLock *shouldEnableOpenGLLock;

@end

@implementation PreviewView
{
    dispatch_queue_t _contextQueue;
    EAGLContext *_context;
    GLuint _displayFramebuffer;
    GLuint _renderBuffer;
    GLint _backingWidth;
    GLint _backingHeight;
    
    BOOL _stopping;
    
    RGBAFrameCopier *_frameCopier;
    RGBAFrame *_frame;
}

+(Class)layerClass{
    return [CAEAGLLayer class];
}

- (instancetype)initWithFrame:(CGRect)frame filePath:(nonnull NSString *)filePath
{
    self = [super initWithFrame:frame];
    if (self) {
        
        self.shouldEnableOpenGLLock = [NSLock new];
        [self.shouldEnableOpenGLLock lock];
        self.shouldEnableOpenGL = [UIApplication sharedApplication].applicationState == UIApplicationStateActive;
        [self.shouldEnableOpenGLLock unlock];
        
        [[NSNotificationCenter defaultCenter] addObserver:self selector:@selector(applicationWillResignActive:) name:UIApplicationWillResignActiveNotification object:nil];
        
        
    }
    return self;
}

@end
