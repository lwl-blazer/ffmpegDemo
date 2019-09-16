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
