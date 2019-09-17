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

@interface VideoPlayerViewController : UIViewController

@property(nonatomic, strong) AVSynchronizer *synchronizer;
@property(nonatomic, strong) NSString *videoFilePath;
@property(nonatomic, assign) BOOL usingHWCodec;
@property(nonatomic, weak) id<PlayerStateDelegate> playerStateDelegate;

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

- (void)play;
- (void)pause;
- (void)stop;
- (void)restart;
- (BOOL)isPlaying;

- (UIImage *)movieSnapshot;

- (VideoOutput *)createVideoOutputInstance;
- (VideoOutput *)getVideoOutputInstance;

@end

NS_ASSUME_NONNULL_END
