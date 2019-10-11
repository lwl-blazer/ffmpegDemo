//
//  AVSynchronizer.m
//  Advance-video-play
//
//  Created by luowailin on 2019/9/11.
//  Copyright © 2019 luowailin. All rights reserved.
//

#import "AVSynchronizer.h"
#import "VideoToolboxDecoder.h"
#import <UIKit/UIDevice.h>
#import <pthread.h>

#define LOCAL_MIN_BUFFERED_DURATION 0.5
#define LOCAL_MAX_BUFFERED_DURATION 1.0
#define NETWORK_MIN_BUFFERED_DURATION 2.0
#define NETWORK_MAX_BUFFERED_DURATION 4.0
#define LOCAL_AV_SYNC_MAX_TIME_DIFF  0.05
#define FIRST_BUFFER_DURATION 0.5

NSString *const kMIN_BUFFERED_DURATION = @"Min_Buffered_Duration";
NSString *const kMAX_BUFFERED_DURATION = @"Max_Buffered_Duration";

@interface AVSynchronizer (){
    VideoDecoder *_decoder;
    BOOL _usingHWCodec;
    BOOL isOnDecoding;
    BOOL isInitializeDecodeThread;
    BOOL isDestroyed;
    
    BOOL isFirstScreen;
    
    /** 解码第一段buffer的控制变量 */
    pthread_mutex_t decodeFirstBufferLock;
    pthread_cond_t decodeFirstBufferCondition;
    pthread_t decodeFirstBufferThread;
    /** 是否正在解码第一段buffer */
    BOOL isDecodingFirstBuffer;
    
    pthread_mutex_t videoDecoderLock;
    pthread_cond_t videoDecoderCondition;
    pthread_t videoDecoderThread;
    
    NSMutableArray *_videoFrames;
    NSMutableArray *_audioFrames;
    
    /** 分别是当外界需要音频数据和视频数据的时候，全局变量缓存数据**/
    NSData *_currentAudioFrame;
    NSUInteger _currentAudioFramePos;
    CGFloat _audioPosition;
    VideoFrame *_currentVideoFrame;
    
    /** 控制何时该解码 */
    BOOL _buffered;
    CGFloat _bufferedDuration;
    CGFloat _minBufferedDuration;
    CGFloat _maxBufferedDuration;
    
    CGFloat _syncMaxTimeDiff;
    NSInteger _firstBufferDuration;
    
    BOOL _completion;
    
    NSTimeInterval _bufferedBeginTime;
    NSTimeInterval _bufferedTotalTime;
    
    int _decodeVideoErrorState;
    NSTimeInterval _decodeVideoErrorBeginTime;
    NSTimeInterval _decodeVideoErrorTotalTime;
    
}

@end


@implementation AVSynchronizer

static BOOL isNetworkPath(NSString *path){
    
    NSRange r = [path rangeOfString:@":"];
    if (r.location == NSNotFound) {
        return NO;
    }
    
    NSString *scheme = [path substringToIndex:r.length];
    if ([scheme isEqualToString:@"file"]) {
        return NO;
    }
    return YES;
}

//开始跑第一次解码程
static void *decodeFirstBufferRunLoop(void *ptr){
    AVSynchronizer *synchronizer = (__bridge AVSynchronizer *)ptr;
    [synchronizer decodeFirstBuffer];
    return NULL;
}

- (void)decodeFirstBuffer{ /** decodeFirstBufferThread线程 */
    double startDecodeFirstBufferTimeMills = CFAbsoluteTimeGetCurrent() * 1000;
    [self decodeFrameWithDuration:FIRST_BUFFER_DURATION];
    int wasteTimeMills = CFAbsoluteTimeGetCurrent() * 1000 - startDecodeFirstBufferTimeMills;
    NSLog(@"Decode First Buffer waste TimeMills is %d", wasteTimeMills);
    
    pthread_mutex_lock(&decodeFirstBufferLock);
    pthread_cond_signal(&decodeFirstBufferCondition);
    pthread_mutex_unlock(&decodeFirstBufferLock);
    
    isDecodingFirstBuffer = false; //找到
}


//开始跑解码线程
static void *runDecoderThread(void *ptr){
    AVSynchronizer *synchronizer = (__bridge AVSynchronizer *)ptr;
    [synchronizer run];
    return NULL;
}

- (void)run{
    while (isOnDecoding) {
        pthread_mutex_lock(&videoDecoderLock);
        pthread_cond_wait(&videoDecoderCondition, &videoDecoderLock); //等待 decodeFirstBufferThread 解码完成发送signal信号 和 signalDecoderThread方法的发送signal信号
        pthread_mutex_unlock(&videoDecoderLock);
        [self decodeFrames];
        /** 线程1
         * videoDecoderThread & videoDecoderLock & videoDecoderCondition
         * 即为播放器的后台解码分配的一个线程
         * 工作内容:
         * 用于解析协议，处理解封装以及解码，并最终将裸数据放到音频和视频的队列中，这个模块为输入模块
         */
    }
}

- (void)decodeFrameWithDuration:(CGFloat)duration{
    BOOL good = YES;
    while (good) {
        good = NO;
        @autoreleasepool {
            if (_decoder && (_decoder.validVideo || _decoder.validAudio)) {
                int tmpDecodeVideoErrorState;
                NSArray *frames = [_decoder decodeFrames:0.0f
                                   decodeVideoErrorState:&tmpDecodeVideoErrorState];
                
                if (frames.count) {
                    good = [self addFrames:frames duration:duration];
                }
            }
        }
    }
}

//主要负责解码音视频压缩数据成为原始数据，并且封装成自定义的结构体，最终全部放到一个数组中，然后返回给调用端
- (void)decodeFrames{ /**videoDecoderThread线程中执行的代码*/
    const CGFloat duration = 0.0f;
    BOOL good = YES;
    while (good) {
        good = NO;
        @autoreleasepool {
            if (_decoder &&(_decoder.validAudio || _decoder.validVideo)) {
                NSArray *frames = [_decoder decodeFrames:duration
                                   decodeVideoErrorState:&_decodeVideoErrorState];
                if (frames.count) {
                    good = [self addFrames:frames duration:_maxBufferedDuration];
                }
            }
        }
    }
}

- (BOOL)addFrames:(NSArray *)frames duration:(CGFloat)duration{/**videoDecoderThread线程*/
    
    /** @synchronized()
     * @synchronized(obj){}指令是使用的obj为该锁的唯一标识，禁止同一时间不同的线程同时访问obj对象。但只能当标识相同的时候才为满足互斥。就是说下面的代码会同时执行，因为标识不一样(_videoFrames和_audioFrames)
     *
     * 优点:
     我们不需要在代码中显式创建锁对象，便可以实现锁的机制
     *
     * 缺点:
     但作为一种预防措施，@synchronized()块会隐式的添加一个异常处理例程来保护代码，该处理例程会在异常抛出的时候自动的释放互斥锁。所以如果不想让隐式的异常处理例程序带来额外的开销，可以考虑使用锁对象
     */
    if (_decoder.validVideo) {
        @synchronized (_videoFrames) {
            for (Frame *frame in frames) {
                if (frame.type == VideoFrameType || frame.type == iOSCVVideoFrameType) {
                    [_videoFrames addObject:frame];
                }
            }
        }
    }
    
    
    if (_decoder.validAudio) {
        @synchronized (_audioFrames) {
            for (Frame *frame in frames) {
                if (frame.type == AudioFrameType) {
                    [_audioFrames addObject:frame];
                    _bufferedDuration += frame.duration;
                }
            }
        }
    }
    
    return _bufferedDuration < duration;
}



- (id)initWithPlayerStateDelegate:(id<PlayerStateDelegate>)playerStateDelegate{
    self = [super init];
    if (self) {
        _playerStateDelegate = playerStateDelegate;
    }
    return self;
}

//给 videoDecoderLock的锁发送 signal信号 再时行run
- (void)signalDecoderThread{
    if (NULL == _decoder || isDestroyed) {
        return;
    }
    
    if (!isDestroyed) {
        pthread_mutex_lock(&videoDecoderLock);
        pthread_cond_signal(&videoDecoderCondition);
        pthread_mutex_unlock(&videoDecoderLock);
    }
}

- (OpenState)openFile:(NSString *)path
         usingHWCodec:(BOOL)usingHWCodec
                error:(NSError * _Nullable __autoreleasing *)perror{
    NSMutableDictionary *parameters = [NSMutableDictionary dictionary];
    parameters[FPS_PROBE_SIZE_CONFIGURED] = @(true);
    parameters[PROBE_SIZE] = @(50 * 1024);
    
    NSMutableArray *durations = [NSMutableArray array];
    durations[0] = @(1250000);
    durations[1] = @(1750000);
    durations[2] = @(2000000);
    parameters[MAX_ANALYZE_DURATION_ARRAY] = durations;
    return [self openFile:path
             usingHWCodec:usingHWCodec
               parameters:parameters
                    error:perror];
}

- (BOOL)usingHWCodec{
    return _usingHWCodec;
}

- (OpenState)openFile:(NSString *)path
         usingHWCodec:(BOOL)usingHWCodec
           parameters:(NSDictionary *)parameters
                error:(NSError * _Nullable __autoreleasing *)perror{
    //1.创建decoder实例
    _usingHWCodec = usingHWCodec;
    [self createDecoderInstance];
    
    //2.初始化成员变量
    _currentVideoFrame = NULL;
    _currentAudioFramePos = 0;
    
    _bufferedBeginTime = 0;
    _bufferedTotalTime = 0;
    
    _decodeVideoErrorBeginTime = 0;
    _decodeVideoErrorTotalTime = 0;
    isFirstScreen = YES;
    
    _minBufferedDuration = [parameters[kMIN_BUFFERED_DURATION] floatValue];
    _maxBufferedDuration = [parameters[kMAX_BUFFERED_DURATION] floatValue];
    
    BOOL isNetwork = isNetworkPath(path);
    if (ABS(_minBufferedDuration - 0.f) < CGFLOAT_MIN) {
        if (isNetwork) {
            _minBufferedDuration = NETWORK_MIN_BUFFERED_DURATION;
        } else {
            _minBufferedDuration = LOCAL_MIN_BUFFERED_DURATION;
        }
    }
    
    if ((ABS(_maxBufferedDuration - 0.f) < CGFLOAT_MIN)) {
        if (isNetwork) {
            _maxBufferedDuration = NETWORK_MAX_BUFFERED_DURATION;
        } else {
            _maxBufferedDuration = LOCAL_MAX_BUFFERED_DURATION;
        }
    }
    
    if (_minBufferedDuration > _maxBufferedDuration) {
        float temp = _minBufferedDuration;
        _minBufferedDuration = _maxBufferedDuration;
        _maxBufferedDuration = temp;
    }
    
    _syncMaxTimeDiff = LOCAL_AV_SYNC_MAX_TIME_DIFF;
    _firstBufferDuration = FIRST_BUFFER_DURATION;
    
    //3.打开流并且解析出来音视频流的Context
    BOOL openCode = [_decoder openFile:path parameter:parameters error:perror];
    if (!openCode || ![_decoder isSubscribed] || isDestroyed) {
        [self closeDecoder];
        return [_decoder isSubscribed] ? OPEN_FAILED : CLIENT_CANCEL;
    }
    
    //4.回调客户端视频宽高以及duration
    NSUInteger videoWidth = [_decoder frameWidth];
    NSUInteger videoHeight = [_decoder frameHeight];
    if (videoWidth <= 0 || videoHeight <= 0) {
        return [_decoder isSubscribed] ? OPEN_FAILED : CLIENT_CANCEL;
    }
    
    //5.开启解码线程和解码队列
    _audioFrames = [NSMutableArray array];
    _videoFrames = [NSMutableArray array];
    
    [self startDecoderThread];
    [self startDecodeFirstBufferThread];
    return OPEN_SUCCESS;
}

- (void)createDecoderInstance{
    if (_usingHWCodec) {
        _decoder = [[VideoToolboxDecoder alloc] init];
    } else {
        _decoder = [[VideoDecoder alloc] init];
    }
}

- (void)startDecodeFirstBufferThread{
    //初始化线程， 互斥锁，条件变量
    pthread_mutex_init(&decodeFirstBufferLock, NULL);
    pthread_cond_init(&decodeFirstBufferCondition, NULL);
    isDecodingFirstBuffer = true;
    pthread_create(&decodeFirstBufferThread, NULL, decodeFirstBufferRunLoop, (__bridge void *)self);
}

- (void)startDecoderThread{
    NSLog(@"AVSynchronizer::startDecoderThread ...");
    isOnDecoding = true;
    isDestroyed = false;
    
    //初始化线程，互斥锁，条件变量
    pthread_mutex_init(&videoDecoderLock, NULL);
    pthread_cond_init(&videoDecoderCondition, NULL);
    isInitializeDecodeThread = true;
    //参数1:返回最后创建线程的id  参数2:指定线程的属性(detach state, 是否joinable, cancel state, cancel type) 参数3:线程函数指针 参数4:传给线程函数的参数
    pthread_create(&videoDecoderThread, NULL, runDecoderThread, (__bridge void *)self);
}


#pragma mark -- 音视频同步
static int count = 0;
static int invalidGetCount = 0;
float lastPosition = -1.0;

- (VideoFrame *)getCorrectVideoFrame{
    VideoFrame *frame = NULL;
    @synchronized (_videoFrames) {
        while (_videoFrames.count > 0) {
            frame = _videoFrames[0];
            const CGFloat delta = _audioPosition - frame.position;
            if (delta < (0 - _syncMaxTimeDiff)) {
                //NSLog(@"视频比音频快了好多,我们还是渲染上一帧");
                frame = NULL;
                break;
            }
            [_videoFrames removeObjectAtIndex:0];
            if (delta > _syncMaxTimeDiff) {
                //NSLog(@"视频比音频慢了好多,我们需要继续从queue拿到合适的帧 _audioPosition is %.3f frame.position %.3f", _audioPosition, frame.position);
                frame = NULL;
                continue;
            } else {
                break;
            }
        }
    }
    if (frame) {
        if (isFirstScreen) {
            [_decoder triggerFirstScreen];
            isFirstScreen = NO;
        }
        
        if (NULL != _currentVideoFrame) {
            _currentVideoFrame = NULL;
        }
        _currentVideoFrame = frame;
    } else {
        //NSLog(@"Frame is NULL");
    }
    
    if (fabs(_currentVideoFrame.position - lastPosition) > 0.01f) {
        lastPosition = _currentVideoFrame.position;
        count ++;
        return _currentVideoFrame;
    } else {
        invalidGetCount ++;
        return nil;
    }
}

- (void)audioCallbackFillData:(SInt16 *)outData
                    numFrames:(UInt32)numFrames
                  numChannels:(UInt32)numChannels{ /**
                                                    AURemoteIO::IOThread中  是Audio Unit的工作线程*/
    [self checkPlayState];
    if (_buffered) {
        memset(outData, 0, numFrames * numChannels * sizeof(SInt16));
        return;
    }
    
    @autoreleasepool {
        while (numFrames > 0) {
            if (!_currentAudioFrame) { //如果当前没有音频帧或已经拷完了，
                //从队列中取出音频数据
                @synchronized (_audioFrames) {
                    NSUInteger count = _audioFrames.count;
                    if (count > 0) {
                        AudioFrame *frame = _audioFrames[0];
                        _bufferedDuration -= frame.duration;
                        
                        [_audioFrames removeObjectAtIndex:0];
                        _audioPosition = frame.position;
                        
                        _currentAudioFramePos = 0;
                        _currentAudioFrame = frame.samples;
                    }
                }
            }
            
            if (_currentAudioFrame) {
                //数据的移位 +意思是向右移_currentAudioFramePos位
                const void *bytes = (Byte *)_currentAudioFrame.bytes + _currentAudioFramePos;
                
                //本次拷贝起点的位置
                const NSUInteger bytesLeft = (_currentAudioFrame.length - _currentAudioFramePos);
                //一帧的大小  根据声道
                const NSUInteger frameSizeOf = numChannels * sizeof(SInt16);
                //本次需要copy的size
                const NSUInteger bytesToCopy = MIN(numFrames * frameSizeOf, bytesLeft);
                //本次能copy多少帧
                const NSUInteger framesToCopy = bytesToCopy / frameSizeOf;
                
                memcpy(outData, bytes, bytesToCopy);
                
                //本次循环已经拷了多少帧,还剩多少针
                numFrames -= framesToCopy;
                outData += framesToCopy * numChannels;
                
                if (bytesToCopy < bytesLeft) { //当前的_currentAudioFrame 还没有拷完
                    _currentAudioFramePos += bytesToCopy;
                } else { //已经拷完
                    _currentAudioFrame = nil;
                }
            } else {
                memset(outData, 0, numFrames * numChannels *sizeof(SInt16));
                break;
            }
        }
    }
}

- (void)checkPlayState{
    if (NULL == _decoder) {
        return;
    }
    
    if (_buffered && (_bufferedDuration > _minBufferedDuration)) {
        _buffered = NO;
        if (_playerStateDelegate && [_playerStateDelegate respondsToSelector:@selector(hideLoading)]) {
            [_playerStateDelegate hideLoading];
        }
    }
    
    if (1 == _decodeVideoErrorState) {
        _decodeVideoErrorState = 0;
        if (_minBufferedDuration > 0 && !_buffered) {
            _buffered = YES;
            _decodeVideoErrorBeginTime = [[NSDate date] timeIntervalSince1970];
        }
        
        _decodeVideoErrorTotalTime = [[NSDate date] timeIntervalSince1970] - _decodeVideoErrorBeginTime;
        if (_decodeVideoErrorTotalTime > TIMEOUT_DECODE_ERROR) {
            NSLog(@"decodeVideoErrorTotalTime = %f", _decodeVideoErrorTotalTime);
            _decodeVideoErrorTotalTime = 0;
            __weak typeof(self) weakSelf = self;
            dispatch_async(dispatch_get_main_queue(), ^{
                __strong typeof(weakSelf) strongify = weakSelf;
               NSLog(@"restart after decodeVideoError");
                if (strongify->_playerStateDelegate && [strongify->_playerStateDelegate respondsToSelector:@selector(restart)]) {
                    [strongify->_playerStateDelegate restart];
                }
            });
        }
        return;
    }
    
    const NSUInteger leftVideoFrames = _decoder.validVideo ? _videoFrames.count : 0;
    const NSUInteger leftAudioFrames = _decoder.validAudio ? _audioFrames.count : 0;
    
    if (leftVideoFrames == 0 || leftAudioFrames == 0) {
        [_decoder addBufferStatusRecord:@"E"];
        if (_minBufferedDuration > 0 && !_buffered) {
            _buffered = YES;
            _bufferedBeginTime = [[NSDate date] timeIntervalSince1970];
            if (_playerStateDelegate && [_playerStateDelegate respondsToSelector:@selector(showLoading)]) {
                [_playerStateDelegate showLoading];
            }
        }
        
        if ([_decoder isEOF]) {
            if (_playerStateDelegate && [_playerStateDelegate respondsToSelector:@selector(onCompletion)]) {
                _completion = YES;
                [_playerStateDelegate onCompletion];
            }
        }
    }
    
    if (_buffered) {
        _bufferedTotalTime = [[NSDate date] timeIntervalSince1970] - _bufferedBeginTime;
        if (_bufferedTotalTime > TIMEOUT_BUFFER) {
            _bufferedTotalTime = 0;
            __weak typeof(self) weakSelf = self;
            dispatch_async(dispatch_get_main_queue(), ^{
#ifdef DEBUG
                NSLog(@"AVSynchronizer restart after timeout");
#endif
                if (weakSelf.playerStateDelegate && [weakSelf.playerStateDelegate respondsToSelector:@selector(restart)]) {
                    NSLog(@"=============================== AVSynchronizer restart");
                    [weakSelf.playerStateDelegate restart];
                }
            });
            return;
        }
    }
    
    if (!isDecodingFirstBuffer && (0 == leftVideoFrames || 0 == leftAudioFrames || !(_bufferedDuration > _minBufferedDuration))) {
#ifdef DEBUG
        NSLog(@"AVSynchronizer _bufferedDuration is %.3f _minBufferedDuration is %.3f", _bufferedDuration, _minBufferedDuration);
#endif
        [self signalDecoderThread];
    } else if (_bufferedDuration >= _maxBufferedDuration) {
        [_decoder addBufferStatusRecord:@"F"];
    }
}

#pragma mark -- 销毁操作相关
- (void)closeFile{
    if (_decoder) {
        [_decoder interrupt];
    }
    
    [self destroyDecodeFirstBufferThread];
    [self destroyDecodeThread];
    if ([_decoder isOpenInputSuccess]) {
        [self closeDecoder];
    }
    
    @synchronized (_videoFrames) {
        [_videoFrames removeAllObjects];
    }
    
    @synchronized (_audioFrames) {
        [_audioFrames removeAllObjects];
        _currentAudioFrame = nil;
    }
    NSLog(@"present diff video frame cnt is %d invalidGetCount is %d", count, invalidGetCount);
}

- (void)closeDecoder{
    if (_decoder) {
        [_decoder closeFile];
        if (_playerStateDelegate && [_playerStateDelegate respondsToSelector:@selector(buriedPointCallback:)]) {
            [_playerStateDelegate buriedPointCallback:[_decoder getBuriedPoint]];
        }
        _decoder = nil;
    }
}

- (void)destroyDecodeFirstBufferThread{
    if (isDecodingFirstBuffer) {
        NSLog(@"Begin Wait Decode First Buffer...");
        double startWaitDecodeFirstBufferTimeMills = CFAbsoluteTimeGetCurrent() * 1000;
        pthread_mutex_lock(&decodeFirstBufferLock);
        pthread_cond_wait(&decodeFirstBufferCondition, &decodeFirstBufferLock); //必须等到 decodeFirstBufferCondition 发送signal信号
        pthread_mutex_unlock(&decodeFirstBufferLock);
        
        pthread_cond_destroy(&decodeFirstBufferCondition);
        pthread_mutex_destroy(&decodeFirstBufferLock);
        
        int wasteTimeMills = CFAbsoluteTimeGetCurrent() * 1000 - startWaitDecodeFirstBufferTimeMills;
        NSLog(@" Wait Decode First Buffer waste TimeMills is %d", wasteTimeMills);
    }
}

- (void)destroyDecodeThread{
    NSLog(@"AVSynchronizer::destroyDecoderThread ...");

    isDestroyed = true;
    isOnDecoding = false;
    if (!isInitializeDecodeThread) {
        return;
    }
    
    void *status;
    pthread_mutex_lock(&videoDecoderLock);
    pthread_cond_signal(&videoDecoderCondition);
    pthread_mutex_unlock(&videoDecoderLock);
    
    /** 阻塞是线程之间同步的一种方法
     * pthread_join(pthread_t threadid, void **value_ptr)  函数会让调用它的线程等待threadid线程运行结束之后再运行， value_ptr存放了其它线程的返回值。
     */
    pthread_join(videoDecoderThread, &status);
    pthread_mutex_destroy(&videoDecoderLock);
    pthread_cond_destroy(&videoDecoderCondition);
}

#pragma mark -- Get
- (BOOL)isOpenInputSuccess{
    BOOL ret = NO;
    if (_decoder) {
        ret = [_decoder isOpenInputSuccess];
    }
    return ret;
}

- (void)interrupt{
    if (_decoder) {
        [_decoder interrupt];
    }
}

- (BOOL)isPlayCompleted{
    return _completion;
}

- (NSInteger)getAudioSampleRate{
    if (_decoder) {
        return [_decoder sampleRate];
    }
    return -1;
}

- (NSInteger)getAudioChannels{
    if (_decoder) {
        return [_decoder channels];
    }
    return -1;
}


- (CGFloat)getVideoFPS{
    if (_decoder) {
        return [_decoder getVideoFPS];
    }
    return 0.0f;
}

- (NSInteger)getVideoFrameHeight{
    if (_decoder) {
        return [_decoder frameHeight];
    }
    return 0;
}

- (NSInteger)getVideoFrameWidth{
    if (_decoder) {
        return [_decoder frameWidth];
    }
    return 0;
}

- (BOOL)isValid{
    if (_decoder && ![_decoder validVideo] && ![_decoder validAudio]) {
        return NO;
    }
    return YES;
}

- (CGFloat)getDuration{
    if (_decoder) {
        return [_decoder getDuration];
    }
    return 0.0f;
}



@end


/**
 * autoreleasepool{} 在ARC环境下使用作用;
 * 主线程或者GCD机制中的线程，这些线程默认都有Autorelease Pool,每次执行Event Loop时，就会将其清空。因此，不需要自己来创建。
 *
 * 每一个线程都会维护自己的Autorelease Pool堆栈。换句话说Autorelease Pool是与线程紧密相关的，每个Autorelease Pool只对应一个线程
 *
 * 对于每个RunLoop，系统会隐式创建一个Autorelease pool,这样所有的release pool会构成一个像Call stack一样的栈式结构，在每一个RunLoop结束的时候，当前栈顶的Autorelease Pool会被销毁，这样这个pool里所有的对象都会被release掉
 *
 * 使用场景:
     1.你编写是命令行工具的代码，而不是基于UI框架的代码
     2.你需要写一个循环，里面会创建很多临时对象
          .这时候你可以在循环内部的代码块里使用一个@autoreleasePool{} 这样这些对象就能在一次迭代完成后被释放掉。这种方式可以降低内存最大占用
     3.当你大量使用辅助线程
          .你需要在线程的任务代码中创建自己的@autoreleasePool{}
     4.长时间在后台运行的任务
     5.创建了新的线程 (非Cocoa程序创建线程时才需要)
 *
 * 要点:
     1.Autorelease Pool 排布在栈中，对象收到autorelease消息后，系统将其放入最顶端的池里
     2.合理运用Autorelease Pool 可降低应用程序的内存峰值
 *
 * 问题:
 *   1.Autorelease对象什么时候释放？
        在没有手加Autorelease Pool的情况下，Autorelease对象是在当前的runloop迭代结束时释放的，而它能够释放的原因是系统在每个runloop迭代中都加入了自动释放池Push和Pop
 */



