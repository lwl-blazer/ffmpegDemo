//
//  ELPushStreamViewController.m
//  BLVideoToolboxEncoder
//
//  Created by luowailin on 2019/10/28.
//  Copyright © 2019 luowailin. All rights reserved.
//

#import "ELPushStreamViewController.h"
#import "BLImageVideoScheduler.h"
#import "ELPushStreamConfigeration.h"

@interface ELPushStreamViewController ()<BLVideoEncoderStatusDelegate>
{
    BLImageVideoScheduler *_videoScheduler;
}
@property (weak, nonatomic) IBOutlet UIButton *startButton;
@property (assign, nonatomic) BOOL started;

@end

@implementation ELPushStreamViewController

- (void)viewDidLoad {
    [super viewDidLoad];
    
    CGRect bounds = self.view.bounds;
    _videoScheduler = [[BLImageVideoScheduler alloc] initWithFrame:bounds
                                                    videoFrameRate:kFrameRate
                                               disableAutoContrast:NO];
    
    [self.view insertSubview:[_videoScheduler previewView] atIndex:0];
    
    self.startButton.layer.cornerRadius = 30.0f;
    self.startButton.layer.masksToBounds = YES;
    self.startButton.layer.borderWidth = 1.0;
    self.startButton.layer.borderColor = [UIColor blueColor].CGColor;
}

- (void)viewWillAppear:(BOOL)animated{
    [super viewWillAppear:animated];
    [_videoScheduler startPreview];
}

- (void)viewWillDisappear:(BOOL)animated{
    [super viewWillDisappear:animated];
    [_videoScheduler stopPreview];
}

- (IBAction)buttonAction:(UIButton *)sender {
    sender.selected = !sender.selected;
    
    if (sender.selected) {
        [_videoScheduler startEncodeWithFPS:kFrameRate
                                 maxBitRate:kMaxVideoBitRate
                                 avgBitRate:kAVGVideoBitRate
                               encoderWidth:kDesiredWidth
                              encoderHeight:kDesiredHeight
                      encoderStatusDelegate:self];
    } else {
        [_videoScheduler stopEncode];
    }
    
}

- (void)onEncoderInitialFailed{
    [_videoScheduler stopEncode];
}

- (void)onEncoderEncodedFailed{
    [_videoScheduler stopEncode];
}


@end
