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
    0.0,   -0.343, 1.765,
    1.4, -0.711, 0.0,
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
        
        //创建信号量
        _frameRenderingSemaphore = dispatch_semaphore_create(1);
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
    NSUInteger cameraCount = [[AVCaptureDevice devicesWithMediaType:AVMediaTypeVideo] count];
    int result = -1;
    if (cameraCount > 1) {
        NSError *error;
        AVCaptureDeviceInput *videoInput;
        AVCaptureDevicePosition position = [[self.captureInput device] position];
        if (position == AVCaptureDevicePositionBack) {
            videoInput = [[AVCaptureDeviceInput alloc] initWithDevice:[self frontCamera]
                                                                error:&error];
            result = 0;
        } else if (position == AVCaptureDevicePositionBack) {
            videoInput = [[AVCaptureDeviceInput alloc] initWithDevice:[self backCamera]
                                                                error:&error];
            result = 0;
        } else {
            return -1;
        }
        
        if (videoInput) {
            [self.captureSession beginConfiguration];
            [self.captureSession removeInput:self.captureInput];
            if ([self.captureSession canAddInput:videoInput]) {
                [self.captureSession addInput:videoInput];
                [self setCaptureInput:videoInput];
            } else {
                [self.captureSession addInput:self.captureInput];
            }
            
            self.connection = [self.captureOutput connectionWithMediaType:AVMediaTypeVideo];
            
            AVCaptureVideoStabilizationMode stabilizationMode = AVCaptureVideoStabilizationModeStandard;
            BOOL supportStabilization = [self.captureInput.device.activeFormat isVideoStabilizationModeSupported:stabilizationMode];
            NSLog(@"device active format: %@, 是否支持防抖: %@", self.captureInput.device.activeFormat,
            supportStabilization ? @"support" : @"not support");
            if ([self.captureInput.device.activeFormat isVideoStabilizationModeSupported:stabilizationMode]) {
                [self.connection setPreferredVideoStabilizationMode:stabilizationMode];
                NSLog(@"===============mode %@", @(self.connection.activeVideoStabilizationMode));
            }
            
            [self setRelativeVideoOrientation];
            [self setFrameRate];
            
            [self.captureSession commitConfiguration];
        } else if (error != nil) {
            result = -1;
        }
        [self updateOrientationSendToTargets];
    }
    return result;
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
    self.captureInput = [[AVCaptureDeviceInput alloc] initWithDevice:[self backCamera]
                                                               error:nil];
    self.captureOutput = [[AVCaptureVideoDataOutput alloc] init];
    self.captureOutput.alwaysDiscardsLateVideoFrames = YES;  //是否丢掉迟到的帧 默认为YES
    
    //输出配置
    BOOL supportFullYUVRange = NO;
    NSArray *supportedPixelFormats = _captureOutput.availableVideoCVPixelFormatTypes;
    for (NSNumber *currentPixelFormat in supportedPixelFormats) {
        if ([currentPixelFormat intValue] == kCVPixelFormatType_420YpCbCr8BiPlanarFullRange) {
            supportFullYUVRange = YES;
        }
    }
    /**
     * 看懂kCVPixelFormatTypes
     *
     * kCVPixelFormatType_{长度|序列}{颜色空间}{Planar|8BiPlanar}{FullRange|VideoRange}
     *
     * Planar--平面   BiPlanar--双平面  平面/双平面主要应用于YUV上。UV分开存储的为Planar.反之是BiPlanar 所以
         kCVPixelFormatType_420YpCbCr8PlanarFullRange是420p
         kCVPixelFormatType_420YpCbCr8BiPlanarFullRange是nv12
     * VideoRange和FullRange的区别在于数值的范围   FullRange比VideoRange大一些，颜色也更丰富一些
     */
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
    //设置预设图像的分辨率
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

    
   AVCaptureDeviceDiscoverySession *deviceSession = [AVCaptureDeviceDiscoverySession discoverySessionWithDeviceTypes:@[AVCaptureDeviceTypeBuiltInWideAngleCamera]
                                                           mediaType:AVMediaTypeVideo position:position];
    //NSArray *devices = [AVCaptureDevice devicesWithMediaType:AVMediaTypeVideo];
    NSArray *devices = deviceSession.devices;
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
    runSyncOnVideoProcessingQueue(^{
        if ([self cameraPosition] == AVCaptureDevicePositionBack) {
            self->_inputTexRotation = kBLImageNoRotation;
        } else
        {
            self->_inputTexRotation = kBLImageFlipHorizontal;
        }
    });
}

- (AVCaptureDevicePosition)cameraPosition{
    return [[_captureInput device] position];
}


- (dispatch_queue_t)sampleBufferCallbackQueue{
    if (!_sampleBufferCallbackQueue) {
        _sampleBufferCallbackQueue = dispatch_queue_create("com.changba.sampleBufferCallQueue", DISPATCH_QUEUE_SERIAL);
    }
    return _sampleBufferCallbackQueue;
}

- (void)setFrameRate:(int)frameRate{
    _frameRate = frameRate;
    [self setFrameRate];
}

/**
 * Focus Modes 聚焦模式
 *
 * AVCaptureFocusModeLocked  焦点的位置是固定的
      当你想让用户组成一个场景，然后锁定焦点
 *
 * AVCaptureFocusModeAutoFocus  照相机做一次扫描聚焦，然后将焦点锁定
      这适合于，你想要选择一个特定的项目，即使它不是现场的中心，但可以专注于该项目的焦点
 *
 * AVCaptureFocusModelContinuousAutoFocus 相机需要不断的自动对焦
     
 */
- (void)setFrameRate{
    if (_frameRate > 0) {
        if ([[self captureInput].device respondsToSelector:@selector(setActiveVideoMinFrameDuration:)] &&
            [[self captureInput].device respondsToSelector:@selector(setActiveVideoMaxFrameDuration:)]) {
            NSError *error;
            [[self captureInput].device lockForConfiguration:&error];
            if (error == nil) {
#if defined(__IPHONE_7_0)
                //设置帧率
                [[self captureInput].device setActiveVideoMinFrameDuration:CMTimeMake(1, _frameRate)];
                [[self captureInput].device setActiveVideoMaxFrameDuration:CMTimeMake(1, _frameRate)];
                
                //对焦模式
                if ([[self captureInput].device isFocusModeSupported:AVCaptureFocusModeContinuousAutoFocus]) {
                    [[self captureInput].device setFocusMode:AVCaptureFocusModeContinuousAutoFocus];
                } else if ([[self captureInput].device isFocusModeSupported:AVCaptureFocusModeAutoFocus]) {
                    [[self captureInput].device setFocusMode:AVCaptureFocusModeAutoFocus];
                }
#endif
            }
            [[self captureInput].device unlockForConfiguration];
        }
        /*else {
            for (AVCaptureConnection *connection in [self captureOutput].connections) {
#pragma clang diagnostic push
#pragma clang diagnostic ignored "-Wdeprecated-declarations"
                if ([connection respondsToSelector:@selector(setVideoMinFrameDuration:)]) {
                    connection.videoMinFrameDuration = CMTimeMake(1, _frameRate);  //从i
                }
                if ([connection respondsToSelector:@selector(setVideoMaxFrameDuration:)]) {
                    connection.videoMaxFrameDuration = CMTimeMake(1, _frameRate);
                }
#pragma clang diagnostic pop
            }
        }*/
    } else {
        if ([[self captureInput].device respondsToSelector:@selector(setActiveVideoMinFrameDuration:)] &&
            [[self captureInput].device respondsToSelector:@selector(setActiveVideoMaxFrameDuration:)]) {
            NSError *error;
            [[self captureInput].device lockForConfiguration:&error];
            if (error == nil) {
#if defined(__IPHONE_7_0)
                //设置帧率
                [[self captureInput].device setActiveVideoMinFrameDuration:kCMTimeInvalid];
                [[self captureInput].device setActiveVideoMaxFrameDuration:kCMTimeInvalid];
                
                //对焦模式
                if ([[self captureInput].device isFocusModeSupported:AVCaptureFocusModeContinuousAutoFocus]) {
                    [[self captureInput].device setFocusMode:AVCaptureFocusModeContinuousAutoFocus];
                } else if ([[self captureInput].device isFocusModeSupported:AVCaptureFocusModeAutoFocus]) {
                    [[self captureInput].device setFocusMode:AVCaptureFocusModeAutoFocus];
                }
#endif
            }
            [[self captureInput].device unlockForConfiguration];
        }
        /*else {
            for (AVCaptureConnection *connection  in [self captureOutput].connections) {
#pragma clang diagnostic push
#pragma clang diagnostic ignored "-Wdeprecated-declarations"
                if ([connection respondsToSelector:@selector(setVideoMinFrameDuration:)]) {
                    connection.videoMinFrameDuration = kCMTimeInvalid;
                }
                if ([connection respondsToSelector:@selector(setVideoMaxFrameDuration:)]) {
                    connection.videoMaxFrameDuration = kCMTimeInvalid;
                }
#pragma clang diagnostic pop
            }
        }*/
    }
}

- (int32_t)frameRate{
    return _frameRate;
}

#pragma mark - AVCaptureVideoDataOuputSampleBufferDelegate
- (void)captureOutput:(AVCaptureOutput *)output didOutputSampleBuffer:(CMSampleBufferRef)sampleBuffer fromConnection:(AVCaptureConnection *)connection{
    if (self.shouldEnableOpenGL) { //是否进行OpenGL ES绘制
        if (dispatch_semaphore_wait(_frameRenderingSemaphore, DISPATCH_TIME_NOW) != 0) {
            return;
        }
        
        //手动把引用计数加1
        CFRetain(sampleBuffer);
        runAsyncOnVideoProcessingQueue(^{
            [self processVideoSampleBuffer:sampleBuffer];
            CFRelease(sampleBuffer); //手动把引用计数减1
            dispatch_semaphore_signal(self->_frameRenderingSemaphore);
        });
    }
}

//处理摄像头采集的图像数据
- (void)processVideoSampleBuffer:(CMSampleBufferRef)sampleBuffer{
    /**CVImageBufferRef
     * 对Core Video中图像缓冲区的引用
     * 根据网上一些资料，CVImageBufferRef 就是 CVPixelBufferRef的别名，从现在文档的定义来看是 "typedef CVBufferRef CVImageBufferRef"
     *
     * 图像缓冲区是一种抽象的类型，表示容纳图像的Core Video的缓冲区。在Core Video中，像素缓冲区(pixel buffers)、OpenGL缓冲区(OpenGL buffers)和OpenGL纹理(OpenGL textures)都是从图像缓冲区类型派生的。
     *
     */
    CVImageBufferRef cameraFrame = CMSampleBufferGetImageBuffer(sampleBuffer);
    //从CVPixelBuffer/CVImageBufferRef中获取颜色转换矩阵
    CFTypeRef colorAttachments = CVBufferGetAttachment(cameraFrame,
                                                       kCVImageBufferYCbCrMatrixKey, //此key最关键 kCVImageBufferYCbCrMatrixKey 颜色转换矩阵
                                                       NULL);
    //得到合适的颜色转换矩阵，为了提升性能，一般在Framgment Shader中进行YUV至RGB的转换， 在此根据不同的YUV格式进行相应的处理，比如Full Range或Video Range
    if (colorAttachments != NULL) {
        if (CFStringCompare(colorAttachments,
                            kCVImageBufferYCbCrMatrix_ITU_R_601_4, 0) == kCFCompareEqualTo) { //String 是否相等
            if (isFullYUVRange) {
                _preferredConversion = colorConversion601FullRange;
            } else {
                _preferredConversion = colorConversion601;
            }
        } else {
            _preferredConversion = colorConversion709;
        }
    } else {
        if (isFullYUVRange) {
            _preferredConversion = colorConversion601FullRange;
        } else {
            _preferredConversion = colorConversion601;
        }
    }
    
    [BLImageContext useImageProcessingContext];
    //帧缓冲
    [[self cameraFrameTextureWithSampleBuffer:sampleBuffer
                                 aspectRation:TEXTURE_FRAME_ASPECT_RATIO] activateFramebuffer]; //激活frameBuffer
    //绘制
    [_cameraLoadTexRenderer renderWithSampleBuffer:sampleBuffer
                                       aspectRatio:TEXTURE_FRAME_ASPECT_RATIO
                               preferredConversion:_preferredConversion
                                     imageRotation:_inputTexRotation];
    
    CMTime currentTime = CMSampleBufferGetPresentationTimeStamp(sampleBuffer);
    CMSampleTimingInfo timimgInfo = kCMTimingInfoInvalid;
    CMSampleBufferGetSampleTimingInfo(sampleBuffer,
                                      0,
                                      &timimgInfo);
    
    for (id<BLImageInput> currentTarget in targets) {
        [currentTarget setInputTexture:outputTexture];   //把outputTexture 传给target  而BLImageView就是target
        [currentTarget newFrameReadyAtTime:currentTime
                                timingInfo:timimgInfo];
    }
}

//创建帧缓冲，纹理，并把纹理附加到帧缓冲中
- (BLImageTextureFrame *)cameraFrameTextureWithSampleBuffer:(CMSampleBufferRef)sampleBuffer
                                               aspectRation:(float)aspectRation {
    if (!outputTexture) {
        CVImageBufferRef cameraFrame = CMSampleBufferGetImageBuffer(sampleBuffer);
        int bufferHeight = (int)CVPixelBufferGetHeight(cameraFrame);
        int targetWidth = bufferHeight / aspectRation;
        int targetHeight = bufferHeight;
        outputTexture = [[BLImageTextureFrame alloc] initWithSize:CGSizeMake(targetWidth, targetHeight)];
    }
    return outputTexture;
}

- (void)dealloc{
    [[NSNotificationCenter defaultCenter] removeObserver:self];
    
    if ([_captureSession isRunning]) {
        [_captureSession stopRunning];
    }
    [_captureOutput setSampleBufferDelegate:nil
                                      queue:dispatch_get_main_queue()];
    [self removeInputsAndOutputs];
}


- (void)removeInputsAndOutputs{
    [_captureSession beginConfiguration];
    if (_captureInput) {
        [_captureSession removeInput:_captureInput];
        [_captureSession removeOutput:_captureOutput];
        
        _captureOutput = nil;
        _captureInput = nil;
    }
    
    [_captureSession commitConfiguration];
}

@end
