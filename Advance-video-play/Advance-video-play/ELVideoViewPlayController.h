//
//  ELVideoViewPlayController.h
//  Advance-video-play
//
//  Created by luowailin on 2019/9/17.
//  Copyright © 2019 luowailin. All rights reserved.
//

#import <UIKit/UIKit.h>

NS_ASSUME_NONNULL_BEGIN

@interface ELVideoViewPlayController : UIViewController

+ (instancetype)viewControllerWithContentPath:(NSString *)path
                                 contentFrame:(CGRect)frame
                                 usingHWCodec:(BOOL)usingHWCodec
                                   parameters:(NSDictionary *)parameters;

@end

NS_ASSUME_NONNULL_END
