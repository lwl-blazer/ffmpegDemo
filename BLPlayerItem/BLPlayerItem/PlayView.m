//
//  PlayView.m
//  BLPlayerItem
//
//  Created by luowailin on 2019/4/19.
//  Copyright © 2019 luowailin. All rights reserved.
//

#import "PlayView.h"

@interface PlayView ()<GLKViewDelegate>

@property(nonatomic, strong) EAGLContext *mContext;  //OpenGL ES上下文
@property(nonatomic, strong) GLKBaseEffect *effect;

@end


@implementation PlayView

- (void)awakeFromNib{
    [super awakeFromNib];
    [self setupGL];
    [self uploadVertexArray];
    [self uploadTexture];
}

- (instancetype)initWithFrame:(CGRect)frame
{
    self = [super initWithFrame:frame];
    if (self) {
        [self setupGL];
        [self uploadVertexArray];
        [self uploadTexture];
    }
    return self;
}

- (void)setupGL{
    self.mContext = [[EAGLContext alloc] initWithAPI:kEAGLRenderingAPIOpenGLES3];
    
    if (!self.mContext) {
        NSLog(@"Failed to create ES context");
    }
    
    self.context = self.mContext;
    self.drawableDepthFormat = GLKViewDrawableDepthFormat24;
    self.drawableColorFormat = GLKViewDrawableColorFormatRGBA8888;
    [EAGLContext setCurrentContext:self.mContext];
    
    self.effect = [[GLKBaseEffect alloc] init];
}


- (void)uploadVertexArray{
    GLfloat vertexData[] =
    {
        0.5, -0.5, 0.0f,    1.0f, 0.0f, //右下
        0.5, 0.5, -0.0f,    1.0f, 1.0f, //右上
        -0.5, 0.5, 0.0f,    0.0f, 1.0f, //左上
        
        0.5, -0.5, 0.0f,    1.0f, 0.0f, //右下
        -0.5, 0.5, 0.0f,    0.0f, 1.0f, //左上
        -0.5, -0.5, 0.0f,   0.0f, 0.0f, //左下
    };
    
    GLuint buffer;
    glGenBuffers(1, &buffer);
    glBindBuffer(GL_ARRAY_BUFFER, buffer);
    glBufferData(GL_ARRAY_BUFFER, sizeof(vertexData), vertexData, GL_STATIC_DRAW);
    
    glEnableVertexAttribArray(GLKVertexAttribPosition);
    glVertexAttribPointer(GLKVertexAttribPosition, 3, GL_FLOAT, GL_FALSE, sizeof(GL_FLOAT) * 3, (void *)0);
    
    glEnableVertexAttribArray(GLKVertexAttribTexCoord0);
    glVertexAttribPointer(GLKVertexAttribTexCoord0, 2, GL_FLOAT, GL_FALSE, sizeof(GL_FLOAT) * 2, (GLfloat *)NULL + 3);
}

- (void)uploadTexture{
    //纹理贴图
    NSString *filePath = [[NSBundle mainBundle] pathForResource:@"for_test" ofType:@"jpg"];
    NSDictionary *options = [NSDictionary dictionaryWithObjectsAndKeys:@(1), GLKTextureLoaderOriginBottomLeft, nil];
    
    GLKTextureInfo *textureInfo = [GLKTextureLoader textureWithContentsOfFile:filePath options:options error:nil];
    
    //着色器
    self.effect.texture2d0.enabled = GL_TRUE;
    self.effect.texture2d0.name = textureInfo.name;
}

- (void)glkView:(GLKView *)view drawInRect:(CGRect)rect{
    NSLog(@"draw");
    glClearColor(0.3f, 0.6f, 1.0f, 1.0f);
    glClear(GL_COLOR_BUFFER_BIT | GL_DEPTH_BUFFER_BIT);
    
    //启动
    [self.effect prepareToDraw];
    glDrawArrays(GL_TRIANGLES, 0, 6);
}

+ (Class)layerClass{
    return [CAEAGLLayer class];
}

- (void)dealloc{
    if (self.mContext == [EAGLContext currentContext]) {
        [EAGLContext setCurrentContext:nil];
        self.mContext = nil;
    }
}



@end
