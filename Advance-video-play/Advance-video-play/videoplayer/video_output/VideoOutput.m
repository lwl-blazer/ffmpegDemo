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
            //上面的两步就已经建立好了EAGL和OpenGL ES的连接， 第3步是另一端的连接(EAGL和Layer(设备的屏幕))，
            
            //3.创建FrameBuffer和RenderBuffer
            if (![strongSelf createDisplayFramebuffer]) { //
                NSLog(@"create Dispaly Framebuffer failed...");
            }
            //当全部连接完成以后，绘制完一帧之后，调用 presentRenderbuffer: 这样就可以将绘制的结果显示到屏幕上了。
            
            //当创建完FrameBuffer和RenderBuffer,后期的处理都是在帧缓冲上进行的
            //纹理的一系列处理----利用GLSL
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
        if (operationCount > kMaxOperationQueueCount) { //是否需要清除一些前面的Operation 只保留kMaxOperationQueueCount
            [_renderOperationQueue.operations enumerateObjectsUsingBlock:^(__kindof NSOperation * _Nonnull obj, NSUInteger idx, BOOL * _Nonnull stop) {
                if (idx < operationCount - kMaxOperationQueueCount) {
                    [obj cancel];
                } else {
                    *stop = YES;
                }
            }];
        }
        
        //添加
        __weak VideoOutput *weakSelf = self;
        [_renderOperationQueue addOperationWithBlock:^{
            if (!weakSelf) {
                return;
            }
            
            __strong VideoOutput *strongSelf = weakSelf;
            [strongSelf.shouldEnableOpenGLLock lock];
            if (!strongSelf.readyToRender || !strongSelf.shouldEnableOpenGL) {
                /**
                 * glFinish 和 glFlush
                 * 提交给OpenGL的绘图指令并不会马上发送给图形硬件执行，而是放到一个缓冲区里，等缓冲区满了之后再将这些指令发送给图形硬件执行，所以指令较少或较简单时是无法填满缓冲区的，这些指令自然不能马上执行以达到所需效果。因此每次写完绘图代码，需要让其立即完成效果时，开发者都需要在代码后添加 glFinish() 或 glFlush()
                 * 作用:
                 *    将缓冲区中指令(无论是否为满)立刻发送给图形硬件执行
                 * 区别：
                 * glFlush(): 发送完后立即返回
                 * glFinish(): 但是要等待图形硬件执行完成之后才返回这些指令
                 */
                glFinish();
                [strongSelf.shouldEnableOpenGLLock unlock];
                return;
            }
            
            [strongSelf.shouldEnableOpenGLLock unlock];
            
            count ++;
            int frameWidth = (int)[frame width];
            int frameHeight = (int)[frame height];
            
            //step1:准备渲染
            [EAGLContext setCurrentContext:strongSelf->_context];
            
            //step2: 渲染FRAMEBUFFER ----视频帧
            [strongSelf->_videoFrameCopier renderWithTexId:frame];
            [strongSelf->_filter renderWithWidth:frameWidth height:frameHeight position:frame.position];
            
            //step3:渲染手机屏幕大小的FRAMEBUFFER
            glBindFramebuffer(GL_FRAMEBUFFER, strongSelf->_displayFrameBuffer);
            [strongSelf->_directPassRenderer renderWithWidth:strongSelf->_backingWidth
                                                      height:strongSelf->_backingHeight
                                                    position:frame.position];
            
            //step4:渲染缓冲的数据写入
            glBindRenderbuffer(GL_RENDERBUFFER, strongSelf->_renderBuffer);
            [strongSelf->_context presentRenderbuffer:GL_RENDERBUFFER];
        }];
    }
}

//创建FrameBuffer和RenderBuffer
- (BOOL)createDisplayFramebuffer{
    BOOL ret = YES;
    
    //1.创建帧缓冲区、绘制缓冲区
    glGenFramebuffers(1, &_displayFrameBuffer);
    glGenRenderbuffers(1, &_renderBuffer);
    
    //2.绑定帧缓冲区和绘制缓冲区到渲染管线
    glBindFramebuffer(GL_FRAMEBUFFER, _displayFrameBuffer);
    glBindRenderbuffer(GL_RENDERBUFFER, _renderBuffer);
    
    //3.为绘制缓冲区分配存储区，此处将CAEAGLLayer的绘制存储区作为绘制缓冲区的存储区
    [self->_context renderbufferStorage:GL_RENDERBUFFER fromDrawable:self.eaglLayer];   //相当于Open GL中的glRenderbufferStorage
   
    //4.获取绘制缓冲区的像素宽度、高度
    glGetRenderbufferParameteriv(GL_RENDERBUFFER, GL_RENDERBUFFER_WIDTH, &_backingWidth);
    glGetRenderbufferParameteriv(GL_RENDERBUFFER, GL_RENDERBUFFER_HEIGHT, &_backingHeight);
    
    //5.将绘制缓冲区绑定到帧缓冲区
    glFramebufferRenderbuffer(GL_FRAMEBUFFER, GL_COLOR_ATTACHMENT0, GL_RENDERBUFFER, _renderBuffer);
    
    //6.检查FrameBuffer的status
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
/** 渲染缓冲对象 GL_RENDERBUFFER
 *
 * 渲染缓冲对象是一个真正的缓冲，即一系列的字节、整数、像素等，渲染缓冲对象附加的好处是，它会将数据存储为OpenGL原生的渲染格式，它是为离屏渲染到帧缓冲优化过的。
 * 渲染缓冲对象直接将所有的渲染数据储存到它的缓冲中，不会做任何针对纹理格式的转换，让它变为一个更快的可写储存介质。然而，渲染缓冲对象通常都是只写的，所以你不能读取它们（比如使用纹理访问）。当然你仍然还是能够使用glReadPixels来读取它，这会从当前绑定的帧缓冲，而不是附件本身，中返回特定区域的像素。
 *
 * 因为它的数据已经是原生的格式了，当写入或者复制它的数据到其它缓冲中时是非常快的。所以，交换缓冲这样的操作在使用渲染缓冲对象时会非常快。我们在每个渲染迭代最后使用的glfwSwapBuffers(在iOS的中presentRenderbuffer底层实现就是调用此函数)，也可以通过渲染缓冲对象实现：只需要写入一个渲染缓冲图像，并在最后交换到另外一个渲染缓冲就可以了。渲染缓冲对象对这种操作非常完美。
 */

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
