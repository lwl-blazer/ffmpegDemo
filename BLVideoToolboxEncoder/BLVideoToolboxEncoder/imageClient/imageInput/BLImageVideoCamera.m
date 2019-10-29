//
//  BLImageVideoCamera.m
//  BLVideoToolboxEncoder
//
//  Created by luowailin on 2019/10/29.
//  Copyright © 2019 luowailin. All rights reserved.
//

#import "BLImageVideoCamera.h"
#import "BLImageCameraRenderer.h"
#import "BLImageContext.h"
#import "ELPushStreamConfigeration.h"

//BT.601 which is the standard for SDTV
GLfloat colorConversion601Default[] = {
    1.164,  1.164, 1.164,
      0.0, -0.392, 2.017,
    1.596, -0.813,   0.0,
};

//BT.601 full range
GLfloat colorConversion601FullRangeDefault[] = {
    1.0,   1.0,    1.0,
    0.0,   -0.392, 2.017,
    1.596, -0.813, 0.0,
};

//BT.709 which is the standard for HDTV
GLfloat colorConversion709Default[] = {
    1.164,  1.164, 1.164,
    0.0,   -0.213, 2.112,
    1.793, -0.533, 0.0,
};

GLfloat *colorConversion601 = colorConversion601Default;
GLfloat *colorConversion601FullRange = colorConversion601FullRangeDefault;
GLfloat *colorConversion709 = colorConversion709Default;

@interface BLImageVideoCamera ()
{
    dispatch_queue_t _sampleBufferCallbackQueue;
    
    int32_t _frameRate;
    
    dispatch_semaphore_t _frameRenderingSemaphore;
    BLImageCameraRenderer * _cameraLoadTexRenderer;
    
    BLImageRotationMode _inputTexRotation;
    
    BOOL isFullYUVRange;
    const GLfloat *_preferredConversion;
}

//处理输入输出设备的数据流动
@property(nonatomic, strong) AVCaptureSession *captureSession;

//输入输出设备的数据连接
@property(nonatomic, strong) AVCaptureConnection *connection;

//输入设备
@property(nonatomic, strong) AVCaptureDeviceInput *captureInput;

//输出设备
@property(nonatomic, strong) AVCaptureVideoDataOutput *captureOutput;

//是否OpenGLES渲染
@property(nonatomic, assign) BOOL shouldEnableOpenGL;

@end

@implementation BLImageVideoCamera

- (instancetype)initWithFPS:(int)fps{
    self = [super init];
    if (self) {
        [[NSNotificationCenter defaultCenter] addObserver:self
                                                 selector:@selector(applicationWillResignActive:)
                                                     name:NSExtensionHostWillResignActiveNotification
                                                   object:nil];
        
        [[NSNotificationCenter defaultCenter] addObserver:self
                                                 selector:@selector(applicationDidBecomeActive:)
                                                     name:NSExtensionHostDidBecomeActiveNotification
                                                   object:nil];
        
        _frameRate = fps;
        _shouldEnableOpenGL = YES;
        
        [self initialSession];
        [self updateOrientationSendToTargets];
        
        runSyncOnVideoProcessingQueue(^{
            [BLImageContext useImageProcessingContext];
            self->_cameraLoadTexRenderer = [[BLImageCameraRenderer alloc] init];
            if (![self->_cameraLoadTexRenderer prepareRender:self->isFullYUVRange]) {
                NSLog(@"Create Camera Load Texture Renderer Failed....");
            }
        });
    }
    return self;
}

#pragma mark -- public method
- (void)startCapture{
    if (![_captureSession isRunning]) {
        [_captureSession startRunning];
    };
}

- (void)stopCapture{
    if ([_captureSession isRunning]) {
        [_captureSession stopRunning];
    }
}

//切换分辨率
- (void)switchResolution{
    [_captureSession beginConfiguration];
    
    if ([_captureSession.sessionPreset isEqualToString:[NSString stringWithString:AVCaptureSessionPreset640x480]]) {
        [_captureSession setSessionPreset:[NSString stringWithString:AVCaptureSessionPreset1280x720]];
    } else {
        [_captureSession setSessionPreset:[NSString stringWithString:AVCaptureSessionPreset640x480]];
    }
    
    [_captureSession commitConfiguration];
}

//切换摄像头
- (int)switchFrontBackCamera{
    
}

#pragma mark -- private method

- (void)applicationWillResignActive:(NSNotification *)sender{
    self.shouldEnableOpenGL = NO;
}

- (void)applicationDidBecomeActive:(NSNotification *)sender{
    self.shouldEnableOpenGL = YES;
}

- (void)initialSession{
    //初始化 session 和设备
    self.captureSession = [[AVCaptureSession alloc] init];
    self.captureInput = [[AVCaptureDeviceInput alloc] initWithDevice:[self frontCamera]
                                                               error:nil];
    self.captureOutput = [[AVCaptureVideoDataOutput alloc] init];
    self.captureOutput.alwaysDiscardsLateVideoFrames = YES;
    
    //输出配置
    BOOL supportFullYUVRange = NO;
    NSArray *supportedPixelFormats = _captureOutput.availableVideoCVPixelFormatTypes;
    for (NSNumber *currentPixelFormat in supportedPixelFormats) {
        if ([currentPixelFormat intValue] == kCVPixelFormatType_420YpCbCr8BiPlanarFullRange) {
            supportFullYUVRange = YES;
        }
    }
    
    if (supportFullYUVRange) {
        [_captureOutput setVideoSettings:@{(id)kCVPixelBufferPixelFormatTypeKey:@(kCVPixelFormatType_420YpCbCr8BiPlanarFullRange)}];
        isFullYUVRange = YES;
    } else {
        [_captureOutput setVideoSettings:@{(id)kCVPixelBufferPixelFormatTypeKey:@(kCVPixelFormatType_420YpCbCr8BiPlanarVideoRange)}];
        isFullYUVRange = NO;
    }
    [_captureOutput setSampleBufferDelegate:self
                                      queue:[self sampleBufferCallbackQueue]];
    
    
    //添加设备
    if ([self.captureSession canAddInput:self.captureInput]) {
        [self.captureSession addInput:self.captureInput];
    }
    if ([self.captureSession canAddOutput:self.captureOutput]) {
        [self.captureSession addOutput:self.captureOutput];
    }
    
    
    [self.captureSession beginConfiguration];
    
    if ([self.captureSession canSetSessionPreset:[NSString stringWithString:kHighCaptureSessionPreset]]) {
        [self.captureSession setSessionPreset:[NSString stringWithString:kHighCaptureSessionPreset]];
    } else {
        [self.captureSession setSessionPreset:[NSString stringWithString:kCommonCaptureSessionPreset]];
    }
    
    self.connection = [self.captureOutput connectionWithMediaType:AVMediaTypeVideo];
    [self setRelativeVideoOrientation];
    [self setFrameRate];
    [self.captureSession commitConfiguration];
}

- (AVCaptureDevice *)frontCamera{
    AVCaptureDevice *device = [self cameraWithPosition:AVCaptureDevicePositionFront];
    return device;
}

- (void)setRelativeVideoOrientation{
    self.connection.videoOrientation = AVCaptureVideoOrientationPortrait;
}

- (AVCaptureDevice *)backCamera{
    AVCaptureDevice *device = [self cameraWithPosition:AVCaptureDevicePositionBack];
    return device;
}

- (AVCaptureDevice *)cameraWithPosition:(AVCaptureDevicePosition)position{
    NSArray *devices = [AVCaptureDevice devicesWithMediaType:AVMediaTypeVideo];
    for (AVCaptureDevice *device in devices) {
        if ([device position] == position) {
            NSError *error = nil;
            if ([device isFocusModeSupported:AVCaptureFocusModeContinuousAutoFocus] && [device lockForConfiguration:&error]) {
                [device setFocusMode:AVCaptureFocusModeContinuousAutoFocus];
                if ([device isFocusPointOfInterestSupported]) {
                    [device setFocusPointOfInterest:CGPointMake(0.5f, 0.5f)];
                }
                [device unlockForConfiguration];
            }
            return device;
        }
    }
    return nil;
}


- (void)updateOrientationSendToTargets{
    
}







- (dispatch_queue_t)sampleBufferCallbackQueue{
    if (!_sampleBufferCallbackQueue) {
        _sampleBufferCallbackQueue = dispatch_queue_create("com.changba.sampleBufferCallQueue", DISPATCH_QUEUE_SERIAL);
    }
    return _sampleBufferCallbackQueue;
}

@end
