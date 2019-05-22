//
//  BLStreamSession.m
//  PullStream
//
//  Created by luowailin on 2019/5/21.
//  Copyright © 2019 luowailin. All rights reserved.
//

#import "BLStreamSession.h"

@interface BLStreamSession () <NSStreamDelegate>

@property(nonatomic, strong) NSInputStream *inputStream;
@property(nonatomic, strong) NSOutputStream *outputStream;

@end


@implementation BLStreamSession

- (instancetype)init{
    self = [super init];
    if (self) {
        self.streamStatus = NSStreamEventNone;
    }
    return self;
}

- (void)dealloc{
    NSLog(@"%s", __func__);
    [self close];
}

- (void)connectToServer:(NSString *)host port:(UInt32)port{
    if (self.streamStatus > 0) {
        [self close];
    }
    
    /**
     Socket流
     在iOS中，NSStream类不支持连接到远程主机，但CFStream支持，可以通过toll-free桥接来相互转换，
     
     使用CFStream时，我们可以调用CFStreamCreatePairWithSocketToHost函数来传递主机名和端口号，来获取一个CFReadStreamRef和一个CFWriteStreamRef来进行通信，然后我们可以将它们转换为NSInputSteam和NSOutputStream对象来处理
     */
    
    CFReadStreamRef readStream;  //输入流 用来读取数据
    CFWriteStreamRef writeStream;  //输出流 用来发送数据
    
    if (port <= 0) {
        port = 1935; //RTMP默认端口是1935
    }
    
    CFStreamCreatePairWithSocketToHost(NULL,
                                       (__bridge CFStringRef)host,
                                       port,
                                       &readStream,
                                       &writeStream); //建立Socket连接
    
    //注意 __bridge_transfer 转移对象的内存管理权
    _inputStream = (__bridge_transfer NSInputStream *)readStream;
    _outputStream = (__bridge_transfer NSOutputStream *)writeStream;
    
    _inputStream.delegate = self;
    _outputStream.delegate = self;
    
    [_outputStream scheduleInRunLoop:[NSRunLoop mainRunLoop]
                             forMode:NSRunLoopCommonModes];
    [_inputStream scheduleInRunLoop:[NSRunLoop mainRunLoop]
                            forMode:NSRunLoopCommonModes];
    
    [_inputStream open];
    [_outputStream open];
}

- (void)stream:(NSStream *)aStream handleEvent:(NSStreamEvent)eventCode{
    switch (eventCode) {
        case NSStreamEventNone:
            return;
        
        case NSStreamEventOpenCompleted:{
            if (_inputStream == aStream) {
                NSLog(@"连接成功");
                _streamStatus = NSStreamEventOpenCompleted;
            }
            break;
        }
            
        case NSStreamEventHasBytesAvailable:{
            NSLog(@"有字节可读");
            _streamStatus |= NSStreamEventHasBytesAvailable;
            break;
        }
            
        case NSStreamEventHasSpaceAvailable:{
            NSLog(@"可以发送字节");
            _streamStatus |= NSStreamEventHasSpaceAvailable;
            break;
        }
            
        case NSStreamEventErrorOccurred:{
            NSLog(@"连接出现错误");
            _streamStatus = NSStreamEventErrorOccurred;
            
            NSError *theError = [aStream streamError];
            NSLog(@"error =====   %@",[NSString stringWithFormat:@"Error %li: %@",
                                       (long)[theError code], [theError localizedDescription]]);
            break;
        }
        case NSStreamEventEndEncountered:{
            NSLog(@"连接结束");
            _streamStatus = NSStreamEventEndEncountered;
            NSError *theError = [aStream streamError];
            NSLog(@"error =====   %@",[NSString stringWithFormat:@"Error %li: %@",
                                       (long)[theError code], [theError localizedDescription]]);
            break;
        }
    }
    
    if (self.delegate && [self.delegate respondsToSelector:@selector(streamSession:didChangeStatus:)]) {
        [self.delegate streamSession:self didChangeStatus:_streamStatus];
    }
}

- (void)disConnect{
    [self close];
}

- (void)close{
    [_inputStream close];
    [_outputStream close];
    
    [_inputStream removeFromRunLoop:[NSRunLoop currentRunLoop] forMode:NSRunLoopCommonModes];
    [_outputStream removeFromRunLoop:[NSRunLoop currentRunLoop] forMode:NSRunLoopCommonModes];
    
    _streamStatus = NSStreamEventNone;
    _inputStream.delegate = nil;
    _outputStream.delegate = nil;
    
    _outputStream = nil;
    _inputStream = nil;
}

- (NSData *)readData{
    uint8_t buff[4096]; //缓冲区
    NSUInteger len = [_inputStream read:buff maxLength:sizeof(buff)];
    NSData *data = nil;
    
    if (len < sizeof(buff) && (_streamStatus & NSStreamEventHasBytesAvailable)) {
        _streamStatus ^= NSStreamEventHasBytesAvailable; //按位异或(^)  相同为0 不同为1
        data = [NSData dataWithBytes:buff length:len];
    }
    
    return data;
}

- (NSInteger)writeData:(NSData *)data{
    if (data.length == 0) {
        return 0;
    }
    
    NSInteger ret = 0;
    if (_outputStream.hasSpaceAvailable) {
        ret = [_outputStream write:data.bytes maxLength:data.length];
    }
    
    if (ret > 0 && (_streamStatus & NSStreamEventHasBytesAvailable)) {
        _streamStatus ^= NSStreamEventHasBytesAvailable; //移除标志位
    }
    
    if (ret == -1) {
        NSLog(@"xxxxxxx");
    }
    return ret;
}

@end

/**
 NSStream 是一个抽象基类,定义了所有流对象的基础接口和属性。
 
 NSInputStream和NSOutputStream继承自NSStream，实现了输入流和输出流的默认行为
 
 NSInputStream可以从文件、socket、NSData对象中获取数据
 NSOutputStream可以将数据写入文件、socket、内存缓存和NSData对象中
 
 流对象调用唯一的代理方法stream:handleEvent:来处理流相关的事件
 对于输入流来说，是有可用的数据可读取事件，我们可以使用read:maxLength:方法从流中获取数据
 对于输出流来说，是准备好写入的数据事件。我们可以使用write:maxLength:方法将数据写入流
 */
