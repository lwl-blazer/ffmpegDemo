//
//  PlayView.h
//  BLPlayerItem
//
//  Created by luowailin on 2019/4/19.
//  Copyright © 2019 luowailin. All rights reserved.
//

#import <GLKit/GLKit.h>

NS_ASSUME_NONNULL_BEGIN

@interface PlayView : GLKView

@end

NS_ASSUME_NONNULL_END

/**
 * GLKView 是对CAEAGLayer的封装，简化了我们使用Core Animation去渲染OpenGL ES的步骤
 *
 * OpenGL ES通过CAEACALayer该类连接到Core Animation，这是一种特殊类型的Core Animation层，其内容来自OpenGL ES renderbuffer。Core Animation将renderbuffer的内容与其他图层复合，并在屏幕上显示生成的图像
 *
 *
 * CAEACALayer提供了两项主要功能:
    1.它为renderbuffer分配共享存储
    2.将渲染缓冲呈现给Core Animation，用renderbuffer的数据替换了以前的内容
 
 * 最大的优点: 只有当渲染的图像更改时，Core Animation图层的内容不需要在每个帧中绘制
 */
