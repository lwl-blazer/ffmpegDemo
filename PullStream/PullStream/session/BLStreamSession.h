//
//  BLStreamSession.h
//  PullStream
//
//  Created by luowailin on 2019/5/21.
//  Copyright © 2019 luowailin. All rights reserved.
//

#import <Foundation/Foundation.h>

NS_ASSUME_NONNULL_BEGIN
typedef NSStreamEvent BLStreamStatus;

@class BLStreamSession;
@protocol BLStreamSessionDelegate <NSObject>

- (void)streamSession:(BLStreamSession *)session
      didChangeStatus:(BLStreamStatus)streamStatus;

@end

//主要封装了Stream
@interface BLStreamSession : NSObject

@property(nonatomic, weak) id<BLStreamSessionDelegate>delegate;

@property(nonatomic, assign) BLStreamStatus streamStatus;

- (void)connectToServer:(NSString *)host port:(UInt32)port;

- (void)disConnect;

- (NSData *)readData;

- (NSInteger)writeData:(NSData *)data;

@end

NS_ASSUME_NONNULL_END
