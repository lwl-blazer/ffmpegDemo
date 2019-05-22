//
//  ViewController.m
//  PullStream
//
//  Created by luowailin on 2019/5/16.
//  Copyright © 2019 luowailin. All rights reserved.
//

#import "ViewController.h"
#include <librtmp/rtmp.h>
#include <librtmp/log.h>
#import "BLRtmpSession.h"
#import "BLRtmpConfig.h"
#import "AAPLEAGLLayer.h"

@interface ViewController ()<BLRtmpSessionDelegate>{
    
    uint8_t *packetBuffer;
    long packetSize;
}
@property (strong, nonatomic) AAPLEAGLLayer *eaglLayer;

@property(nonatomic, strong) NSFileManager *fileManager;
@property(nonatomic, copy) NSString *path;

@property(nonatomic, strong) BLRtmpSession *rtmpSession;

@end

@implementation ViewController

//第一步: 初始化Socket
- (void)InitSocket{
    
}

//最后一步:关闭Socket
- (void)cleanupSockets{
    
}

- (void)viewDidLoad {
    [super viewDidLoad];
    
    self.eaglLayer = [[AAPLEAGLLayer alloc] initWithFrame:self.view.frame];
    self.eaglLayer.backgroundColor = [UIColor blackColor].CGColor;
    [self.view.layer addSublayer:self.eaglLayer];
    self.eaglLayer.zPosition = -1;
    
    //创建空文件
    self.path = NSSearchPathForDirectoriesInDomains(NSDocumentDirectory, NSUserDomainMask, YES).lastObject;
    self.path = [self.path stringByAppendingPathComponent:@"receive.txt"];
    
    if ([self.fileManager fileExistsAtPath:self.path]) {
        [self.fileManager removeItemAtPath:self.path error:nil];
    }
    [self.fileManager createFileAtPath:self.path contents:nil attributes:nil];
}


- (void)readLiveStream{
    
    int nRead;
    
    BOOL bLiveStream = true;
    
    int bufsize = 1024 * 1024 * 10;
    char *buf = (char *)malloc(bufsize);
    
    memset(buf, 0, bufsize);
    
    long countbufsize = 0;
    
    char output_str_full[500] = {0};

    //把格式化的数据写入某个字符串中
    sprintf(output_str_full, "%s", [self.path UTF8String]);
    printf("output path: %s\n", output_str_full);
    FILE *fp = fopen(output_str_full, "wb");
    if (!fp) {
        RTMP_LogPrintf("Open Flie Error.\n");
        return;
    }
    
    //用于创建一个RTMP会话的句柄
    RTMP *rtmp = RTMP_Alloc();
    RTMP_Init(rtmp); //初始化句柄
    
    rtmp->Link.timeout = 20;
    
    
    
    
    
    //设置会话的参数
    if (!RTMP_SetupURL(rtmp, "rtmp://192.168.1.148:1935/live/room")) {
        RTMP_Log(RTMP_LOGERROR, "SetupURL Err\n");
        RTMP_Free(rtmp);
        return;
    }
    
    if (bLiveStream) {
        rtmp->Link.lFlags |= RTMP_LF_LIVE;
    }
    
    //1hour
    RTMP_SetBufferMS(rtmp, 3600 * 1000);
    
    
    //建立RTMP链接中的网络连接(NetConnection)
    if (!RTMP_Connect(rtmp, NULL)) {
        RTMP_Log(RTMP_LOGERROR, "connect err\n");
        RTMP_Free(rtmp);
        return;
    }
    
    //建立RTMP链接中的网络流(NetStream)
    if (!RTMP_ConnectStream(rtmp, 0)) {
        RTMP_Log(RTMP_LOGERROR, "connect stream Err\n");
        RTMP_Close(rtmp);
        RTMP_Free(rtmp);
        return;
    }
    
    while (YES) {
        //读取RTMP流的内容   当返回0字节的时候，代表流已经读取完毕
        nRead = RTMP_Read(rtmp, buf, bufsize);
        if (nRead) {
            
            NSData *data = [NSData dataWithBytes:buf length:nRead];
            NSLog(@"%@", data);
            
            fwrite(buf, 1, nRead, fp);
            countbufsize += nRead;
            RTMP_LogPrintf("Receive: %5dByte, Total: %5.2fkB\n",nRead,countbufsize*1.0/1024);
            
            
            packetBuffer = (uint8_t *)data.bytes;
            packetSize = (long)nRead;
            
            [self updateFrame];
            
        } else {
            break;
        }
    }
    
    fclose(fp);
    
    if (buf) {
        free(buf);
    }
    
    RTMP_Close(rtmp);
    RTMP_Free(rtmp); //清理会话
    rtmp = NULL;
    RTMP_LogPrintf("End\n");
}


- (IBAction)send:(id)sender {
    //[self readLiveStream];
    [self.rtmpSession connect];
}

- (NSFileManager *)fileManager{
    if (!_fileManager) {
        _fileManager = [NSFileManager defaultManager];
    }
    return _fileManager;
}

- (void)updateFrame{
    if (packetBuffer == NULL) {
        return;
    }
    
    uint8_t avcType = packetBuffer[0];
    long totalLength = packetSize;
    
    while (avcType == 0x17 || avcType == 0x27) {
        uint8_t type = packetBuffer[1];
        if (type == 0) {
            NSLog(@"type === 0");
            break;
        } else if (type == 1) {
            NSLog(@"type === 1");
            break;
        }
    }
}


- (void)rtmpSession:(BLRtmpSession *)rtmpSession didChangeStatus:(LLYRtmpSessionStatus)rtmpstatus{
    
}

- (void)rtmpSession:(BLRtmpSession *)rtmpSession receiveVideoData:(uint8_t *)data length:(int)length{
    packetBuffer = data;
    packetSize = length;
    [self updateFrame];
}


- (BLRtmpSession *)rtmpSession{
    if (!_rtmpSession) {
        _rtmpSession = [[BLRtmpSession alloc] init];
        _rtmpSession.delegate = self;
        
        BLRtmpConfig *config = [[BLRtmpConfig alloc] init];
        config.url = @"rtmp://192.168.1.148:1935/live/room";
        config.width = 480;
        config.height = 640;
        config.frameDuration = 1.0 / 30;
        config.videoBitrate = 512 *1024;
        
        _rtmpSession.config = config;
    }
    return _rtmpSession;
}

@end
