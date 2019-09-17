//
//  LoadingView.h
//  Advance-video-play
//
//  Created by luowailin on 2019/9/17.
//  Copyright © 2019 luowailin. All rights reserved.
//

#import <UIKit/UIKit.h>

NS_ASSUME_NONNULL_BEGIN

@interface LoadingView : UIView
{
    UIActivityIndicatorView *indicatorView;
    UIView *conerView;
}

@property(nonatomic, assign) BOOL isLikeSynchro;

- (void)show;
- (void)close;

+ (LoadingView *)shareLoadingView;

@end

NS_ASSUME_NONNULL_END
