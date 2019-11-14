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
    self.recoder = [[AudioUnitInput alloc] initWithAccompanyPath:[CommonUtil documentsPath:@"recorder.pcm"]];
}

- (IBAction)action:(UIButton *)sender {
    
    sender.selected = !sender.selected;
    if (sender.selected) {
        
    }
}

@end
