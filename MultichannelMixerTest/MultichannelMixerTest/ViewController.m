//
//  ViewController.m
//  MultichannelMixerTest
//
//  Created by luowailin on 2019/10/23.
//  Copyright © 2019 luowailin. All rights reserved.
//

#import "ViewController.h"
#import "AudioUnitMixer.h"
#import "CommonUtil.h"

@interface ViewController ()

@property(nonatomic, strong) AudioUnitMixer *mixer;

@end

@implementation ViewController

- (void)viewDidLoad {
    [super viewDidLoad];
    /*[CommonUtil documentsPath:@"GuitarMonoSTP.aif"]*/
    /*[CommonUtil documentsPath:@"DrumsMonoSTP.aif"]*/
    self.view.backgroundColor = [UIColor whiteColor];
    self.mixer = [[AudioUnitMixer alloc] initWithPath1:[[NSBundle mainBundle] pathForResource:@"GuitarMonoSTP" ofType:@"aif"]
                                                 path2:[[NSBundle mainBundle] pathForResource:@"DrumsMonoSTP" ofType:@"aif"]
                  ];
}

- (IBAction)playAction:(UIButton *)sender {
    if (self.mixer.isPlaying) {
        [self.mixer stop];
        sender.selected = NO;
    } else {
        [self.mixer start];
        sender.selected = YES;
    }
}

- (IBAction)bus0Switch:(UISwitch *)sender {
    AudioUnitParameterValue isOn = (AudioUnitParameterValue)sender.isOn;
    [self.mixer enableInput:0
                       isOn:isOn];
}

- (IBAction)bus0Slider:(UISlider *)sender {
    AudioUnitParameterValue value = (AudioUnitParameterValue)sender.value;
    [self.mixer setInputVolume:0
                         value:value];
}

- (IBAction)bus1Switch:(UISwitch *)sender {
    AudioUnitParameterValue isOn = (AudioUnitParameterValue)sender.isOn;
    [self.mixer enableInput:1
                       isOn:isOn];
}

- (IBAction)bus1Slider:(UISlider *)sender {
    AudioUnitParameterValue value = (AudioUnitParameterValue)sender.value;
    [self.mixer setInputVolume:1
                         value:value];
}

- (IBAction)outputVolumeSlider:(UISlider *)sender {
    AudioUnitParameterValue value = (AudioUnitParameterValue)sender.value;
    [self.mixer setOutputVolume:value];
}

@end
