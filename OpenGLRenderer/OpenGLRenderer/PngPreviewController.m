//
//  PngPreviewController.m
//  OpenGLRenderer
//
//  Created by luowailin on 2019/9/3.
//  Copyright © 2019 luowailin. All rights reserved.
//

#import "PngPreviewController.h"
#import "PreviewView.h"

@interface PngPreviewController ()

@property(nonatomic, strong) PreviewView *previewView;

@end

@implementation PngPreviewController

+ (id)viewControllerWithContentPath:(NSString *)pngFilePath contentFrame:(CGRect)frame{
    return [[PngPreviewController alloc] initWithContentPath:pngFilePath
                                                contentFrame:frame];
}

- (id)initWithContentPath:(NSString *)path
             contentFrame:(CGRect)frame{
    
    NSAssert(path.length > 0, @"empty path");
    self = [super initWithNibName:nil bundle:nil];
    if (self) {
        self.previewView = [[PreviewView alloc] initWithFrame:frame filePath:path];
        self.previewView.contentMode = UIViewContentModeScaleAspectFill;
        
        self.view.backgroundColor = [UIColor colorWithRed:0.5 green:0.5 blue:0.5 alpha:1.0];
        [self.view insertSubview:self.previewView atIndex:0];
    }
    return nil;
}

- (void)viewDidLoad{
    [super viewDidLoad];
    [self.previewView render];
}

- (void)dealloc{
    if (self.previewView) {
        [self.previewView destroy];
        self.previewView = nil;
    }
}


@end
