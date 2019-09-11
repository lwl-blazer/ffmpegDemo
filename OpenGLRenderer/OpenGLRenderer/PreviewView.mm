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

+ (Class)layerClass{
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
        
        [[NSNotificationCenter defaultCenter] addObserver:self selector:@selector(applicationWillResignActive:) name:UIApplicationWillResignActiveNotification object:nil];   //UIApplicationWillResignActiveNotification  当APP不再活动或失去焦点时候
        
        [[NSNotificationCenter defaultCenter] addObserver:self selector:@selector(applicationDidBecomeActive:) name:UIApplicationDidBecomeActiveNotification object:nil];  //UIApplicationDidBecomeActiveNotification 当APP开始活动
        
        CAEAGLLayer *eaglLayer = (CAEAGLLayer *)self.layer;
        eaglLayer.opaque = YES;
        eaglLayer.drawableProperties = [NSDictionary dictionaryWithObjectsAndKeys:
                                        [NSNumber numberWithBool:FALSE],
                                        kEAGLDrawablePropertyRetainedBacking,
                                        kEAGLColorFormatRGBA8,
                                        kEAGLDrawablePropertyColorFormat, nil];
        
        //构造EAGLContext与RenderBuffer并且绑定到Layer上，必须为每一个线程绑定OpenGL ES上下文
        _contextQueue = dispatch_queue_create("com.changba.video_player.videoRenderQueue", NULL); //NULL 表示的是DISPATCH_QUEUE_SERIAL 串行队列
        __weak typeof(self) WEAKSELF = self;
        dispatch_sync(_contextQueue, ^{
            WEAKSELF.context = [self buildEAGLContext];
            //setCurrentContext 建立EAGL与OpenGL ES的连接，
            if (!WEAKSELF.context || ![EAGLContext setCurrentContext:WEAKSELF.context]) {
                NSLog(@"Setup EAGLContext Failed...");
            }
            if (![WEAKSELF createDisplayFrameBuffer]) {
                NSLog(@"create Display Framebuffer failed...");
            }
            
            //获取图片数据
            self->_frame = [self getRGBAFrame:filePath];
            
            WEAKSELF.frameCopier = [[RGBAFrameCopier alloc] init];
            //初始化program 和 初始化纹理
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
            if (!self.readyToRender || !self.shouldEnableOpenGL) { //是否处于可绘制的状态
                glFinish();   //glFinish() 将OpenGL命令队列中的命令发送给显卡并清空命令队列，显示完成这些命令(也就是画完)后返回 glFlush() 将OpenGL命令队列中的命令发送给显卡并清空命令队列，发送完立即返回
                [self.shouldEnableOpenGLLock unlock];
                return;
            }
            [self.shouldEnableOpenGLLock unlock];
            
            //step1
            [EAGLContext setCurrentContext:WEAKSELF.context];
            
            //step2: 在帧缓存中进行绘制
            glBindFramebuffer(GL_FRAMEBUFFER, WEAKSELF.displayFramebuffer);
            glViewport(0, 0, WEAKSELF.backingWidth, WEAKSELF.backingHeight);
            [WEAKSELF.frameCopier renderFrame:self->_frame->pixels];
            
            //step3: 发送给context进行渲染
            glBindRenderbuffer(GL_RENDERBUFFER, WEAKSELF.renderBuffer);
            [WEAKSELF.context presentRenderbuffer:GL_RENDERBUFFER];   //绘制  显示缓存的内容
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
    
    //整张图片需要多少内存空间来存储
    int expectLength = data.width *data.height * 4;
    uint8_t *pixels = new uint8_t[expectLength];
    memset(pixels, 0, sizeof(uint8_t) * expectLength);
    
    //copy操作
    int pixelsLength = MIN(expectLength, data.size);
    memcpy(pixels, (byte *)data.data, pixelsLength);
    frame->pixels = pixels;
    
    //销毁操作
    decoder->releaseRawImageData(&data);
    decoder->closeFile();
    delete decoder;
    
    return frame;
}

- (EAGLContext *)buildEAGLContext{
    return [[EAGLContext alloc] initWithAPI:kEAGLRenderingAPIOpenGLES2];
}

//创建帧缓存区 和 创建渲染缓存区对象并附加在帧缓存中
- (BOOL)createDisplayFrameBuffer{
    BOOL ret = TRUE;
    //创建
    glGenRenderbuffers(1, &_displayFramebuffer);
    glGenRenderbuffers(1, &_renderBuffer);
    glBindFramebuffer(GL_FRAMEBUFFER, self.displayFramebuffer);
    glBindRenderbuffer(GL_RENDERBUFFER, self.renderBuffer);
    
    //重点1:把可绘制对象绑定到渲染缓存区中  相当于OpenGL中的glRenderbufferStorage();   为绘制缓冲区分配存储区，此处将CAEAGLLayer的绘制存储区作为绘制缓冲区的存储区
    [self.context renderbufferStorage:GL_RENDERBUFFER fromDrawable:(CAEAGLLayer *)self.layer];
    
    glGetRenderbufferParameteriv(GL_RENDERBUFFER, GL_RENDERBUFFER_WIDTH, &_backingWidth);
    glGetRenderbufferParameteriv(GL_RENDERBUFFER, GL_RENDERBUFFER_HEIGHT, &_backingHeight);
    
    //重点2:附加这个渲染缓冲对象   将绘制缓冲区绑定到帧缓冲区
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
    
    /** 帧缓存
     * 纹理附件 和 渲染缓存对象附件 怎么选择
     * 渲染缓冲对象能为你的帧缓冲对象提供一些优化，但知道什么时候使用渲染缓冲对象，什么时候使用纹理很重要的。通常的规则是:
     如果你不需要从一个缓冲中采样数据，那么对这个缓冲使用渲染缓冲对象会是明智的选择。如果你需要从缓冲中采样颜色或深度值等数据，那么你应该选择纹理附件，性能方面它不会产生非常大的影响
     */
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
