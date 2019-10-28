//
//  ELImageOutput.h
//  BLVideoToolboxEncoder
//
//  Created by luowailin on 2019/10/28.
//  Copyright © 2019 luowailin. All rights reserved.
//

#import <Foundation/Foundation.h>
#import "BLImageTextureFrame.h"
#import "BLImageContext.h"

NS_ASSUME_NONNULL_BEGIN

void runSyncOnVideoProcessingQueue(void (^block)(void));
void runAsyncOnVideoProcessingQueue(void (^block)(void));
void runSyncOnContextQueue(BLImageContext *context, void (^block)(void));
void runAsyncOnContextQueue(BLImageContext *context, void (^block)(void));

@interface BLImageOutput : NSObject
{
    BLImageTextureFrame *outputTexture;
    NSMutableArray *targets;
}

- (void)setInputTextureForTarget:(id<BLImageInput>)target;

- (BLImageTextureFrame *)framebufferForOutput;

- (NSArray *)targets;

- (void)addTarget:(id<BLImageInput>)newTarget;

- (void)removeTarget:(id<BLImageInput>)targetToRemove;

- (void)removeAllTargets;

@end

NS_ASSUME_NONNULL_END
