//
//  ViewController.m
//  Advance-video-play
//
//  Created by luowailin on 2019/9/11.
//  Copyright © 2019 luowailin. All rights reserved.
//

#import "ViewController.h"
#import "ELVideoViewPlayController.h"
#import "CommonUtil.h"


NSString * const MIN_BUFFERED_DURATION = @"Min Buffered Duration";
NSString * const MAX_BUFFERED_DURATION = @"Max Buffered Duration";

@interface ViewController ()
{
    NSMutableDictionary *_requestHeader;
}


@end

@implementation ViewController

- (void)viewDidLoad {
    [super viewDidLoad];

    
    _requestHeader = [NSMutableDictionary dictionary];
    _requestHeader[MIN_BUFFERED_DURATION] = @(2.0f);
    _requestHeader[MAX_BUFFERED_DURATION] = @(4.0f);
}

- (IBAction)actionButton:(id)sender {
    NSString* videoFilePath = [CommonUtil bundlePath:@"music" type:@"flv"];
    BOOL usingHWCodec = NO;//YES;
    ELVideoViewPlayController *vc = [ELVideoViewPlayController viewControllerWithContentPath:videoFilePath contentFrame:self.view.bounds usingHWCodec:usingHWCodec parameters:_requestHeader];
    [self.navigationController pushViewController:vc animated:YES];
}


@end
