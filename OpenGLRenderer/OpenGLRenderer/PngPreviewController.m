//
//  PngPreviewController.m
//  OpenGLRenderer
//
//  Created by luowailin on 2019/9/3.
//  Copyright © 2019 luowailin. All rights reserved.
//

#import "PngPreviewController.h"

@interface PngPreviewController ()

@end

@implementation PngPreviewController

- (void)viewDidLoad {
    [super viewDidLoad];
    // Do any additional setup after loading the view.
}

+ (id)viewControllerWithContentPath:(NSString *)pngFilePath contentFrame:(CGRect)frame{
    return [[PngPreviewController alloc] initWithContentPath:pngFilePath
                                                contentFrame:frame];
}

- (id)initWithContentPath:(NSString *)path
             contentFrame:(CGRect)frame{
    return nil;
}

@end
