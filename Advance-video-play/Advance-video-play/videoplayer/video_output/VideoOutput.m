//
//  VideoOutput.m
//  Advance-video-play
//
//  Created by luowailin on 2019/9/11.
//  Copyright © 2019 luowailin. All rights reserved.
//

#import "VideoOutput.h"

#import <OpenGLES/ES2/gl.h>
#import <OpenGLES/ES2/glext.h>
#import "YUVFrameCopier.h"
#import "YUVFrameFastCopier.h"
#import "ContrastEnhancerFilter.h"
#import "DirectPassRenderer.h"

/**
 * 本类的职责:
 * 1.作为UIView的子类，必须提供layer绘制，我们这里是靠RenderBuffer和我们的CAEAGLLayer进行绑定来绘制的
 * 2.需要构建OpenGL的环境，EAGLContext与运行Thread
 * 3.调用第三方Filter与Renderer去把YUV420P的数据处理以及渲染到RenderBuffer上
 * 4.由于这里涉及到OpenGL操作，要增加NotificationCenter的监听，在applicationWillResignActive停止绘制
 *
 */

@interface VideoOutput ()

@property(nonatomic, assign) BOOL readyToRender;
@property(nonatomic, assign) BOOL shouldEnableOpenGL;
@property(nonatomic, strong) NSLock *shouldEnableOpenGLLock;
@property(nonatomic, strong) NSOperationQueue *renderOperationQueue;

@property(nonatomic, weak) CAEAGLLayer *eaglLayer;

@end

@implementation VideoOutput
{
    EAGLContext *_context;
    GLuint _displayFrameBuffer;
    GLuint _renderBuffer;
    GLint _backingWidth;
    GLint _backingHeight;
    
    BOOL _stopping;
    
    YUVFrameCopier *_videoFrameCopier;
    BaseEffectFilter *_filter;
    DirectPassRenderer *_directPassRenderer;
}

+ (Class)layerClass{
    return [CAEAGLLayer class];
}

- (instancetype)initWithFrame:(CGRect)frame
                 textureWidth:(NSInteger)textureWidth
                textureHeight:(NSInteger)textureHeight
                 usingHWCodec:(BOOL)usingHWCodec{
    return [self initWithFrame:frame
                  textureWidth:textureWidth
                 textureHeight:textureHeight
                  usingHWCodec:usingHWCodec
                    shareGroup:nil];
}

- (instancetype)initWithFrame:(CGRect)frame
                 textureWidth:(NSInteger)textureWidth
                textureHeight:(NSInteger)textureHeight
                 usingHWCodec:(BOOL)usingHWCodec
                   shareGroup:(EAGLSharegroup *)shareGroup{
    self = [super initWithFrame:frame];
    if (self) {
        _shouldEnableOpenGLLock = [NSLock new];
        [_shouldEnableOpenGLLock lock];
        _shouldEnableOpenGL = [UIApplication sharedApplication].applicationState == UIApplicationStateActive;
        [_shouldEnableOpenGLLock unlock];
        
        //如果App进入后台之后，就不能再进行OpenGL ES的渲染操作 在下面的两个监听中，维护一个BOOL变量， 在线程的绘制过程中应该先判定这个变量是否为YES,是YES进行绘制，否则不进行绘制
        //WillResignActiveNotification 即当App从活跃状态变为非活跃状态的时候，或者即将进入后台的时候，
        [[NSNotificationCenter defaultCenter] addObserver:self
                                                 selector:@selector(applicationWillResignActive:)
                                                     name:UIApplicationWillResignActiveNotification
                                                   object:nil];
        //DidBecomeActiveNotification 即当App从后台到前台
        [[NSNotificationCenter defaultCenter] addObserver:self
                                                 selector:@selector(applicationDidBecomeActive:)
                                                     name:UIApplicationDidBecomeActiveNotification
                                                   object:nil];
    
        self.eaglLayer = (CAEAGLLayer *)self.layer;
        self.eaglLayer.opaque = YES;
        self.eaglLayer.drawableProperties = [NSDictionary dictionaryWithObjectsAndKeys:[NSNumber numberWithBool:NO],
                                        kEAGLDrawablePropertyRetainedBacking,
                                        kEAGLColorFormatRGBA8,
                                        kEAGLDrawablePropertyColorFormat, nil];
        
        /**
         * 采用NSOperationQueue来实现，也就是把OpenGL ES的所有操作都封装在NSOperationQueue中来完成，
         *
         * 为什么要采用这种线程模型，而不是GCD
         * 由于某些低端设备(iPod,iPhone4)，在一次OpenGL的绘制中耗费的时间可能会比较多，如果使用的是GCD的线程模型，那么会导致DispatchQueue里面的Operation超过定义的阈值(Threshold)时，清空最久的Operation,只保留最新的绘制操作，这样才能完成正常的播放
         *
         * GCD 和 NSOperation的区别
         * 1.GCD是C语言， NSOperation底层由GCD封装
         * 2.NSOperationQueue支持KVO， 可以监测operation是否正在执行(isExecuted) 是否结束(isFinished) 是否取消(isCanceld)
         * 3.GCD只支持FIFO的队列，而NSOperationQueue可以调整队列的执行顺序(可以通过调整权重)
         *
         * 使用NSOperationQueue的情况:
         *   各个操作之间有依赖关系、操作需要取消暂停、并发管理、控制操作之间优先级、限制同时能执行的线程数量、让线程在某时刻停止/继续
         *
         * 使用GCD的情况:
         *    一般的需求很简单的多线程操作，用GCD都可以，简单高效
         */
        _renderOperationQueue = [[NSOperationQueue alloc] init];
        _renderOperationQueue.maxConcurrentOperationCount = 1; //同时执行的最大数量
        _renderOperationQueue.name = @"com.changba.video_player.videoRenderQueue";
        
        __weak VideoOutput *weakSelf = self;
        //将OpenGL ES的上下文构建以及OpenGL ES的渲染Program的构建作为一个Block直接加入到该Queue中。
        [_renderOperationQueue addOperationWithBlock:^{   //添加到队列中，自动异步执行
            if (!weakSelf) {
                return;
            }
            __strong VideoOutput *strongSelf = weakSelf;
            //1.创建EAGLContext上下文
            if (shareGroup) {
                strongSelf->_context = [[EAGLContext alloc] initWithAPI:kEAGLRenderingAPIOpenGLES2 sharegroup:shareGroup];
            } else {
                strongSelf->_context = [[EAGLContext alloc] initWithAPI:kEAGLRenderingAPIOpenGLES2];
            }
            //2.为该NSOperationQueue线程绑定OpenGL ES上下文
            if (!strongSelf->_context || ![EAGLContext setCurrentContext:strongSelf->_context]) {
                NSLog(@"Setup EAGLContext Failed...");
            }
            
            //3.创建FrameBuffer和RenderBuffer
            if (![strongSelf createDisplayFramebuffer]) {
                NSLog(@"create Dispaly Framebuffer failed...");
            }
            
            [strongSelf createCopierInstance:usingHWCodec];
            if (![strongSelf->_videoFrameCopier prepareRender:textureWidth height:textureHeight]) {
                NSLog(@"_videoFrameFastCopier prepareRender failed...");
            }
            
            strongSelf->_filter = [self createImageProcessFilterInstance];
            if (![strongSelf->_filter prepareRender:textureWidth height:textureHeight]) {
                NSLog(@"_contrastEnhancerFilter prepareRender failed...");
            }
            
            [strongSelf->_filter setInputTexture:[strongSelf->_videoFrameCopier outputTextureID]];
            
            strongSelf->_directPassRenderer = [[DirectPassRenderer alloc] init];
            if (![strongSelf->_directPassRenderer prepareRender:textureWidth height:textureHeight]) {
                NSLog(@"_directPassRenderer prepareRender failed...");
            }
            
            [strongSelf ->_directPassRenderer setInputTexture:[strongSelf->_filter outputTextureID]];
            strongSelf.readyToRender = YES;
        }];
        
    }
    return self;
}

- (BaseEffectFilter *)createImageProcessFilterInstance{
    return [[ContrastEnhancerFilter alloc] init];
}

- (BaseEffectFilter *)getImageProcessFilterInstance{
    return _filter;
}

- (void)createCopierInstance:(BOOL)usingHWCodec{
    if (usingHWCodec) {
        _videoFrameCopier = [[YUVFrameFastCopier alloc] init];
    } else {
        _videoFrameCopier = [[YUVFrameCopier alloc] init];
    }
}

//最核心代码-----渲染
static int count = 0;
static const NSInteger kMaxOperationQueueCount = 3;

- (void)presentVideoFrame:(VideoFrame *)frame{
    if (_stopping) {
        NSLog(@"Prevent A InValid Renderer >>>>>>>>>");
        return;
    }
    
    @synchronized (self.renderOperationQueue) {
        //这段代码是运用NSOperation最重要的原因.....
        NSInteger operationCount = _renderOperationQueue.operationCount;
        if (operationCount > kMaxOperationQueueCount) {
            [_renderOperationQueue.operations enumerateObjectsUsingBlock:^(__kindof NSOperation * _Nonnull obj, NSUInteger idx, BOOL * _Nonnull stop) {
                if (idx < operationCount - kMaxOperationQueueCount) {
                    [obj cancel];
                } else {
                    *stop = YES;
                }
            }];
        }
        
        __weak VideoOutput *weakSelf = self;
        [_renderOperationQueue addOperationWithBlock:^{
            if (!weakSelf) {
                return;
            }
            
            __strong VideoOutput *strongSelf = weakSelf;
            [strongSelf.shouldEnableOpenGLLock lock];
            if (!strongSelf.readyToRender || !strongSelf.shouldEnableOpenGL) {
                glFinish();
                [strongSelf.shouldEnableOpenGLLock unlock];
                return;
            }
            
            [strongSelf.shouldEnableOpenGLLock unlock];
            
            count ++;
            int frameWidth = (int)[frame width];
            int frameHeight = (int)[frame height];
            
            [EAGLContext setCurrentContext:strongSelf->_context];
            
            [strongSelf->_videoFrameCopier renderWithTexId:frame];
            [strongSelf->_filter renderWithWidth:frameWidth height:frameHeight position:frame.position];
            
            glBindFramebuffer(GL_FRAMEBUFFER, strongSelf->_displayFrameBuffer);
            [strongSelf->_directPassRenderer renderWithWidth:strongSelf->_backingWidth
                                                      height:strongSelf->_backingHeight position:frame.position];
            glBindRenderbuffer(GL_RENDERBUFFER, strongSelf->_renderBuffer);
            [strongSelf->_context presentRenderbuffer:GL_RENDERBUFFER];
        }];
    }
}


- (BOOL)createDisplayFramebuffer{
    BOOL ret = YES;
    
    glGenFramebuffers(1, &_displayFrameBuffer);
    glGenRenderbuffers(1, &_renderBuffer);
    glBindFramebuffer(GL_FRAMEBUFFER, _displayFrameBuffer);
    glBindRenderbuffer(GL_RENDERBUFFER, _renderBuffer);
    [self->_context renderbufferStorage:GL_RENDERBUFFER fromDrawable:self.eaglLayer];
   
    glGetRenderbufferParameteriv(GL_RENDERBUFFER, GL_RENDERBUFFER_WIDTH, &_backingWidth);
    glGetRenderbufferParameteriv(GL_RENDERBUFFER, GL_RENDERBUFFER_HEIGHT, &_backingHeight);
    
    glFramebufferRenderbuffer(GL_FRAMEBUFFER, GL_COLOR_ATTACHMENT0, GL_RENDERBUFFER, _renderBuffer);
    
    GLenum status = glCheckFramebufferStatus(GL_FRAMEBUFFER);
    if (status != GL_FRAMEBUFFER_COMPLETE) {
        NSLog(@"failed to make complete framebuffer object %x", status);
        return NO;
    }
    
    GLenum glError = glGetError();
    if (GL_NO_ERROR != glError) {
        NSLog(@"failed to setup GL %x", glError);
        return NO;
    }
    
    return ret;
}

- (void)destroy{
    _stopping = true;
    __weak VideoOutput *weakSelf = self;
    [self.renderOperationQueue addOperationWithBlock:^{
        if (!weakSelf) {
            return;
        }
        
        __strong VideoOutput *strongSelf = weakSelf;
        if (strongSelf->_videoFrameCopier) {
            [strongSelf->_videoFrameCopier releaseRender];
        }
        
        if (strongSelf->_filter) {
            [strongSelf->_filter releaseRender];
        }
        
        if (strongSelf->_directPassRenderer) {
            [strongSelf->_directPassRenderer releaseRender];
        }
        
        if (strongSelf->_displayFrameBuffer) {
            glDeleteFramebuffers(1, &strongSelf->_displayFrameBuffer);
            strongSelf->_displayFrameBuffer = 0;
        }
        
        if (strongSelf->_renderBuffer) {
            glDeleteRenderbuffers(1, &strongSelf->_renderBuffer);
            strongSelf->_renderBuffer = 0;
        }
        
        if ([EAGLContext currentContext] == strongSelf->_context) {
            [EAGLContext setCurrentContext:nil];
        }
    }];
}

- (void)dealloc{
    [[NSNotificationCenter defaultCenter] removeObserver:self];
    
    if (_renderOperationQueue) {
        [_renderOperationQueue cancelAllOperations];
        _renderOperationQueue = nil;
    }
    
    _videoFrameCopier = nil;
    _filter = nil;
    _directPassRenderer = nil;
    
    _context = nil;
    NSLog(@"Render Frame Count is %d", count);
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
