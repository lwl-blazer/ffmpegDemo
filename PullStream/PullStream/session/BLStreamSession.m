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
     
     Cocoa(Foundation)中的流对象与Core Foundation中的流对象是对应的    可以通过toll-free桥接来相互转换
     NSStream  ----> CFStream
     NSInputStream  ----> CFReadSteam
     NSOutputSteam  ----> CFWriteStream
     两者间不是完全一样的，Core Foundation一般使用回调函数来处理数据。  而且Core Foundation中的流对象无法进行扩展   而Cocoa是可以进行扩展来自定义一些属性和行为
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
    _outputStream = (__bridge_transfer NSOutputStream *)writeStream; //如果NSOutputStream流对象写入数据到内存，则通过请求NSStreamDataWrittenToMemoryStreamKey属性来获取数据
    
    _inputStream.delegate = self;
    _outputStream.delegate = self;
    
    [_inputStream scheduleInRunLoop:[NSRunLoop mainRunLoop]
                            forMode:NSRunLoopCommonModes]; //在流对象放入run loop且有流事件(有可读数据)发生时，流对象会向代理发送stream:handleEvent:消息
    [_outputStream scheduleInRunLoop:[NSRunLoop mainRunLoop]
                             forMode:NSRunLoopCommonModes];  //如果不放入run loop 可以使用轮循处理数据，用hasSpaceAvailable来判断有没有数据 这样会阻塞当前线程
    
    [_inputStream open]; //打开流   在打开之前需要放入runloop中，这样做可以避免在没有数据可读时阻塞代理对象的操作
    [_outputStream open];
}

//流一旦打开，将会持续发送stream:handleEvent:消算给代理对象，直到流结束为止
- (void)stream:(NSStream *)aStream handleEvent:(NSStreamEvent)eventCode{
    /**
     * NSStreamEvent  -- 标识事件的类型
     * 对于NSInputStream对象，主要的事件类型包括NSStreamEventOpenCompleted, NSStreamEventHasBytesAvailable, NSStreamEventEndEncountered
     * 当NSInputStream在处理流的过程中出现错误时，它将停止流处理并产生一个NSStreamEventErrorOccurred事件给代理
     * 当NSInputStream读取到流的结尾时，会发送一个NSStreamEventEndEncountered事件，   应该销毁流对象
     
     * NSOutputStream
     * 如果NSOutputStream对象的目标是应用的内存时，在NSStreamEventEndEncountered事件中可能需要从内存中获取流中的数据，我们将调用NSOutputStream对象的propertyForKey:的属性，并指定Key为NSStreamDataWrittenToMemoryStreamKey来获取这些数据
     */
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
            _streamStatus |= NSStreamEventHasBytesAvailable; //7
            break;
        }
            
            
        case NSStreamEventHasSpaceAvailable:{
            NSLog(@"可以发送字节");
            _streamStatus |= NSStreamEventHasSpaceAvailable;   //5
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

//hasSpaceAvailable  在NSInputStream的时候表示是否有空间来写入数据   在NSOutputStream 可用空间供写入
- (NSData *)readData{
    uint8_t buff[4096]; //缓冲区
    NSUInteger len = [_inputStream read:buff maxLength:sizeof(buff)];  //读取数据
    NSData *data = nil;
    
    if (len < sizeof(buff) && (_streamStatus & NSStreamEventHasBytesAvailable)) {
        _streamStatus ^= NSStreamEventHasBytesAvailable; //按位异或(^)  相同为0 不同为1    _streamStatus = 5 移回去
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
        ret = [_outputStream write:data.bytes maxLength:data.length]; //写入数据
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
 iOS中流(Stream)
 
 流是在通信路径中串行传输的连续的比特位序列。从编码的角度来看，流是单向的。因此流可以是输入流或输出流。除了基于文件的流外，其它形式的流都是不可查找的，这些流的数据一旦消耗完后，就无法从对象中再次获取
 */



/**
 NSStream 是一个抽象基类,定义了所有流对象的基础接口和属性。
 
 NSInputStream和NSOutputStream继承自NSStream，实现了输入流和输出流的默认行为
 
 NSInputStream可以从文件、socket、NSData对象中获取数据
 NSOutputStream可以将数据写入文件、socket、内存缓存和NSData对象中
 
 流对象调用唯一的代理方法stream:handleEvent:来处理流相关的事件
 对于输入流来说，是有可用的数据可读取事件，我们可以使用read:maxLength:方法从流中获取数据
 对于输出流来说，是准备好写入的数据事件。我们可以使用write:maxLength:方法将数据写入流
 */
