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

@interface ELPushStreamViewController ()
{
    BLImageVideoScheduler *_videoScheduler;
}

@end

@implementation ELPushStreamViewController

- (void)viewDidLoad {
    [super viewDidLoad];
    
    CGRect bounds = self.view.bounds;
    _videoScheduler = [[BLImageVideoScheduler alloc] initWithFrame:bounds
                                                    videoFrameRate:kFrameRate
                                               disableAutoContrast:NO];
    
    [self.view insertSubview:[_videoScheduler previewView] atIndex:0];
}

- (void)viewWillAppear:(BOOL)animated{
    [_videoScheduler startPreview];
}


@end
