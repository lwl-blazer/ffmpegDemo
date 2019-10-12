//
//  ViewController.m
//  AudioUnit-EarFoldback
//
//  Created by luowailin on 2019/10/11.
//  Copyright © 2019 luowailin. All rights reserved.
//

#import "ViewController.h"
#import "AudioOutput.h"

@interface ViewController ()

@property(nonatomic, strong) AudioOutput *output;
@property (weak, nonatomic) IBOutlet UIButton *recordButton;

@end

@implementation ViewController

- (void)viewDidLoad {
    [super viewDidLoad];
    self.view.backgroundColor = [UIColor redColor];
    
    self.output = [[AudioOutput alloc] init];
    [self.recordButton setTitle:@"停止录音" forState:UIControlStateSelected];
}

- (IBAction)recordAction:(UIButton *)sender {
    if (sender.selected) {
        [self.output stop];
    } else {
        [self.output start];
    }
    sender.selected = !sender.selected;
}


@end
