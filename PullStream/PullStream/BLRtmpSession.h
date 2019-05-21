//
//  BLRtmpSession.h
//  PullStream
//
//  Created by luowailin on 2019/5/21.
//  Copyright © 2019 luowailin. All rights reserved.
//

#import <Foundation/Foundation.h>
#import "BLFrame.h"


NS_ASSUME_NONNULL_BEGIN

typedef NS_ENUM(NSUInteger, LLYRtmpSessionStatus){
    
    LLYRtmpSessionStatusNone              = 0,
    LLYRtmpSessionStatusConnected         = 1,
    
    LLYRtmpSessionStatusHandshake0        = 2,
    LLYRtmpSessionStatusHandshake1        = 3,
    LLYRtmpSessionStatusHandshake2        = 4,
    LLYRtmpSessionStatusHandshakeComplete = 5,
    
    LLYRtmpSessionStatusFCPublish         = 6,
    LLYRtmpSessionStatusReady             = 7,
    LLYRtmpSessionStatusSessionStarted    = 8,
    
    LLYRtmpSessionStatusError             = 9,
    LLYRtmpSessionStatusNotConnected      = 10,
    
    LLYRtmpSessionStatusSessionStartPlay = 11
};

@class BLRtmpSession;
@protocol BLRtmpSessionDelegate <NSObject>

- (void)rtmpSession:(BLRtmpSession *)rtmpSession didChangeStatus:(LLYRtmpSessionStatus)rtmpstatus;
- (void)rtmpSession:(BLRtmpSession *)rtmpSession receiveVideoData:(uint8_t *)data length:(int)length;

@end


@class BLRtmpConfig;
@interface BLRtmpSession : NSObject

@property(nonatomic, copy) NSString *url;
@property(nonatomic, strong) BLRtmpConfig *config;

@property(nonatomic, weak) id<BLRtmpSessionDelegate>delegate;


- (void)connect;
- (void)disConnect;
- (void)sendBuffer:(BLFrame *)frame;


@end

NS_ASSUME_NONNULL_END
