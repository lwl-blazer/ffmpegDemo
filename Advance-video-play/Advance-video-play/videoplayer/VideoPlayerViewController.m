//
//  VideoPlayerViewController.m
//  Advance-video-play
//
//  Created by luowailin on 2019/9/11.
//  Copyright © 2019 luowailin. All rights reserved.
//

#import "VideoPlayerViewController.h"

@interface VideoPlayerViewController ()<FillDataDelegate>{
    VideoOutput *_videoOutput;
    AudioOutput *_audioOutput;
    
    NSDictionary *_parameters;
    CGRect _contentFrame;
    
    BOOL _isPlaying;
    EAGLSharegroup *_shareGroup;
}

@property(nonatomic, assign) CGRect bounds;

@end

@implementation VideoPlayerViewController

+ (instancetype)viewControllerWithContentPath:(NSString *)path
                                 contentFrame:(CGRect)frame
                                 usingHWCodec:(BOOL)usingHWCodec
                          playerStateDelegate:(id)playerStateDelegate
                                   parameters:(NSDictionary *)parameters{
    return [[VideoPlayerViewController alloc] initWithContentPath:path
                                                     contentFrame:frame
                                                     usingHWCodec:usingHWCodec
                                              playerStateDelegate:playerStateDelegate
                                                       parameters:parameters];
}

+ (instancetype)viewControllerWithContentPath:(NSString *)path
                                 contentFrame:(CGRect)frame
                                 usingHWCodec:(BOOL)usingHWCodec
                          playerStateDelegate:(id<PlayerStateDelegate>)playerStateDelegate
                                   parameters:(NSDictionary *)parameters
                  outputEAGLContextShareGroup:(EAGLSharegroup *)sharegroup{
    return [[VideoPlayerViewController alloc] initWithContentPath:path
                                                     contentFrame:frame
                                                     usingHWCodec:usingHWCodec
                                              playerStateDelegate:playerStateDelegate
                                                       parameters:parameters
                                      outputEAGLContextShareGroup:sharegroup];
}

- (instancetype)initWithContentPath:(NSString *)path
                       contentFrame:(CGRect)frame
                       usingHWCodec:(BOOL)usingHWCodec
                playerStateDelegate:(id)playerStateDelegate
                         parameters:(NSDictionary *)parameters{
    return [self initWithContentPath:path
                        contentFrame:frame
                        usingHWCodec:usingHWCodec
                 playerStateDelegate:playerStateDelegate
                          parameters:parameters
         outputEAGLContextShareGroup:nil];
}

- (instancetype)initWithContentPath:(NSString *)path
                       contentFrame:(CGRect)frame
                       usingHWCodec:(BOOL)usingHWCodec
                playerStateDelegate:(id)playerStateDelegate
                         parameters:(NSDictionary *)parameters
        outputEAGLContextShareGroup:(EAGLSharegroup  *)sharegroup{
    NSAssert(path.length > 0, @"empty path");
    self = [super initWithNibName:nil bundle:nil];
    if (self) {
        _contentFrame = frame;
        _usingHWCodec = usingHWCodec;
        _parameters = parameters;
        _videoFilePath = path;
        _playerStateDelegate = playerStateDelegate;
        _shareGroup = sharegroup;
        NSLog(@"Enter VideoPlayerViewController init, url: %@, h/w enable: %@", _videoFilePath, @(usingHWCodec));
        [self start];
    }
    return self;
}

- (void)viewDidLoad {
    [super viewDidLoad];
    self.view = [[UIView alloc] initWithFrame:_contentFrame];
    self.view.backgroundColor = [UIColor clearColor];
}



- (void)start{
    //AVSynchronizer 音视频同步模块 
    _synchronizer = [[AVSynchronizer alloc] initWithPlayerStateDelegate:_playerStateDelegate];
    __weak VideoPlayerViewController *weakSelf = self;
    self.bounds = self.view.bounds;
    dispatch_async(dispatch_get_global_queue(DISPATCH_QUEUE_PRIORITY_HIGH, 0), ^{
        __strong VideoPlayerViewController *strongSelf = weakSelf;
        if (strongSelf) {
            NSError *error = nil;
            OpenState state = OPEN_FAILED;
            if ([strongSelf->_parameters count] > 0) {
                state = [strongSelf->_synchronizer openFile:strongSelf->_videoFilePath
                                               usingHWCodec:strongSelf->_usingHWCodec
                                                 parameters:strongSelf->_parameters
                                                      error:&error];
            } else {
                state = [strongSelf->_synchronizer openFile:strongSelf->_videoFilePath
                                               usingHWCodec:strongSelf->_usingHWCodec
                                                      error:&error];
            }
            
            strongSelf->_usingHWCodec = [strongSelf->_synchronizer usingHWCodec];
            
            if (OPEN_SUCCESS == state) {
                //启动AudioOutput与VideoOutput
                dispatch_async(dispatch_get_main_queue(), ^{
                    strongSelf->_videoOutput = [strongSelf createVideoOutputInstance];
                    strongSelf->_videoOutput.contentMode = UIViewContentModeScaleAspectFit;
                    strongSelf->_videoOutput.autoresizingMask = UIViewAutoresizingFlexibleWidth | UIViewAutoresizingFlexibleTopMargin | UIViewAutoresizingFlexibleRightMargin | UIViewAutoresizingFlexibleLeftMargin | UIViewAutoresizingFlexibleHeight | UIViewAutoresizingFlexibleBottomMargin;
                    
                    self.view.backgroundColor = [UIColor clearColor];
                    [self.view insertSubview:strongSelf->_videoOutput atIndex:0];
                });
                
                
                NSInteger audioChannels = [strongSelf->_synchronizer getAudioChannels];
                NSInteger audioSampleRate = [strongSelf->_synchronizer getAudioSampleRate];
                
                NSInteger bytesPerSample = 2;
                
                strongSelf->_audioOutput = [[AudioOutput alloc] initWithChannels:audioChannels
                                                                      sampleRate:audioSampleRate
                                                                  bytesPerSample:bytesPerSample
                                                               filleDataDelegate:strongSelf];
                [strongSelf->_audioOutput play];
                
                
                strongSelf->_isPlaying = YES;
                if (strongSelf->_playerStateDelegate && [strongSelf->_playerStateDelegate respondsToSelector:@selector(openSucced)]) {
                    [strongSelf->_playerStateDelegate openSucced];
                }
            } else if (OPEN_FAILED == state) {
                if (strongSelf->_playerStateDelegate && [strongSelf->_playerStateDelegate respondsToSelector:@selector(connectFailed)]) {
                    [strongSelf->_playerStateDelegate connectFailed];
                }
            }
        }
    });
}

//创建视频界面
- (VideoOutput *)createVideoOutputInstance{
    NSInteger textureWidth = [_synchronizer getVideoFrameWidth];
    NSInteger textureHeight = [_synchronizer getVideoFrameHeight];
    return [[VideoOutput alloc] initWithFrame:self.bounds
                                 textureWidth:textureWidth
                                textureHeight:textureHeight
                                 usingHWCodec:_usingHWCodec
                                   shareGroup:_shareGroup];
}



- (void)restart{
    UIView *parentView = [self.view superview];
    [self.view removeFromSuperview];
    [self stop];
    [self start];
    [parentView addSubview:self.view];
}



- (VideoOutput *)getVideoOutputInstance{
    return _videoOutput;
}


- (void)play{
    if (_isPlaying) {
        return;
    }
    
    if (_audioOutput) {
        [_audioOutput play];
    }
}

- (void)pause{
    if (!_isPlaying) {
        return;
    }
    
    if (_audioOutput) {
        [_audioOutput stop];
    }
}

- (void)stop{
    if (_audioOutput) {
        [_audioOutput stop];
        _audioOutput = nil;
    }
    
    if (_synchronizer) {
        if ([_synchronizer isOpenInputSuccess]) {
            [_synchronizer closeFile];
            _synchronizer = nil;
        } else {
            [_synchronizer interrupt];
        }
    }
    
    if (_videoOutput) {
        [_videoOutput destroy];
        [_videoOutput removeFromSuperview];
        _videoOutput = nil;
    }
}

- (BOOL)isPlaying{
    return _isPlaying;
}

- (UIImage *)movieSnapshot{
    if (!_videoOutput) {
        return nil;
    }
    
    UIGraphicsBeginImageContextWithOptions(_videoOutput.bounds.size, YES, 0);
    [_videoOutput drawViewHierarchyInRect:_videoOutput.bounds afterScreenUpdates:NO];
    
    UIImage *image = UIGraphicsGetImageFromCurrentImageContext();
    UIGraphicsEndImageContext();
    return image;
}
#pragma mark -- FillDataDelegate
//根据音频驱动视频
- (NSInteger)fillAudioData:(SInt16 *)sampleBuffer numFrames:(NSInteger)frameNum numChannels:(NSInteger)channels{
    if (_synchronizer && ![_synchronizer isPlayCompleted]) {
        [_synchronizer audioCallbackFillData:sampleBuffer
                                   numFrames:(UInt32)frameNum
                                 numChannels:(UInt32)channels];
        VideoFrame *videoFrame = [_synchronizer getCorrectVideoFrame];
        if (videoFrame) {
            [_videoOutput presentVideoFrame:videoFrame];
        }
    } else {
        memset(sampleBuffer, 0, frameNum * channels *sizeof(SInt16));
    }
    return 1;
}

- (void)dealloc{
    NSLog(@"dealloc");
}
@end
