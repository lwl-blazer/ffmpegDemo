//
//  ViewController.m
//  AudioPlayer
//
//  Created by luowailin on 2019/8/5.
//  Copyright © 2019 luowailin. All rights reserved.
//

#import "ViewController.h"
#import "CommonUtil.h"
#import "AudioPlayer.h"

@interface ViewController (){
    AudioPlayer *_audioPlayer;
}

@end

@implementation ViewController

- (void)viewDidLoad {
    [super viewDidLoad];
}

- (IBAction)playAction:(UIButton *)sender { //开始播放
    NSLog(@"play music");
    NSString *filtPath = [CommonUtil bundlePath:@"test" type:@"m4a"];
    _audioPlayer = [[AudioPlayer alloc] initWithFilePath:filtPath];
    [_audioPlayer start];
}

- (IBAction)stopAction:(UIButton *)sender { //停止播放
    NSLog(@"stop music");
    if (_audioPlayer) {
        [_audioPlayer stop];
    }
}

@end
