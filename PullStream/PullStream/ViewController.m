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


@interface ViewController ()

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
}


- (void)readLiveStream{
    
    int nRead;
    
    BOOL bLiveStream = true;
    
    int bufsize = 1024 * 1024 * 10;
    char *buf = (char *)malloc(bufsize);
    
    memset(buf, 0, bufsize);
    
    long countbufsize = 0;
    
    char output_str_full[500] = {0};
    NSString *path = [[[NSBundle mainBundle] resourcePath] stringByAppendingPathComponent:@"receive.flv"];
    //把格式化的数据写入某个字符串中
    sprintf(output_str_full, "%s", [path UTF8String]);
    printf("output path: %s\n", output_str_full);
    FILE *fp = fopen(output_str_full, "wb");
    if (!fp) {
        RTMP_LogPrintf("Open Flie Error.\n");
        
        return;
    }
    
    
    RTMP *rtmp = RTMP_Alloc();
    RTMP_Init(rtmp);
    
    rtmp->Link.timeout = 20;
    
    if (!RTMP_SetupURL(rtmp, "rtmp://192.168.1.146:1935/live/room")) {
        RTMP_Log(RTMP_LOGERROR, "SetupURL Err\n");
        RTMP_Free(rtmp);
        return;
    }
    
    if (bLiveStream) {
        rtmp->Link.lFlags |= RTMP_LF_LIVE;
    }
    
    //1hour
    RTMP_SetBufferMS(rtmp, 3600 * 1000);
    
    if (!RTMP_Connect(rtmp, NULL)) {
        RTMP_Log(RTMP_LOGERROR, "connect err\n");
        RTMP_Free(rtmp);
        return;
    }
    
    if (!RTMP_ConnectStream(rtmp, 0)) {
        RTMP_Log(RTMP_LOGERROR, "connect stream Err\n");
        RTMP_Close(rtmp);
        RTMP_Free(rtmp);
        return;
    }
    
    while (YES) {
        nRead = RTMP_Read(rtmp, buf, bufsize);
        if (nRead) {
            fwrite(buf, 1, nRead, fp);
            countbufsize += nRead;
            RTMP_LogPrintf("Receive: %5dByte, Total: %5.2fkB\n",nRead,countbufsize*1.0/1024);
        } else {
            break;
        }
    }
    
    fclose(fp);
    
    if (buf) {
        free(buf);
    }
    
    RTMP_Close(rtmp);
    RTMP_Free(rtmp);
    rtmp = NULL;
}


- (IBAction)send:(id)sender {
    [self readLiveStream];
}


@end
