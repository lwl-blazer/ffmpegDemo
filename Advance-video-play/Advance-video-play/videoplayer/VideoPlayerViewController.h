//
//  VideoPlayerViewController.h
//  Advance-video-play
//
//  Created by luowailin on 2019/9/11.
//  Copyright © 2019 luowailin. All rights reserved.
//

#import <UIKit/UIKit.h>
#import "AVSynchronizer.h"
#import "VideoOutput.h"
#import "AudioOutput.h"

NS_ASSUME_NONNULL_BEGIN
//调度器----包括了音视频同步模块、音频输出模块、视频输出模块
@interface VideoPlayerViewController : UIViewController

@property(nonatomic, strong) AVSynchronizer *synchronizer;
@property(nonatomic, strong) NSString *videoFilePath;
@property(nonatomic, assign) BOOL usingHWCodec;
@property(nonatomic, weak) id<PlayerStateDelegate> playerStateDelegate;

//初始化方法
+ (instancetype)viewControllerWithContentPath:(NSString *)path
                                 contentFrame:(CGRect)frame
                                 usingHWCodec:(BOOL)usingHWCodec
                          playerStateDelegate:(id)playerStateDelegate
                                   parameters:(NSDictionary *)parameters;

+ (instancetype)viewControllerWithContentPath:(NSString *)path
                                 contentFrame:(CGRect)frame
                                 usingHWCodec:(BOOL)usingHWCodec
                          playerStateDelegate:(id<PlayerStateDelegate>)playerStateDelegate
                                   parameters:(NSDictionary *)parameters
                  outputEAGLContextShareGroup:(EAGLSharegroup *)sharegroup;

- (instancetype)initWithContentPath:(NSString *)path
                       contentFrame:(CGRect)frame
                       usingHWCodec:(BOOL)usingHWCodec
                playerStateDelegate:(id)playerStateDelegate
                         parameters:(NSDictionary *)parameters;

- (instancetype)initWithContentPath:(NSString *)path
                       contentFrame:(CGRect)frame
                       usingHWCodec:(BOOL)usingHWCodec
                playerStateDelegate:(id)playerStateDelegate
                         parameters:(NSDictionary *)parameters
        outputEAGLContextShareGroup:(EAGLSharegroup *)sharegroup;

//播放
- (void)play;
//暂停
- (void)pause;
//停止
- (void)stop;
//继续播放
- (void)restart;


- (BOOL)isPlaying;

- (UIImage *)movieSnapshot;

- (VideoOutput *)createVideoOutputInstance;
- (VideoOutput *)getVideoOutputInstance;

@end

NS_ASSUME_NONNULL_END
