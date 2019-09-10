//
//  ViewController.m
//  OpenGLRenderer
//
//  Created by luowailin on 2019/9/3.
//  Copyright © 2019 luowailin. All rights reserved.
//

#import "ViewController.h"
#import "PngPreviewController.h"
#import "CommonUtil.h"

@interface ViewController ()

@end

@implementation ViewController

- (void)viewDidLoad {
    [super viewDidLoad];
}

- (IBAction)display:(UIButton *)sender {
    
    NSString* pngFilePath = [CommonUtil bundlePath:@"1" type:@"png"];
    
    PngPreviewController *previewController = [PngPreviewController viewControllerWithContentPath:pngFilePath
                                                                                     contentFrame:CGRectMake(0, 80, CGRectGetWidth(self.view.bounds), CGRectGetHeight(self.view.bounds) - 80)];
    
    //[self presentViewController:previewController animated:YES completion:NULL];
   [self.navigationController pushViewController:previewController animated:YES];
}

@end
