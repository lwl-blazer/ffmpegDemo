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
@property(nonatomic, strong) EAGLContext *context;
@property(nonatomic, strong) RGBAFrameCopier *frameCopier;

@property(nonatomic, assign) GLuint displayFramebuffer;
@property(nonatomic, assign) GLuint renderBuffer;
@property(nonatomic, assign) GLint backingWidth;
@property(nonatomic, assign) GLint backingHeight;
@property(nonatomic, assign) BOOL stopping;

@end

@implementation PreviewView
{
    dispatch_queue_t _contextQueue;
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
        
        [[NSNotificationCenter defaultCenter] addObserver:self selector:@selector(applicationDidBecomeActive:) name:UIApplicationDidBecomeActiveNotification object:nil];
        
        CAEAGLLayer *eaglLayer = (CAEAGLLayer *)self.layer;
        eaglLayer.opaque = YES;
        eaglLayer.drawableProperties = [NSDictionary dictionaryWithObjectsAndKeys:
                                        [NSNumber numberWithBool:FALSE],
                                        kEAGLDrawablePropertyRetainedBacking,
                                        kEAGLColorFormatRGBA8,
                                        kEAGLDrawablePropertyColorFormat, nil];
        
        _contextQueue = dispatch_queue_create("com.changba.video_player.videoRenderQueue", NULL);
        __weak typeof(self) WEAKSELF = self;
        dispatch_sync(_contextQueue, ^{
            WEAKSELF.context = [self buildEAGLContext];
            if (!WEAKSELF.context || ![EAGLContext setCurrentContext:WEAKSELF.context]) {
                NSLog(@"Setup EAGLContext Failed...");
            }
            if (![WEAKSELF createDisplayFrameBuffer]) {
                NSLog(@"create Display Framebuffer failed...");
            }
            
            self->_frame = [self getRGBAFrame:filePath];
            
            WEAKSELF.frameCopier = [[RGBAFrameCopier alloc] init];
            if (![WEAKSELF.frameCopier prepareRender:self->_frame->width height:self->_frame->height]) {
                NSLog(@"RGBAFrameCopier prepareRender failed...");
            }
            WEAKSELF.readyToRender = YES;
        });
    }
    return self;
}

- (void)render{
    if (_stopping) {
        return;
    }
    
    __weak typeof(self) WEAKSELF = self;
    dispatch_async(_contextQueue, ^{
        if (self->_frame) {
            [self.shouldEnableOpenGLLock lock];
            if (!self.readyToRender || !self.shouldEnableOpenGL) {
                glFinish();
                [self.shouldEnableOpenGLLock unlock];
                return;
            }
    
            [self.shouldEnableOpenGLLock unlock];
            [EAGLContext setCurrentContext:WEAKSELF.context];
            glBindFramebuffer(GL_FRAMEBUFFER, WEAKSELF.displayFramebuffer);
            glViewport(0, WEAKSELF.backingHeight - WEAKSELF.backingWidth - 75, WEAKSELF.backingWidth, WEAKSELF.backingHeight);
            [WEAKSELF.frameCopier renderFrame:self->_frame->pixels];
            glBindRenderbuffer(GL_RENDERBUFFER, WEAKSELF.renderBuffer);
            [WEAKSELF.context presentRenderbuffer:GL_RENDERBUFFER];
        }
    });
}


- (RGBAFrame *)getRGBAFrame:(NSString *)pngFilePath{
    PngPicDecoder *decoder = new PngPicDecoder();
    
    char *pngPath = (char *)[pngFilePath cStringUsingEncoding:NSUTF8StringEncoding];
    
    decoder->openFile(pngPath);
    
    RawImageData data = decoder->getRawImageData();
    RGBAFrame *frame = new RGBAFrame();
    frame->width = data.width;
    frame->height = data.height;
    
    int expectLength = data.width *data.height * 4;
    uint8_t *pixels = new uint8_t[expectLength];
    memset(pixels, 0, sizeof(uint8_t) * expectLength);
    
    int pixelsLength = MIN(expectLength, data.size);
    memcpy(pixels, (byte *)data.data, pixelsLength);
    frame->pixels = pixels;
    decoder->releaseRawImageData(&data);
    decoder->closeFile();
    delete decoder;
    return frame;
}

- (EAGLContext *)buildEAGLContext{
    return [[EAGLContext alloc] initWithAPI:kEAGLRenderingAPIOpenGLES2];
}

- (BOOL)createDisplayFrameBuffer{
    BOOL ret = TRUE;
    glGenRenderbuffers(1, &_displayFramebuffer);
    glGenRenderbuffers(1, &_renderBuffer);
    glBindFramebuffer(GL_FRAMEBUFFER, self.displayFramebuffer);
    glBindRenderbuffer(GL_RENDERBUFFER, self.renderBuffer);
    
    [self.context renderbufferStorage:GL_RENDERBUFFER fromDrawable:(CAEAGLLayer *)self.layer];
    
    glGetRenderbufferParameteriv(GL_RENDERBUFFER, GL_RENDERBUFFER_WIDTH, &_backingWidth);
    glGetRenderbufferParameteriv(GL_RENDERBUFFER, GL_RENDERBUFFER_HEIGHT, &_backingHeight);
    glFramebufferRenderbuffer(GL_FRAMEBUFFER, GL_COLOR_ATTACHMENT0, GL_RENDERBUFFER, _renderBuffer);
    
    GLenum status = glCheckFramebufferStatus(GL_FRAMEBUFFER);
    if (status != GL_FRAMEBUFFER_COMPLETE) {
        NSLog(@"failed to make complete framebuffer object");
        return FALSE;
    }
    
    GLenum glError = glGetError();
    if (GL_NO_ERROR != glError) {
        NSLog(@"failed to setup GL %x", glError);
        return FALSE;
    }
    return ret;
}

- (void)destroy{
    self.stopping = true;
    __weak typeof(self) WEAKSELF = self;
    dispatch_sync(_contextQueue, ^{
        if (self.frameCopier) {
            [WEAKSELF.frameCopier releaseRender];
        }
        
        if (self.displayFramebuffer) {
            glDeleteFramebuffers(1, &self->_displayFramebuffer);
            WEAKSELF.displayFramebuffer = 0;
        }
        
        if (self.renderBuffer) {
            glDeleteRenderbuffers(1, &self->_renderBuffer);
            WEAKSELF.renderBuffer = 0;
        }
        
        if ([EAGLContext currentContext] == WEAKSELF.context) {
            [EAGLContext setCurrentContext:nil];
        }
    });
}

- (void)dealloc{
    [[NSNotificationCenter defaultCenter] removeObserver:self];
    if (_contextQueue) {
        _contextQueue = nil;
    }
    
    self.frameCopier = nil;
    self.context = nil;
}

- (void)applicationWillResignActive:(NSNotification *)notification{
    [self.shouldEnableOpenGLLock lock];
    self.shouldEnableOpenGL = NO;
    [self.shouldEnableOpenGLLock unlock];
}

- (void)applicationDidBecomeActive:(NSNotification *)notification{
    [self.shouldEnableOpenGLLock lock];
    self.shouldEnableOpenGL = YES;
    [self.shouldEnableOpenGLLock unlock];
}


@end
