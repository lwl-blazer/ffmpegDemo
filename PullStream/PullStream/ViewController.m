//
//  ViewController.m
//  PullStream
//
//  Created by luowailin on 2019/5/16.
//  Copyright © 2019 luowailin. All rights reserved.
//

#import "ViewController.h"
#include "include/librtmp/rtmp.h"

@interface ViewController ()

@end

@implementation ViewController

- (void)viewDidLoad {
    [super viewDidLoad];
}


- (IBAction)send:(id)sender {
    
    RTMP *rtmp = RTMP_Alloc();
    RTMP_Init(rtmp);
    
    RTMP_SetupURL(rtmp, "rtmp://10.204.109.20:1935/live/room");
    
    RTMP_SetBufferMS(rtmp, 3600 * 1000);
    
    RTMP_Connect(rtmp, NULL);
    
    RTMP_ConnectStream(rtmp, 0);
    
    char * buf = NULL;
    while (RTMP_Read(rtmp, buf, 3600 * 1000)) {
        
        NSLog(@"rtmp_read....");
    }
    RTMP_Close(rtmp);
}


@end
