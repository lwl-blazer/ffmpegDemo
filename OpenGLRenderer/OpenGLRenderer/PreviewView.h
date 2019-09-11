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

/**
 * 在iOS平台上不允许开发者使用OpenGL ES直接渲染屏幕，必须使用FrameBuffer与RenderBuffer来进行渲染。若要使用EAGL,则必须创建一个RenderBuffer
 * 然后让OpenGL ES渲染到该RenderBuffer上去， 而该RenderBuffer则需要绑定到一个CAEAGLLayer上面去，
 * 最后调用EAGLContext的presentRenderBuffer方法，就可以将渲染结果输出到屏幕上去了。 底层也是执行类似于swapBuffer过程，将OpenGLES 渲染的结果绘制到物理屏幕上去(View的Layer)
 */
