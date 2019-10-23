//
//  ViewController.m
//  MultichannelMixerTest
//
//  Created by luowailin on 2019/10/23.
//  Copyright © 2019 luowailin. All rights reserved.
//

#import "ViewController.h"

@interface ViewController ()

@end

@implementation ViewController

- (void)viewDidLoad {
    [super viewDidLoad];
    self.view.backgroundColor = [UIColor whiteColor];
}

- (IBAction)playAction:(UIButton *)sender {
    
    if (sender.selected) {
        sender.selected = NO;
    } else {
        sender.selected = YES;
    }
}

- (IBAction)bus0Switch:(UISwitch *)sender {
    
}

- (IBAction)bus0Slider:(UISlider *)sender {
    
}


- (IBAction)bus1Switch:(UISwitch *)sender {
    
}



- (IBAction)bus1Slider:(UISlider *)sender {
    
}

- (IBAction)outputVolumeSlider:(UISlider *)sender {
    
    
}

@end
