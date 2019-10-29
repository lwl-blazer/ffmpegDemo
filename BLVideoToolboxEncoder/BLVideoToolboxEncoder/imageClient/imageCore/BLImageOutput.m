//
//  ELImageOutput.m
//  BLVideoToolboxEncoder
//
//  Created by luowailin on 2019/10/28.
//  Copyright © 2019 luowailin. All rights reserved.
//

#import "BLImageOutput.h"

void runSyncOnVideoProcessingQueue(void (^block)(void)){
    dispatch_queue_t videoProcessingQueue = [BLImageContext shareContextQueue];
    
#if !OS_OBJECT_USE_OBJC
#pragma clang diagnostic push
#pragma clang diagnostic ignored "-Wdeprecated-declarations"
    if (dispatch_get_current_queue() == videoProcessingQueue)
#pragma clang diagnostic pop
#else
        if (dispatch_get_specific([BLImageContext contextKey]))
#endif
        {
            block();
        } else {
            dispatch_sync(videoProcessingQueue, block);
        }
}

void runAsyncOnVideoProcessingQueue(void (^block)(void)){
    dispatch_queue_t videoProcessingQueue = [BLImageContext shareContextQueue];

#if !OS_OBJECT_USE_OBJC
#pragma clang diagnostic push
#pragma clang diagnostic ignored "-Wdeprecated-declarations"
    if (dispatch_get_current_queue() == videoProcessingQueue)
#pragma clang diagnostic pop
#else
        if (dispatch_get_specific([BLImageContext contextKey]))
#endif
        {
            block();
        } else {
            dispatch_async(videoProcessingQueue, block);
        }
}


void runSyncOnContextQueue(BLImageContext *context, void (^block)(void)){
    dispatch_queue_t videoProcessingQueue = [context contextQueue];
#if !OS_OBJECT_USE_OBJC
#pragma clang diagnostic push
#pragma clang diagnostic ignored "-Wdeprecated-declarations"
    if (dispatch_get_current_queue() == videoProcessingQueue)
#pragma clang diagnostic pop
#else
        if (dispatch_get_specific([BLImageContext contextKey]))
#endif
        {
            block();
        } else {
            dispatch_sync(videoProcessingQueue, block);
        }
}

void runAsyncOnContextQueue(BLImageContext *context, void (^block)(void)){
    dispatch_queue_t videoProcessingQueue = [context contextQueue];
#if !OS_OBJECT_USE_OBJC
#pragma clang diagnostic push
#pragma clang diagnostic ignored "-Wdeprecated-declarations"
    if (dispatch_get_current_queue() == videoProcessingQueue)
#pragma clang diagnostic pop
#else
        if (dispatch_get_specific([BLImageContext contextKey]))
#endif
        {
            block();
        } else {
            dispatch_async(videoProcessingQueue, block);
        }
}


@implementation BLImageOutput

- (instancetype)init{
    self = [super init];
    if (self) {
        targets = [NSMutableArray array];
    }
    return self;
}

- (void)dealloc{
    [self removeAllTargets];
}

- (BLImageTextureFrame *)framebufferForOutput{
    return outputTexture;
}

- (void)setInputTextureForTarget:(id<BLImageInput>)target{
    [target setInputTexture:[self framebufferForOutput]];
}

- (NSArray *)targets{
    return [NSArray arrayWithArray:targets];
}

- (void)addTarget:(id<BLImageInput>)newTarget{
    [targets addObject:newTarget];
}

- (void)removeTarget:(id<BLImageInput>)targetToRemove{
    if (![targets containsObject:targetToRemove]) {
        return;
    }

    runSyncOnVideoProcessingQueue(^{
        [self->targets removeObject:targetToRemove];
    });
}

- (void)removeAllTargets{
    runSyncOnVideoProcessingQueue(^{
        [self->targets removeAllObjects];
    });
}

@end
