//
//  ELImageContext.m
//  BLVideoToolboxEncoder
//
//  Created by luowailin on 2019/10/28.
//  Copyright © 2019 luowailin. All rights reserved.
//

#import "BLImageContext.h"

@interface BLImageContext ()
{
    EAGLSharegroup *_sharegroup;
}
@property(readwrite, strong, nonatomic) EAGLContext *context;
@property(readwrite, nonatomic) CVOpenGLESTextureCacheRef coreVideoTextureCache;

@end

@implementation BLImageContext

static void *openGLESContextQueueKey;

- (instancetype)init{
    self = [super init];
    if (self) {
        openGLESContextQueueKey = &openGLESContextQueueKey;
        _contextQueue = dispatch_queue_create("com.esaylive.BLImage.openGLESContextQueue", NULL); //NULL 就是DISPATCH_CURRENT_QUEUE_LABEL
 
        //OS_OBJECT_USE_OBJC 代表SDK6.0以下
#if OS_OBJECT_USE_OBJC
        dispatch_queue_set_specific(_contextQueue,
                                    openGLESContextQueueKey,
                                    (__bridge void *)self,
                                    NULL);
#endif
    }
    return self;
}

+ (void *)contextKey{
    return openGLESContextQueueKey;
}

//单例处理图像的Context
+ (BLImageContext *)shareImageProcessingContext{

    static BLImageContext *sharedImageProcessingContext = nil;
    static dispatch_once_t onceToken;
    dispatch_once(&onceToken, ^{
        sharedImageProcessingContext = [[BLImageContext alloc] init];
    });
    return sharedImageProcessingContext;
}

+ (dispatch_queue_t)shareContextQueue{
    return [[self shareImageProcessingContext] contextQueue];
}

+ (void)useImageProcessingContext{
    [[BLImageContext shareImageProcessingContext] useAsCurrentContext];
}

- (void)useAsCurrentContext{
    EAGLContext *imageProcessingContext = [self context];
    if ([EAGLContext currentContext] != imageProcessingContext) {
        [EAGLContext setCurrentContext:imageProcessingContext];
    }
}

/** EAGLSharegroup
 * 上下文保持OpenGL ES状态，但它并不直接管理OpenGL ES对象。相反，OpenGL ES对象由EAGLSharegroup对象创建和维护。每个上下文都包含一个EAGLSharegroup对象。
 *
 * 当两个或多个上下文引用相同的共享组时，共享组的优点变得明显，当多个上下文连接到公共共享组时，由任何上下文创建的OpenGL ES对象可用用于所有上下文；如果绑定到与创建它相同的上下文上的相同对象标识符，则引用同一个OpenGL ES对象。
 *
 * 移动设备上的资源通常很少；在多个上下文中创建相同内容的多个副本是浪费的。共享共享资源可以更好地利用设备上可用的图形资源
 *
 * 一个共享组是一个不透明的对象；它没有您的应用可以调用的方法或属性。使用sharegroup对象的上下文保持强有力的参考
 *
 * 在两种情况下，共享组最有用:
 * 1.当上下文之间共享的大部分资源是不变的
 * 2.希望应用程序能在除渲染器的主线程之外的线程上创建新的OpenGL ES对象。在这种情况下，第二个上下文在单独的线程上运行，专门用于获取数据和创建资源。在资源被加载之后，第一个上下文可以绑定到对象并立即使用它。GLKTextureLoader类使用此模式提供异步纹理加载
 *
 * 当共享组由多个上下文共享时，应用程序有责任管理OpenGL ES对象的状态更改.规则:
 *  1.如果对象未被修改，您的应用程序可以同时访问跨多个上下文的对象。
 *  2.当对象被发送到上下文的命令修改时，对象不得在任何其他上下文中被读取或修改。
 *  3.修改对象后，所有上下文都必须重新绑定对象以查看更改。如果上下文在绑定它之前引用它，则对象的内容是未定义的。
 *
 * 下面是您的应用程序应该更新OpenGL ES对象的步骤:
 *  1.在可能使用对象的每个上下文上调用glFlush;
 *  2.在要修改对象的上下文中，调用一个或多个OpenGL ES函数来更改对象
 *  3.在接收到状态修改命令的上下文中调用glFlush
 *  4.在其他上下文中，重新绑定对象标识符。
 */
- (void)useSharegroup:(EAGLSharegroup *)sharegroup{
    _sharegroup = sharegroup;
}

- (EAGLContext *)createContext{
    EAGLContext *context = [[EAGLContext alloc] initWithAPI:kEAGLRenderingAPIOpenGLES2
                                                 sharegroup:_sharegroup];
    return context;
}

#pragma mark - Manage fast texture upload
+ (BOOL)supportFastTextureUpload{
#if TARGET_IPHONE_SIMULATOR
    return NO;
#else
    //clang diagnostic 就是处掉警告
#pragma clang diagnostic push
#pragma clang diagnostic ignored "-Wtautological-pointer-compare"
    return (CVOpenGLESTextureCacheCreate != NULL);
#pragma clang diagnostic pop
#endif
}

#pragma mark - Accessors
- (EAGLContext *)context{
    if (_context == nil) {
        _context = [self createContext];
        [EAGLContext setCurrentContext:_context];
        glDisable(GL_DEPTH_TEST);
    }
    return _context;
}

- (CVOpenGLESTextureCacheRef)coreVideoTextureCache{
    if (_coreVideoTextureCache == NULL) {
        CVReturn err = CVOpenGLESTextureCacheCreate(kCFAllocatorDefault,
                                                    NULL,
                                                    [self context],
                                                    NULL,
                                                    &_coreVideoTextureCache);
        if (err) {
            NSAssert(NO, @"Error at CVOpenGLESTextureCacheCreate %d", err);
        }
    }
    return _coreVideoTextureCache;
}

- (void)dealloc{
    if (_coreVideoTextureCache) {
        CFRelease(_coreVideoTextureCache);
        NSLog(@"Realese _coreVideoTextureCache...");
    }
}

@end
