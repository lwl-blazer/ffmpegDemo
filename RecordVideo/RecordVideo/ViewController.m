//
//  ViewController.m
//  RecordVideo
//
//  Created by luowailin on 2019/11/13.
//  Copyright © 2019 luowailin. All rights reserved.
//

#import "ViewController.h"
#import "AudioUnitInput.h"
#import "CommonUtil.h"

@interface ViewController ()

@property(nonatomic, strong) AudioUnitInput *recoder;

@end

@implementation ViewController

- (void)viewDidLoad {
    [super viewDidLoad];
    self.recoder = [[AudioUnitInput alloc] initWithpath:[CommonUtil documentsPath:@"recorder.pcm"]
                                          accompanyPath:[CommonUtil bundlePath:@"background" type:@"mp3"]];
}

- (IBAction)action:(UIButton *)sender {
    sender.selected = !sender.selected;
    if (sender.selected) {
        [self.recoder start];
    } else {
        [self.recoder stop];
    }
}

@end
