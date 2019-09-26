//
//  AVSynchronizer.h
//  Advance-video-play
//
//  Created by luowailin on 2019/9/11.
//  Copyright © 2019 luowailin. All rights reserved.
//

#import <Foundation/Foundation.h>
#import <CoreGraphics/CoreGraphics.h>
#import "VideoDecoder.h"

NS_ASSUME_NONNULL_BEGIN

#define TIMEOUT_DECODE_ERROR 20
#define TIMEOUT_BUFFER 10

extern NSString *const kMIN_BUFFERED_DURATION;
extern NSString *const kMAX_BUFFERED_DURATION;

typedef enum OpenState{
    OPEN_SUCCESS,
    OPEN_FAILED,
    CLIENT_CANCEL,
} OpenState;

@protocol PlayerStateDelegate <NSObject>

- (void)openSucced;

- (void)connectFailed;

- (void)hideLoading;

- (void)showLoading;

- (void)onCompletion;

- (void)buriedPointCallback:(BuriedPoint *)buriedPoint;

- (void)restart;

@end

//音视频同步模块(封装了输入模块、音频队列、视频队列):为外界提供获取音频、视频数据的接口，这两个接口必须保证音视频同步，内部将负责解码线程的运行和暂停的维护
@interface AVSynchronizer : NSObject

@property(nonatomic, weak) id<PlayerStateDelegate>playerStateDelegate;

- (id)initWithPlayerStateDelegate:(id<PlayerStateDelegate>)playerStateDelegate;

- (OpenState)openFile:(NSString *)path
         usingHWCodec:(BOOL)usingHWCodec
           parameters:(NSDictionary *)parameters
                error:(NSError **)perror;

- (OpenState)openFile:(NSString *)path
         usingHWCodec:(BOOL)usingHWCodec
                error:(NSError **)perror;

- (void)closeFile;

- (void)audioCallbackFillData:(SInt16 *)outData
                    numFrames:(UInt32)numFrames
                  numChannels:(UInt32)numChannels;

//获取音频当前对应的正常的视频帧
- (VideoFrame *)getCorrectVideoFrame;

- (void)run;

- (BOOL)isOpenInputSuccess;

- (void)interrupt;

- (BOOL)usingHWCodec;

- (BOOL)isPlayCompleted;

- (NSInteger)getAudioSampleRate;
- (NSInteger)getAudioChannels;
- (CGFloat)getVideoFPS;
- (NSInteger)getVideoFrameHeight;
- (NSInteger)getVideoFrameWidth;
- (BOOL)isValid;
- (CGFloat)getDuration;

@end

NS_ASSUME_NONNULL_END
