//
//  BLRtmpSession.m
//  PullStream
//
//  Created by luowailin on 2019/5/21.
//  Copyright © 2019 luowailin. All rights reserved.
//

#import "BLRtmpSession.h"
#import "BLStreamSession.h"
#import "NSMutableData+Buffer.h"
#import "BLTypeHeader.h"
#import "NSString+Url.h"
#import "BLRtmpConfig.h"

static const size_t kRtmpSignatureSize = 1536;

@interface BLRtmpSession () <BLStreamSessionDelegate>
{
    dispatch_queue_t _pacekageQueue;
    dispatch_queue_t _sendQueue;
    
    
    int _outChunkSize;
    int _inChunkSize;
    int _streamID;
    int _numOfInvokes;
}

@property(nonatomic, strong) BLStreamSession *streamSession;
@property(nonatomic, assign) LLYRtmpSessionStatus rtmpStatus;

@property(nonatomic, strong) NSMutableData *handShake;
@property(nonatomic, strong) NSMutableDictionary *preChunk;
@property(nonatomic, strong) NSMutableDictionary<NSNumber *, NSString *>*trackedCommands;

@end


@implementation BLRtmpSession

- (void)dealloc{
    NSLog(@"%s", __func__);
    [self sendDeleteStream];
    
    
    self.url = @"";
    self.delegate = nil;
    self.streamSession.delegate = nil;
    self.streamSession = nil;
    
    _pacekageQueue = nil;
    _sendQueue = nil;
    
    _rtmpStatus = LLYRtmpSessionStatusNone;
    
    _numOfInvokes = 0;
    
    [_preChunk removeAllObjects];
    [_trackedCommands removeAllObjects];
}

- (void)sendDeleteStream{
    RTMPChunk_0 metadata = {0};
    metadata.msg_stream_id = LLYStreamIDInvoke;
    metadata.msg_type_id = LLYMSGTypeID_INVOKE;
    
    NSMutableData *buff = [NSMutableData data];
    [buff appendString:@"deleteStream"];
    [buff appendDouble:++_numOfInvokes];
    
    self.trackedCommands[@(_numOfInvokes)] = @"deleteStream";
    
    [buff appendByte:kAMFNull];
    [buff appendDouble:_streamID];
    
    metadata.msg_length.data = (int)buff.length;
    [self sendPacket:buff :metadata];
}

- (void)sendPacket:(NSData *)data :(RTMPChunk_0)metadata{
    BLFrame *frame = [[BLFrame alloc] init];
    
    frame.data = data;
    frame.timestamp = metadata.timestamp.data;
    frame.msgLength = metadata.msg_length.data;
    frame.msgTypeId = metadata.msg_type_id;
    frame.msgStreamId = metadata.msg_stream_id;
    
    [self sendBuffer:frame];
}

- (instancetype)init
{
    self = [super init];
    if (self) {
        _rtmpStatus = LLYRtmpSessionStatusNone;
        _pacekageQueue = dispatch_queue_create("packet", 0);
        _sendQueue = dispatch_queue_create("send", 0);
        
        _outChunkSize = 128;
        _inChunkSize = 128;
    }
    return self;
}

- (void)connect{
    [self.streamSession connectToServer:self.url.host port:self.url.port];
}

- (void)disConnect{
    [self reset];
    [self.streamSession disConnect];
}

- (void)reset{
    
    self.handShake = nil;
    self.preChunk = nil;
    self.trackedCommands = nil;
    _streamID = 0;
    _numOfInvokes = 0;
    
    _outChunkSize = 128;
    _inChunkSize = 128;
    
    self.rtmpStatus = LLYRtmpSessionStatusNone;
}

#pragma mark -- delegate

- (void)streamSession:(BLStreamSession *)session didChangeStatus:(BLStreamStatus)streamStatus{

    if (streamStatus & NSStreamEventHasBytesAvailable) {
        [self didReceivedata];
        return;
    }
    
    if (streamStatus & NSStreamEventHasSpaceAvailable) {
        if (_rtmpStatus == LLYRtmpSessionStatusConnected) {
            [self handshake0];
        }
        return;
    }
    
    if ((streamStatus & NSStreamEventOpenCompleted) && (_rtmpStatus < LLYRtmpSessionStatusConnected)) {
        self.rtmpStatus = LLYRtmpSessionStatusConnected;
    }
    
    
    if (streamStatus & NSStreamEventErrorOccurred) {
        self.rtmpStatus = LLYRtmpSessionStatusError;
    }
    
    if (streamStatus & NSStreamEventEndEncountered) {
        self.rtmpStatus = LLYRtmpSessionStatusNotConnected;
    }
}

- (void)handshake0{
    //c0
    char c0Byte = 0x03;  //rtmp版本号
    NSData *c0 = [NSData dataWithBytes:&c0Byte length:1];
    [self writeData:c0];
    
    //c1
    uint8_t *c1Bytes = (uint8_t *)malloc(kRtmpSignatureSize);
    memset(c1Bytes, 0, 4+4);
    NSData *c1 = [NSData dataWithBytes:&c1Bytes length:kRtmpSignatureSize];
    free(c1Bytes);
    [self writeData:c1];
}

- (void)handshake1{
    self.rtmpStatus = LLYRtmpSessionStatusHandshake2;
    NSData *s1 = [self.handShake subdataWithRange:NSMakeRange(0, kRtmpSignatureSize)];
    
    //c2
    uint8_t *s1Bytes = (uint8_t *)s1.bytes;
    memset(s1Bytes + 4, 0, 4);
    
    NSData *c2 = [NSData dataWithBytes:s1Bytes length:s1.length];
    [self writeData:c2];
}



- (void)writeData:(NSData *)data{
    if (data.length == 0) {
        return;
    }
    
    [self.streamSession writeData:data];
}

- (void)didReceivedata{
    NSData *data = [self.streamSession readData];
    
    if (self.rtmpStatus >= LLYRtmpSessionStatusConnected && self.rtmpStatus < LLYRtmpSessionStatusHandshakeComplete) {
        [self.handShake appendData:data];
    }
    
    NSLog(@"%zd", data.length);
    
    switch (self.rtmpStatus) {
        case LLYRtmpSessionStatusHandshake0:{
            
            uint8_t s0;
            [data getBytes:&s0 length:1];
            if (s0 == 0x03) {
                self.rtmpStatus = LLYRtmpSessionStatusHandshake1;
                if (data.length > 1) {
                    data = [data subdataWithRange:NSMakeRange(1, data.length - 1)];
                    self.handShake = data.mutableCopy;
                } else {
                    break;
                }
            } else {
                NSLog(@"握手失败");
                break;
            }
        }
            
        case LLYRtmpSessionStatusHandshake1:{
            
            if (self.handShake.length >= kRtmpSignatureSize) {
                [self handshake1];
                
                if (self.handShake.length > kRtmpSignatureSize) {
                    NSData *subData = [self.handShake subdataWithRange:NSMakeRange(kRtmpSignatureSize, self.handShake.length - kRtmpSignatureSize)];
                    
                    self.handShake = subData.mutableCopy;
                } else {
                    self.handShake = [NSMutableData data];
                    break;
                }
            } else {
                break;
            }
        }
        case LLYRtmpSessionStatusHandshake2:{
            
            if (data.length >= kRtmpSignatureSize) {
                NSLog(@"握手完成");
                self.rtmpStatus = LLYRtmpSessionStatusHandshakeComplete;
                [self sendConnectPacket];
            }
            break;
        }
            
        default:
            [self parseData:data];
            break;
    }
}

- (void)parseData:(NSData *)data{
    
    if (data.length == 0) {
        return;
    }
    
    uint8_t *buffer = (uint8_t *)data.bytes;
    NSUInteger total = data.length;
    
    int loopIndex = 0;
    while (total > 0) {
        loopIndex ++;
        
        total --;
        
        if (total <= 0) {
            break;
        }
        
        const uint8_t buf0 = buffer[0];
        int headType = (buffer[0] & 0xC0) >> 6;
        buffer ++;
        
        switch (headType) {
            case RTMP_HEADER_TYPE_FULL:{
                RTMPChunk_0 chunk;
                memcpy(&chunk, buffer, sizeof(RTMPChunk_0));
                chunk.msg_length.data = [NSMutableData getByte24:(uint8_t *)&chunk.msg_length];
                
                buffer += sizeof(RTMPChunk_0);
                total -= sizeof(RTMPChunk_0);
                
                BOOL isSuccess = [self handleMeesage:buffer type:chunk.msg_type_id length:chunk.msg_length.data
                                  ];
                if (!isSuccess) {
                    total = 0;
                    break;
                }
                
                buffer += chunk.msg_length.data;
                total -= chunk.msg_length.data;
            }
                break;
                
            default:
                break;
        }
    }
    
    
}

- (BOOL)handleMeesage:(uint8_t *)p type:(uint8_t)msgTypeId length:(int)length{
    
}

- (void)sendConnectPacket{
    
}



- (void)sendBuffer:(BLFrame *)frame{
    dispatch_sync(_pacekageQueue, ^{
        uint64_t ts = frame.timestamp;
        int streamId = frame.msgStreamId;
        
        NSNumber *preTimestamp = self.preChunk[@(streamId)];
        
        uint8_t *chunk;
        int offset = 0;
        
        if (preTimestamp == nil) { //第一帧,音视频
            
            chunk = malloc(12);
            chunk[0] = RTMP_CHUNK_TYPE_0 | (streamId & 0x1F);
            offset += 1;
            
            memcpy(chunk + offset, [NSMutableData be24:(uint32_t)ts], 3);
            offset += 3;
            
            memcpy(chunk + offset, [NSMutableData be24:frame.msgLength], 3);
            offset += 3;
            
            int msgTypeId = frame.msgTypeId;
            memcpy(chunk + offset, &msgTypeId, 1);
            offset += 1;
            
            memcpy(chunk + offset, (uint8_t *)&(streamId), sizeof(streamId));
            offset += sizeof(streamId);
            
        } else {
            chunk = malloc(8);
            
            chunk[0] = RTMP_CHUNK_TYPE_1 | (streamId & 0x1F);
            offset += 1;
            
            char *temp = [NSMutableData be24:(uint32_t)(ts - preTimestamp.integerValue)];
            memcpy(chunk + offset, temp, 3);
            offset += 3;
            
            memcpy(chunk + offset, [NSMutableData be24:frame.msgLength], 3);
            offset += 3;
            
            int msgTypeId = frame.msgTypeId;
            memcpy(chunk + offset, &msgTypeId, 1);
            offset += 1;
            
        }
        
        self.preChunk[@(streamId)] = @(ts);
        
        uint8_t *bufferData = (uint8_t *)frame.data.bytes;
        uint8_t *outp = (uint8_t *)malloc(frame.data.length + 64);
        memcpy(outp, chunk, offset);
        
        free(chunk);
        
        NSUInteger total = frame.data.length;
        NSInteger step = MIN(total, self->_outChunkSize);
        
        memcpy(outp + offset, bufferData, step);
        offset += step;
        total -= step;
        
        bufferData += step;
        
        while (total > 0) {
            step = MIN(total, self->_outChunkSize);
            
            bufferData[-1] = RTMP_CHUNK_TYPE_3 | (streamId & 0x1F);
            memcpy(outp + offset, bufferData - 1, step + 1);
            
            offset += step + 1;
            total -= step;
            bufferData += step;
        }
        
        NSData *tosend = [NSData dataWithBytes:outp length:offset];
        free(outp);
        [self writeData:tosend];
    });
}


#pragma mark -- init

- (NSMutableDictionary<NSNumber *,NSString *> *)trackedCommands{
    if (!_trackedCommands) {
        _trackedCommands = [NSMutableDictionary dictionary];
    }
    return _trackedCommands;
}

- (NSMutableDictionary *)preChunk{
    if (!_preChunk) {
        _preChunk = [NSMutableDictionary dictionary];
    }
    return _preChunk;
}

- (BLStreamSession *)streamSession{
    if (!_streamSession) {
        _streamSession = [[BLStreamSession alloc] init];
        _streamSession.delegate = self;
    }
    return _streamSession;
}

- (void)setConfig:(BLRtmpConfig *)config{
    _config = config;
    self.url = config.url;
}

- (void)setUrl:(NSString *)url{
    _url = url;
    NSLog(@"scheme:%@",url.scheme);
    NSLog(@"host:%@",url.host);
    NSLog(@"app:%@",url.app);
    NSLog(@"playPath:%@",url.playPath);
    NSLog(@"port:%u",(unsigned int)url.port);
}

- (void)setRtmpStatus:(LLYRtmpSessionStatus)rtmpStatus{
    _rtmpStatus = rtmpStatus;
    
    NSLog(@"rtmpStatus-----%zd",rtmpStatus);
    if ([self.delegate respondsToSelector:@selector(rtmpSession:didChangeStatus:)]) {
        [self.delegate rtmpSession:self didChangeStatus:_rtmpStatus];
    }
}


@end
