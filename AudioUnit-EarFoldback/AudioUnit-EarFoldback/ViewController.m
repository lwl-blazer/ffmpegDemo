//
//  ViewController.m
//  AudioUnit-EarFoldback
//
//  Created by luowailin on 2019/10/11.
//  Copyright © 2019 luowailin. All rights reserved.
//

#import "ViewController.h"
#import "CommonUtil.h"
#import "AudioQuqeueOutput.h"
#import "AudioUnitRecorder.h"

@interface ViewController ()

@property(nonatomic, strong) AudioQuqeueOutput *audioQueueOutput;
@property(nonatomic, strong) AudioUnitRecorder *audioRecoder;
@property (weak, nonatomic) IBOutlet UIButton *recordButton;

@end

@implementation ViewController

- (void)viewDidLoad {
    [super viewDidLoad];
    self.view.backgroundColor = [UIColor redColor];
    
//    self.audioQueueOutput = [[AudioQuqeueOutput alloc] init];
//    [self.recordButton setTitle:@"停止录音" forState:UIControlStateSelected];
    
    self.audioRecoder = [[AudioUnitRecorder alloc] initWithPath:[CommonUtil bundlePath:@"recorder" type:@"pcm"]];
}

- (IBAction)recordAction:(UIButton *)sender {
//    if (sender.selected) {
//        [self.audioQueueOutput stop];
//    } else {
//        [self.audioQueueOutput start];
//    }
        if (sender.selected) {
            [self.audioRecoder stop];
        } else {
            [self.audioRecoder start];
        }
    sender.selected = !sender.selected;
}


@end
