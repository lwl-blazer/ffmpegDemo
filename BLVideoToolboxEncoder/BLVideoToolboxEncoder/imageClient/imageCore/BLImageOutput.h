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

/**
 * 凡是需要向后级节点输出纹理纹理对象的节点都是Output类型
 * 其中Camera,Filter节点需要继承自该类
 * 描述:
     凡是继承自它的节点都可以向自己的后级节点输出目标纹理对象，
 */
@interface BLImageOutput : NSObject
{
    //目标纹理对象
    BLImageTextureFrame *outputTexture;
    //后级节点列表
    NSMutableArray *targets;
    /**
     * 为什么是Array 因为后级节点有可能包含了多个目标对象，像Filter节点，既要输出给BLImageView又要输出给VideoEncoder
     * 而这个targets里面的对象又是什么呢:
     *    就是协议BLImageInput类型的对象，这是因为Output节点的后级节点肯定是一个Input的节点，
     */
}

- (void)setInputTextureForTarget:(id<BLImageInput>)target;

- (BLImageTextureFrame *)framebufferForOutput;

- (NSArray *)targets;

- (void)addTarget:(id<BLImageInput>)newTarget;

- (void)removeTarget:(id<BLImageInput>)targetToRemove;

- (void)removeAllTargets;

@end

NS_ASSUME_NONNULL_END
