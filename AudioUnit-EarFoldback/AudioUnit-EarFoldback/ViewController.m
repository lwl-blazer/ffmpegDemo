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
    self.audioRecoder = [[AudioUnitRecorder alloc] initWithPath:[CommonUtil documentsPath:@"recorder.caf"]];
}

- (IBAction)recordAction:(UIButton *)sender {
    
    //        [self.audioQueueOutput start];
    [self.audioRecoder start];
    
}

- (IBAction)stop:(UIButton *)sender {
    //        [self.audioQueueOutput stop];
    [self.audioRecoder stop];
}

@end
