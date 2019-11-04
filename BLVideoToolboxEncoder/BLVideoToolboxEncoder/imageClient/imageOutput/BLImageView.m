//
//  BLImageView.m
//  BLVideoToolboxEncoder
//
//  Created by luowailin on 2019/10/30.
//  Copyright © 2019 luowailin. All rights reserved.
//

#import "BLImageView.h"
#import "BLImageDirectPassRenderer.h"
#import "BLImageOutput.h"

@implementation BLImageView{
    BLImageTextureFrame *_inputFrameTexture;
    BLImageDirectPassRenderer *_directPassRenderer;
    
    GLuint _displayFramebuffer;
    GLuint _renderbuffer;
    GLint _backingWidth;
    GLint _backingHeight;
}

+ (Class)layerClass{
    return [CAEAGLLayer class];
}


- (instancetype)initWithFrame:(CGRect)frame
{
    self = [super initWithFrame:frame];
    if (self) {
        CAEAGLLayer *eaglLayer = (CAEAGLLayer *)self.layer;
        eaglLayer.opaque = YES;  //提高性能的作用
        eaglLayer.drawableProperties = [NSDictionary dictionaryWithObjectsAndKeys:[NSNumber numberWithBool:FALSE], kEAGLDrawablePropertyRetainedBacking, kEAGLColorFormatRGBA8, kEAGLDrawablePropertyColorFormat, nil];
        
        __weak typeof(BLImageView *)weakSelf = self;
        runSyncOnVideoProcessingQueue(^{ //在专门的线程中进行操作
            [BLImageContext useImageProcessingContext]; //激活上下文
            if (![weakSelf createDisplayFrameBuffer]) {
                NSLog(@"create display framebuffer failed .....");
            }
            
            self->_directPassRenderer = [[BLImageDirectPassRenderer alloc] init];
            if (![self->_directPassRenderer prepareRender]) {
                NSLog(@"_directPassRenderer prepareRender failed...");
            }
        });
    }
    return self;
}

/** OpenGL ES的渲染流程
 * 如何使用Core Animation层绘制OpenGL ES内容，使用CAEAGLLayer来显示OpenGL最终的渲染内容，而不是通过GLKViewController和GLKView类来显示OpenGL的内容
 *
 * Apple不允许OpenGL直接渲染到屏幕上，我们需要它放进输出的颜色缓冲，然后询问EAGL去把缓冲对象展现到屏幕上。因为颜色渲染缓冲是强制需要的，所以我们需要先把renderBuffer 关联上colorRenderBuffer 然后通过EAGLContext调用renderbufferStorage:和Core Animation图层关联起来。
 *
 * 流程：
 * 1.创建CAEAGLLayer 并配置其属性，把opaque属性的值设置为YES, 通过drawableProperties为CAEAGLayer对象的属性分配新的值,参考：https://developer.apple.com/documentation/opengles/eagldrawable?language=objc
 *
 * 2.分配OpenGL ES上下文并使其成为当前上下文  EAGLContext
 * 3.创建framebuffer对象
 * 4.创建一个彩色渲染缓冲区，通过上下文调用renderbufferStorage:fromDrawable:方法并传递层对象作为参数来分配其存储空间
 * 
 */

//FBO
- (BOOL)createDisplayFrameBuffer{
    [BLImageContext useImageProcessingContext];
    BOOL ret = TRUE;
    glGenFramebuffers(1, &_displayFramebuffer);
    glGenRenderbuffers(1, &_renderbuffer);
    glBindFramebuffer(GL_FRAMEBUFFER, _displayFramebuffer);
    glBindRenderbuffer(GL_RENDERBUFFER, _renderbuffer);
    
    //renderbufferStorage:fromDrawable作用:将可绘制对象的存储绑定到OpenGL ES的renderBuffer对象
    [[[BLImageContext shareImageProcessingContext] context] renderbufferStorage:GL_RENDERBUFFER
                                                                   fromDrawable:(CAEAGLLayer *)self.layer];
    
    //检索颜色renderBuffer的高度和宽度
    glGetRenderbufferParameteriv(GL_RENDERBUFFER, GL_RENDERBUFFER_WIDTH, &_backingWidth);
    glGetRenderbufferParameteriv(GL_RENDERBUFFER, GL_RENDERBUFFER_HEIGHT, &_backingHeight);
    
    //配置当前绑定的帧缓存以便在colorRenderBuffer中保存渲染的像素颜色
    glFramebufferRenderbuffer(GL_FRAMEBUFFER, GL_COLOR_ATTACHMENT0, GL_RENDERBUFFER, _renderbuffer);
    
    GLenum status = glCheckFramebufferStatus(GL_FRAMEBUFFER);
    if (status != GL_FRAMEBUFFER_COMPLETE) {
        NSLog(@"failed to make complete framebuffer object %x", status);
        return FALSE;
    }
    
    
    GLenum glError = glGetError();
    if (glError != GL_NO_ERROR) {
        NSLog(@"failed to setup GL %x", glError);
        return FALSE;
    }
    
    return ret;
}


#pragma mark --
- (void)newFrameReadyAtTime:(CMTime)frameTime timingInfo:(CMSampleTimingInfo)timingInfo{
    glBindFramebuffer(GL_FRAMEBUFFER, _displayFramebuffer);
    [_directPassRenderer renderWithTextureId:[_inputFrameTexture texture]
                                       width:_backingWidth
                                      height:_backingHeight
                                 aspectRatio:TEXTURE_FRAME_ASPECT_RATIO];
    
    glBindRenderbuffer(GL_RENDERBUFFER, _renderbuffer);
    //通知上下文 渲染renderBuffer的内容
    [[[BLImageContext shareImageProcessingContext] context] presentRenderbuffer:GL_RENDERBUFFER];
}

- (void)setInputTexture:(BLImageTextureFrame *)textureFrame{
    _inputFrameTexture = textureFrame;
}


- (void)dealloc{
    _directPassRenderer = nil;
    
    if (_displayFramebuffer) {
        glDeleteFramebuffers(1, &_displayFramebuffer);
        _displayFramebuffer = 0;
    }
    
    if (_renderbuffer) {
        glDeleteRenderbuffers(1, &_renderbuffer);
        _renderbuffer = 0;
    }
}

@end
