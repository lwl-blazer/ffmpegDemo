//
//  ViewController.m
//  AUPlayer
//
//  Created by luowailin on 2019/8/2.
//  Copyright © 2019 luowailin. All rights reserved.
//

#import "ViewController.h"
#import "CommonUtil.h"
#import "AUGraphPlayer.h"

@interface ViewController (){
    AUGraphPlayer *graphPlayer;
}

@property(nonatomic, assign) BOOL isAcc;

@end

@implementation ViewController

- (void)viewDidLoad {
    [super viewDidLoad];
    self.isAcc = NO;
    
}

- (IBAction)playAction:(id)sender {
    
    NSLog(@"Play Music...");
    if (graphPlayer) {
        [graphPlayer stop];
    }

   // NSString *filePath = [CommonUtil bundlePath:@"0fe2a7e9c51012210eaaa1e2b103b1b1" type:@"m4a"];
    NSString *filePath = [CommonUtil bundlePath:@"MiAmor" type:@"mp3"];
    
    graphPlayer = [[AUGraphPlayer alloc] initWithFilePath:filePath];
    [graphPlayer play];
}

- (IBAction)switchAction:(id)sender {
    
    _isAcc = !_isAcc;
    [graphPlayer setInputSource:_isAcc];
    
}


- (IBAction)stopAction:(id)sender {

    NSLog(@"stop music ...");
    [graphPlayer stop];
}

@end
