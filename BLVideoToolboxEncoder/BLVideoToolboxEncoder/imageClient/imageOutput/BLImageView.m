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
        eaglLayer.opaque = YES;
        eaglLayer.drawableProperties = [NSDictionary dictionaryWithObjectsAndKeys:[NSNumber numberWithBool:FALSE], kEAGLDrawablePropertyRetainedBacking, kEAGLColorFormatRGBA8, kEAGLDrawablePropertyColorFormat, nil];
        
        __weak typeof(BLImageView *)weakSelf = self;
        runSyncOnVideoProcessingQueue(^{
            [BLImageContext useImageProcessingContext];
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

- (void)newFrameReadyAtTime:(CMTime)frameTime timingInfo:(CMSampleTimingInfo)timingInfo{
    glBindFramebuffer(GL_FRAMEBUFFER, _displayFramebuffer);
    [_directPassRenderer renderWithTextureId:[_inputFrameTexture texture]
                                       width:_backingWidth
                                      height:_backingHeight
                                 aspectRatio:TEXTURE_FRAME_ASPECT_RATIO];
    
    glBindRenderbuffer(GL_RENDERBUFFER, _renderbuffer);
    
    [[[BLImageContext shareImageProcessingContext] context] presentRenderbuffer:GL_RENDERBUFFER];
}

- (void)setInputTexture:(BLImageTextureFrame *)textureFrame{
    _inputFrameTexture = textureFrame;
}

- (BOOL)createDisplayFrameBuffer{
    [BLImageContext useImageProcessingContext];
    BOOL ret = TRUE;
    glGenFramebuffers(1, &_displayFramebuffer);
    glGenFramebuffers(1, &_renderbuffer);
    glBindFramebuffer(GL_FRAMEBUFFER, _displayFramebuffer);
    glBindRenderbuffer(GL_RENDERBUFFER, _renderbuffer);
    
    [[[BLImageContext shareImageProcessingContext] context] renderbufferStorage:GL_RENDERBUFFER
                                                                   fromDrawable:(CAEAGLLayer *)self.layer];
    
    glGetRenderbufferParameteriv(GL_RENDERBUFFER, GL_RENDERBUFFER_WIDTH, &_backingWidth);
    glGetRenderbufferParameteriv(GL_RENDERBUFFER, GL_RENDERBUFFER_HEIGHT, &_backingHeight);
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
