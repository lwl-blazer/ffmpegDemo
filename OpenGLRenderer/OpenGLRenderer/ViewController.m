//
//  ViewController.m
//  OpenGLRenderer
//
//  Created by luowailin on 2019/9/3.
//  Copyright © 2019 luowailin. All rights reserved.
//

#import "ViewController.h"
#import "PngPreviewController.h"

@interface ViewController ()

@end

@implementation ViewController

- (void)viewDidLoad {
    [super viewDidLoad];
}

- (IBAction)display:(UIButton *)sender {
    PngPreviewController *previewController = [[PngPreviewController alloc] init];
    [self.navigationController pushViewController:previewController animated:YES];
}

@end
