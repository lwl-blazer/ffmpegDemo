//
//  ViewController.m
//  BLPlayerItem
//
//  Created by luowailin on 2019/4/19.
//  Copyright © 2019 luowailin. All rights reserved.
//

#import "ViewController.h"
#import "XDemux.h"
#import "XDecode.h"
#import "DecodeObject.h"

@interface ViewController ()

@property (weak, nonatomic) IBOutlet UITextField *urlField;
@property (weak, nonatomic) IBOutlet UISlider *progressSlide;

@end

@implementation ViewController

- (void)viewDidLoad {
    [super viewDidLoad];
}

- (IBAction)runButtonAction:(id)sender {
    DecodeObject *object = [[DecodeObject alloc] init];
    [object decodeWithTwoUrl:@"521.flv"];
}


- (IBAction)slideAction:(id)sender {
    
}


@end
