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
        
        [[NSNotificationCenter defaultCenter] addObserver:self
                                                 selector:@selector(applicationWillResignActive:)
                                                     name:UIApplicationWillResignActiveNotification
                                                   object:nil];
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
        
        _renderOperationQueue = [[NSOperationQueue alloc] init];
        _renderOperationQueue.maxConcurrentOperationCount = 1; //同时执行的最大数量
        _renderOperationQueue.name = @"com.changba.video_player.videoRenderQueue";
        
        __weak VideoOutput *weakSelf = self;
        [_renderOperationQueue addOperationWithBlock:^{   //添加到队列中，自动异步执行
            if (!weakSelf) {
                return;
            }
            __strong VideoOutput *strongSelf = weakSelf;
            if (shareGroup) {
                strongSelf->_context = [[EAGLContext alloc] initWithAPI:kEAGLRenderingAPIOpenGLES2 sharegroup:shareGroup];
            } else {
                strongSelf->_context = [[EAGLContext alloc] initWithAPI:kEAGLRenderingAPIOpenGLES2];
            }
            
            if (!strongSelf->_context || ![EAGLContext setCurrentContext:strongSelf->_context]) {
                NSLog(@"Setup EAGLContext Failed...");
            }
            
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


static int count = 0;
static const NSInteger kMaxOperationQueueCount = 3;

- (void)presentVideoFrame:(VideoFrame *)frame{
    if (_stopping) {
        NSLog(@"Prevent A InValid Renderer >>>>>>>>>");
        return;
    }
    
    @synchronized (self.renderOperationQueue) {
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
