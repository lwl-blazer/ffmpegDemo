//
//  BLFrame.h
//  PullStream
//
//  Created by luowailin on 2019/5/21.
//  Copyright © 2019 luowailin. All rights reserved.
//

#import <Foundation/Foundation.h>

NS_ASSUME_NONNULL_BEGIN

@interface BLFrame : NSObject

@property(nonatomic, strong) NSData *data; //数据

@property(nonatomic, assign) int timestamp; //时间戳
@property(nonatomic, assign) int msgLength; //长度
@property(nonatomic, assign) int msgTypeId; //typeId

@property(nonatomic, assign) int msgStreamId; //msgStreamId

@property(nonatomic, assign) BOOL isKeyframe;  //关键帧

@end

NS_ASSUME_NONNULL_END
