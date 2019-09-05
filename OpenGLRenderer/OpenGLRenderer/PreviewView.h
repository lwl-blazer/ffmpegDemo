//
//  PreviewView.h
//  OpenGLRenderer
//
//  Created by luowailin on 2019/9/3.
//  Copyright © 2019 luowailin. All rights reserved.
//

#import <UIKit/UIKit.h>

NS_ASSUME_NONNULL_BEGIN

@interface PreviewView : UIView

- (instancetype)initWithFrame:(CGRect)frame
                     filePath:(NSString *)filePath;

- (void)render;
- (void)destroy;

@end

NS_ASSUME_NONNULL_END
