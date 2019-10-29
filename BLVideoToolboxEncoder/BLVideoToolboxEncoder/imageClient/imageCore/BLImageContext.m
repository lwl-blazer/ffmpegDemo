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
        _contextQueue = dispatch_queue_create("com.esaylive.BLImage.openGLESContextQueue", NULL);
        
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
#if defined(__IPHONE_6_0)
        CVReturn err = CVOpenGLESTextureCacheCreate(kCFAllocatorDefault,
                                                    NULL,
                                                    [self context],
                                                    NULL,
                                                    &_coreVideoTextureCache);
#else
        CVReturn err = CVOpenGLESTextureCacheCreate(kCFAllocatorDefault,
                                                    NULL,
                                                    (__bridge void *)[self context],
                                                    NULL,
                                                    &_coreVideoTextureCache);
#endif

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
